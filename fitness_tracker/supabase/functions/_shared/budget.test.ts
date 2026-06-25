import { assertAlmostEquals, assertEquals, assertRejects } from "@std/assert";
import {
  assertWithinBudget,
  assertWithinGlobalBudget,
  getBudgetState,
  resolvedDailyCap,
  resolvedGlobalDailyCap,
} from "./budget.ts";
import { ErrorCodes, VoiceError } from "./errors.ts";
import type { SupabaseClient } from "./deps.ts";

function makeSupabase(
  rows: Array<{ cost_usd: number }>,
  error: unknown = null,
) {
  return {
    from: () => ({
      select: () => ({
        eq: () => ({
          gte: () => Promise.resolve({ data: rows, error }),
        }),
      }),
    }),
  } as unknown as SupabaseClient;
}

Deno.test("assertWithinBudget: empty log → usedUsd=0, returns remaining=0.50", async () => {
  const result = await assertWithinBudget(makeSupabase([]), "user-1");
  assertEquals(result.usedUsd, 0);
  assertEquals(result.remainingUsd, 0.5);
});

Deno.test("assertWithinBudget: under cap → returns correct remaining", async () => {
  const rows = [{ cost_usd: 0.3 }, { cost_usd: 0.1 }];
  const result = await assertWithinBudget(makeSupabase(rows), "user-1");
  assertAlmostEquals(result.usedUsd, 0.4);
  assertAlmostEquals(result.remainingUsd, 0.1);
});

Deno.test("assertWithinBudget: exactly at cap → throws BUDGET_EXCEEDED", async () => {
  const rows = [{ cost_usd: 0.5 }];
  const err = await assertRejects(
    () => assertWithinBudget(makeSupabase(rows), "user-1"),
    VoiceError,
  );
  assertEquals(err.code, ErrorCodes.BUDGET_EXCEEDED);
  assertEquals(err.httpStatus, 402);
});

Deno.test("assertWithinBudget: over cap → throws BUDGET_EXCEEDED", async () => {
  const rows = [{ cost_usd: 0.4 }, { cost_usd: 0.2 }];
  const err = await assertRejects(
    () => assertWithinBudget(makeSupabase(rows), "user-1"),
    VoiceError,
  );
  assertEquals(err.code, ErrorCodes.BUDGET_EXCEEDED);
});

Deno.test("assertWithinBudget: DB error → throws INTERNAL", async () => {
  const err = await assertRejects(
    () =>
      assertWithinBudget(makeSupabase([], { message: "db error" }), "user-1"),
    VoiceError,
  );
  assertEquals(err.code, ErrorCodes.INTERNAL);
});

Deno.test("assertWithinBudget: custom daily cap is respected", async () => {
  const rows = [{ cost_usd: 0.06 }];
  const err = await assertRejects(
    () => assertWithinBudget(makeSupabase(rows), "user-1", 0.05),
    VoiceError,
  );
  assertEquals(err.code, ErrorCodes.BUDGET_EXCEEDED);
});

// ---------------------------------------------------------------------------
// getBudgetState — the non-throwing post-success reader
// ---------------------------------------------------------------------------

Deno.test("getBudgetState: under cap → exceeded=false, remaining > 0", async () => {
  const state = await getBudgetState(
    makeSupabase([{ cost_usd: 0.2 }]),
    "user-1",
  );
  assertEquals(state.usedUsd, 0.2);
  assertEquals(state.remainingUsd, 0.3);
  assertEquals(state.exceeded, false);
});

Deno.test("getBudgetState: at cap → exceeded=true but DOES NOT throw", async () => {
  // Critical: getBudgetState is the post-success reader. If it threw on
  // crossing the cap, every voice request that *just* crossed $0.50 would
  // 402 the user even though their work succeeded and was billed.
  const state = await getBudgetState(
    makeSupabase([{ cost_usd: 0.5 }]),
    "user-1",
  );
  assertEquals(state.usedUsd, 0.5);
  assertEquals(state.remainingUsd, 0);
  assertEquals(state.exceeded, true);
});

