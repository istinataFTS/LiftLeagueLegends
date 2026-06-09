import { assertEquals } from "@std/assert";
import { appendSessionTurn } from "./session.ts";
import type { SupabaseClient } from "./deps.ts";

function makeRpcClient(
  onRpc: (fn: string, args: Record<string, unknown>) => { error: unknown },
) {
  return {
    rpc: (fn: string, args: Record<string, unknown>) => onRpc(fn, args),
  } as unknown as SupabaseClient;
}

const baseTurn = { role: "user" as const, content: "hello" };
const baseArgs = {
  sessionId: "session-1",
  userId: "user-1",
  turn: baseTurn,
  costUsd: 0.001,
};

Deno.test("appendSessionTurn: disabled → no RPC call", async () => {
  let called = false;
  const client = makeRpcClient(() => {
    called = true;
    return { error: null };
  });
  await appendSessionTurn(client, { ...baseArgs, enabled: false });
  assertEquals(called, false);
});

Deno.test("appendSessionTurn: enabled → calls voice_session_append_turn RPC", async () => {
  let capturedFn: string | null = null;
  let capturedArgs: Record<string, unknown> = {};

  const client = makeRpcClient((fn, args) => {
    capturedFn = fn;
    capturedArgs = args;
    return { error: null };
  });

  await appendSessionTurn(client, { ...baseArgs, enabled: true });

  assertEquals(capturedFn, "voice_session_append_turn");
  assertEquals(capturedArgs?.p_session_id, "session-1");
  assertEquals(capturedArgs?.p_user_id, "user-1");
  assertEquals(capturedArgs?.p_cost_usd, 0.001);
});

Deno.test("appendSessionTurn: RPC error is swallowed (no throw)", async () => {
  const consoleSpy: unknown[] = [];
  const originalError = console.error;
  console.error = (...args: unknown[]) => consoleSpy.push(args);

  try {
    const client = makeRpcClient(() => ({ error: { message: "rpc error" } }));
    await appendSessionTurn(client, { ...baseArgs, enabled: true });
    assertEquals(
      consoleSpy.length > 0,
      true,
      "Expected console.error to be called",
    );
  } finally {
    console.error = originalError;
  }
});

Deno.test("appendSessionTurn: assistant turn is passed correctly", async () => {
  let capturedArgs: Record<string, unknown> = {};
  const client = makeRpcClient((_, args) => {
    capturedArgs = args;
    return { error: null };
  });

  const assistantTurn = { role: "assistant" as const, content: "Got it!" };
  await appendSessionTurn(client, {
    ...baseArgs,
    turn: assistantTurn,
    enabled: true,
  });

  assertEquals((capturedArgs?.p_turn as { role: string }).role, "assistant");
});
