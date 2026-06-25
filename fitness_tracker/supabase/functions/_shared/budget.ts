import type { SupabaseClient } from "./deps.ts";
import { ErrorCodes, VoiceError } from "./errors.ts";

export interface BudgetState {
  readonly usedUsd: number;
  readonly remainingUsd: number; // clamped to ≥ 0 — never negative
  readonly exceeded: boolean;
}

const _DEFAULT_DAILY_CAP_USD = 0.50;

/**
 * Reads `DAILY_BUDGET_CAP_USD` from the edge-function environment.
 * Falls back to `_DEFAULT_DAILY_CAP_USD` if the variable is absent, empty,
 * non-numeric, or non-positive. This lets the owner adjust the cap in the
 * Supabase dashboard (Project → Edge Functions → Manage secrets) without a
 * code change or redeployment.
 */
export function resolvedDailyCap(): number {
  const raw = Deno.env.get("DAILY_BUDGET_CAP_USD");
  if (!raw || raw.trim() === "") return _DEFAULT_DAILY_CAP_USD;
  // Use Number() rather than parseFloat() so trailing garbage ("0.50x")
  // rejects to NaN instead of silently parsing as 0.50.
  const parsed = Number(raw.trim());
  return Number.isFinite(parsed) && parsed > 0
    ? parsed
    : _DEFAULT_DAILY_CAP_USD;
}

/**
 * Reads (without throwing) the user's voice-budget state for the current
 * UTC day. Use this AFTER a successful OpenAI call to compute the
 * remaining-budget number for the response — using the throwing
 * `assertWithinBudget` here would 402 the user's response even though
 * the work succeeded and was billed.
 *
 * On DB error this still throws (`INTERNAL`) — that's a different
 * failure mode, not a budget signal.
 */
export async function getBudgetState(
  supabase: SupabaseClient,
  userId: string,
  dailyCapUsd = resolvedDailyCap(),
): Promise<BudgetState> {
  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);

  const { data, error } = await supabase
    .from("voice_usage_log")
    .select("cost_usd")
    .eq("user_id", userId)
    .gte("created_at", today.toISOString());

  if (error) {
    throw new VoiceError(ErrorCodes.INTERNAL, "Budget check failed", 500);
  }

  const usedUsd = (data ?? []).reduce(
    (sum: number, row: { cost_usd: number | string }) =>
      sum + Number(row.cost_usd),
    0,
  );
  const remainingUsd = Math.max(0, dailyCapUsd - usedUsd);

  return { usedUsd, remainingUsd, exceeded: usedUsd >= dailyCapUsd };
}

/**
 * Pre-call budget gate. Throws `BUDGET_EXCEEDED` (402) when the user has
 * met or crossed the daily cap. Use this BEFORE issuing any OpenAI call.
 *
 * **Known limitation:** there is a TOCTOU window between this check and the
 * later `logUsage` call — two concurrent requests from the same user can
 * both pass the gate before either logs cost. Practical exposure is at most
 * one extra ~$0.01 call against a $0.50 cap. An atomic Postgres function
 * (advisory lock + insert) would eliminate this; tracked for a future PR.
 *
 * Returns `{ usedUsd, remainingUsd }` for callers that want to log /
 * surface the pre-call values; callers needing a non-throwing read after
 * a successful call should use `getBudgetState` instead.
 */
export async function assertWithinBudget(
  supabase: SupabaseClient,
  userId: string,
  dailyCapUsd = resolvedDailyCap(),
): Promise<{ usedUsd: number; remainingUsd: number }> {
  const state = await getBudgetState(supabase, userId, dailyCapUsd);

  if (state.exceeded) {
    throw new VoiceError(
      ErrorCodes.BUDGET_EXCEEDED,
      `Daily budget of $${dailyCapUsd.toFixed(2)} exceeded`,
      402,
    );
  }

  return { usedUsd: state.usedUsd, remainingUsd: state.remainingUsd };
}
