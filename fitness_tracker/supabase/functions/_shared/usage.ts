import type { SupabaseClient } from "@supabase/supabase-js";
import { PRICING_VERSION } from "./cost.ts";
import type { UsageLogInput } from "./types.ts";

export async function logUsage(
  serviceClient: SupabaseClient,
  input: UsageLogInput,
  costUsd: number,
): Promise<void> {
  const { error } = await serviceClient.from("voice_usage_log").insert({
    user_id: input.userId,
    function_name: input.functionName,
    model: input.model,
    input_tokens: input.inputTokens ?? null,
    output_tokens: input.outputTokens ?? null,
    cost_usd: costUsd,
    pricing_version: PRICING_VERSION,
    latency_ms: input.latencyMs,
    session_id: input.sessionId ?? null,
    status: input.status,
  });

  if (error) {
    // Swallow — failing to write an audit row should never block the user's request.
    console.error("[voice] logUsage insert failed:", error);
  }
}