Deno.test("getBudgetState: over cap → remainingUsd clamped to 0 (never negative)", async () => {
  const state = await getBudgetState(
    makeSupabase([{ cost_usd: 0.8 }]),
    "user-1",
  );
  assertEquals(state.usedUsd, 0.8);
  assertEquals(state.remainingUsd, 0);
  assertEquals(state.exceeded, true);
});

Deno.test("getBudgetState: DB error → throws INTERNAL (DB error is not a budget signal)", async () => {
  const err = await assertRejects(
    () => getBudgetState(makeSupabase([], { message: "db error" }), "user-1"),
    VoiceError,
  );
  assertEquals(err.code, ErrorCodes.INTERNAL);
});

// ---------------------------------------------------------------------------
// resolvedDailyCap — env-driven cap resolver
// ---------------------------------------------------------------------------

Deno.test("resolvedDailyCap: env var absent → falls back to 0.50", () => {
  Deno.env.delete("DAILY_BUDGET_CAP_USD");
  assertEquals(resolvedDailyCap(), 0.50);
});

Deno.test("resolvedDailyCap: env var empty → falls back to 0.50", () => {
  Deno.env.set("DAILY_BUDGET_CAP_USD", "");
  try {
    assertEquals(resolvedDailyCap(), 0.50);
  } finally {
    Deno.env.delete("DAILY_BUDGET_CAP_USD");
  }
});

Deno.test("resolvedDailyCap: positive numeric value → parsed", () => {
  Deno.env.set("DAILY_BUDGET_CAP_USD", "1.25");
  try {
    assertEquals(resolvedDailyCap(), 1.25);
  } finally {
    Deno.env.delete("DAILY_BUDGET_CAP_USD");
  }
});

Deno.test("resolvedDailyCap: non-positive value → falls back to 0.50", () => {
  Deno.env.set("DAILY_BUDGET_CAP_USD", "-1");
  try {
    assertEquals(resolvedDailyCap(), 0.50);
  } finally {
    Deno.env.delete("DAILY_BUDGET_CAP_USD");
  }
});

Deno.test("resolvedDailyCap: non-numeric value → falls back to 0.50", () => {
  Deno.env.set("DAILY_BUDGET_CAP_USD", "notanumber");
  try {
    assertEquals(resolvedDailyCap(), 0.50);
  } finally {
    Deno.env.delete("DAILY_BUDGET_CAP_USD");
  }
});

Deno.test("resolvedDailyCap: trailing garbage rejects to fallback (strict parse)", () => {
  // parseFloat("0.50x") would silently return 0.50; Number() rejects to NaN
  // so a malformed secret falls back to the default cap rather than applying
  // an attacker-controlled prefix.
  Deno.env.set("DAILY_BUDGET_CAP_USD", "0.50x");
  try {
    assertEquals(resolvedDailyCap(), 0.50);
  } finally {
    Deno.env.delete("DAILY_BUDGET_CAP_USD");
  }
});

// ---------------------------------------------------------------------------
// resolvedGlobalDailyCap — env-driven global cap resolver
// ---------------------------------------------------------------------------

Deno.test("resolvedGlobalDailyCap: env var absent → falls back to 10.00", () => {
  Deno.env.delete("GLOBAL_DAILY_CAP_USD");
  assertEquals(resolvedGlobalDailyCap(), 10.00);
});

Deno.test("resolvedGlobalDailyCap: positive numeric value → parsed", () => {
  Deno.env.set("GLOBAL_DAILY_CAP_USD", "25");
  try {
    assertEquals(resolvedGlobalDailyCap(), 25);
  } finally {
    Deno.env.delete("GLOBAL_DAILY_CAP_USD");
  }
});

Deno.test("resolvedGlobalDailyCap: non-positive value → falls back to 10.00", () => {
  Deno.env.set("GLOBAL_DAILY_CAP_USD", "0");
  try {
    assertEquals(resolvedGlobalDailyCap(), 10.00);
  } finally {
    Deno.env.delete("GLOBAL_DAILY_CAP_USD");
  }
});

