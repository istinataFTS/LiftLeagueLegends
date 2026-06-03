// Schema-versus-callsites contract test.
//
// Every edge function under `supabase/functions/` that bills against the
// daily voice budget logs to `voice_usage_log`. The table has a
// `CHECK (function_name IN (...))` constraint listing the allowed names.
//
// History: when `voice-transcribe` shipped, the constraint still only
// permitted `voice-chat`, so every Whisper call failed in production with
// PostgreSQL error 23514 and the cost never landed in the budget. The fix
// (migration 20260527000000) broadened the IN list, but the failure mode
// was silent in CI because nothing cross-checks the constraint against
// the actual function directories.
//
// This test closes the gap: it walks `supabase/functions/`, builds the
// set of edge-function directories, walks `supabase/migrations/` to find
// the most recent migration that touches the constraint, parses the IN
// clause, and fails if the two sets diverge.
//
// When a new edge function is added that bills against the budget, add a
// new migration broadening the constraint in the same PR — this test
// guarantees the two land together.

import { assertEquals } from "@std/assert";
import { dirname, fromFileUrl, join } from "@std/path";

const functionsDir = dirname(dirname(fromFileUrl(import.meta.url)));
const supabaseDir = dirname(functionsDir);
const migrationsDir = join(supabaseDir, "migrations");

/// Edge-function directories that bill against the voice budget. Excludes
/// `_shared/` (utilities) and any hidden directory.
function discoverBilledFunctions(): Set<string> {
  const names = new Set<string>();
  for (const entry of Deno.readDirSync(functionsDir)) {
    if (!entry.isDirectory) continue;
    if (entry.name.startsWith(".")) continue;
    if (entry.name === "_shared") continue;
    names.add(entry.name);
  }
  return names;
}

/// Returns the set of function names allowed by the most recent migration
/// that adds the `voice_usage_log_function_name_check` constraint.
function discoverAllowedFunctions(): Set<string> {
  const files: string[] = [];
  for (const entry of Deno.readDirSync(migrationsDir)) {
    if (!entry.isFile || !entry.name.endsWith(".sql")) continue;
    const body = Deno.readTextFileSync(join(migrationsDir, entry.name));
    if (body.includes("voice_usage_log_function_name_check")) {
      files.push(entry.name);
    }
  }
  // Files are timestamp-prefixed (YYYYMMDDHHMMSS_*.sql); the last lexically
  // is the most recent.
  files.sort();
  const latest = files.at(-1);
  if (!latest) {
    throw new Error(
      `No migration found that defines voice_usage_log_function_name_check ` +
        `in ${migrationsDir}.`,
    );
  }

  const body = Deno.readTextFileSync(join(migrationsDir, latest));
  // Match the most recent `check (function_name in (...))` clause. The
  // SQL allows extra whitespace and newlines inside the IN list.
  const matches = [...body.matchAll(
    /check\s*\(\s*function_name\s+in\s*\(([^)]+)\)\s*\)/gi,
  )];
  if (matches.length === 0) {
    throw new Error(
      `Migration ${latest} mentions ` +
        `voice_usage_log_function_name_check but contains no parseable ` +
        `check (function_name in (...)) clause.`,
    );
  }
  const inList = matches.at(-1)![1];
  // Pull every single-quoted string out of the IN list, regardless of
  // surrounding whitespace.
  const names = [...inList.matchAll(/'([^']+)'/g)].map((m) => m[1]);
  return new Set(names);
}

Deno.test(
  "voice_usage_log CHECK constraint covers every edge function directory",
  () => {
    const billed = discoverBilledFunctions();
    const allowed = discoverAllowedFunctions();

    const missing = [...billed].filter((n) => !allowed.has(n)).sort();
    const extra = [...allowed].filter((n) => !billed.has(n)).sort();

    assertEquals(
      missing,
      [],
      `Edge function(s) without a matching CHECK-constraint entry: ` +
        `${missing.join(", ")}. Add a migration broadening ` +
        `voice_usage_log_function_name_check to include them, in the ` +
        `same PR that introduces the function. See ` +
        `KNOWN_ISSUES.md#voice-transcribe-must-deploy-with-openai-secret-and-cors ` +
        `for an analogous trap the team already hit.`,
    );
    assertEquals(
      extra,
      [],
      `CHECK-constraint allows function name(s) that have no matching ` +
        `directory under supabase/functions/: ${extra.join(", ")}. Either ` +
        `restore the missing function directory or land a migration that ` +
        `narrows the constraint.`,
    );
  },
);

Deno.test(
  "discoverAllowedFunctions returns a non-empty set",
  () => {
    const allowed = discoverAllowedFunctions();
    assertEquals(
      allowed.size > 0,
      true,
      "Expected the latest voice_usage_log_function_name_check migration " +
        "to list at least one allowed function name.",
    );
  },
);
