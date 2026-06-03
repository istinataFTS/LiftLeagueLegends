import { assertAlmostEquals, assertEquals, assertRejects } from "@std/assert";
import { assertWithinBudget, getBudgetState } from "./budget.ts";
import { ErrorCodes, VoiceError } from "./errors.ts";
import type { SupabaseClient } from "@supabase/supabase-js";

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