Deno.test("resolvedGlobalDailyCap: trailing garbage rejects to fallback (strict parse)", () => {
  Deno.env.set("GLOBAL_DAILY_CAP_USD", "10x");
  try {
    assertEquals(resolvedGlobalDailyCap(), 10.00);
  } finally {
    Deno.env.delete("GLOBAL_DAILY_CAP_USD");
  }
});

// ---------------------------------------------------------------------------
// assertWithinGlobalBudget — service-wide aggregate ceiling
// ---------------------------------------------------------------------------

// The global check aggregates across ALL users server-side via the
// `global_voice_spend_since` RPC, which returns a single scalar sum. The mock
// asserts the contract (RPC name + a `p_since` ISO timestamp argument) so a
// regression that called the wrong procedure or dropped the parameter fails
// here instead of silently passing.
function makeGlobalSupabase(
  total: number | string | null,
  error: unknown = null,
) {
  return {
    rpc: (fn: string, args: Record<string, unknown>) => {
      assertEquals(fn, "global_voice_spend_since");
      assertEquals(typeof args?.p_since, "string");
      // p_since must be a parseable timestamp at the UTC day boundary.
      assertEquals(Number.isNaN(Date.parse(args.p_since as string)), false);
      return Promise.resolve({ data: total, error });
    },
  } as unknown as SupabaseClient;
}

Deno.test("assertWithinGlobalBudget: total below cap → passes (no throw)", async () => {
  await assertWithinGlobalBudget(makeGlobalSupabase(7.0));
});

Deno.test("assertWithinGlobalBudget: total at cap → throws BUDGET_EXCEEDED 402", async () => {
  const err = await assertRejects(
    () => assertWithinGlobalBudget(makeGlobalSupabase(10.0)), // = default cap
    VoiceError,
  );
  assertEquals(err.code, ErrorCodes.BUDGET_EXCEEDED);
  assertEquals(err.httpStatus, 402);
});

Deno.test("assertWithinGlobalBudget: total over cap → throws BUDGET_EXCEEDED", async () => {
  const err = await assertRejects(
    () => assertWithinGlobalBudget(makeGlobalSupabase(12.5)),
    VoiceError,
  );
  assertEquals(err.code, ErrorCodes.BUDGET_EXCEEDED);
});

Deno.test("assertWithinGlobalBudget: numeric RPC result as string → parsed", async () => {
  // Postgres `numeric` can deserialize as a string; Number() must still parse it.
  const err = await assertRejects(
    () => assertWithinGlobalBudget(makeGlobalSupabase("11.0")),
    VoiceError,
  );
  assertEquals(err.code, ErrorCodes.BUDGET_EXCEEDED);
});

Deno.test("assertWithinGlobalBudget: DB error → fails open (no throw)", async () => {
  // A transient DB failure must NOT block legitimate users. The function logs
  // a warning and returns without throwing.
  await assertWithinGlobalBudget(
    makeGlobalSupabase(null, { message: "db error" }),
  );
});

Deno.test("assertWithinGlobalBudget: non-numeric aggregate → fails open (no throw)", async () => {
  await assertWithinGlobalBudget(makeGlobalSupabase("notanumber"));
});

Deno.test("assertWithinGlobalBudget: GLOBAL_DAILY_CAP_USD env var respected", async () => {
  Deno.env.set("GLOBAL_DAILY_CAP_USD", "5.00");
  try {
    // 6.00 spent is under the default 10 but at/over the configured 5 → throws.
    const err = await assertRejects(
      () => assertWithinGlobalBudget(makeGlobalSupabase(6.0)),
      VoiceError,
    );
    assertEquals(err.code, ErrorCodes.BUDGET_EXCEEDED);
  } finally {
    Deno.env.delete("GLOBAL_DAILY_CAP_USD");
  }
});
