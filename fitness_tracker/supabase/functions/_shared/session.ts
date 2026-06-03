import type { SupabaseClient } from "@supabase/supabase-js";
import type { Turn } from "./types.ts";

/**
 * Appends one turn to a `voice_sessions` row. No-op when `enabled` is false.
 *
 * TODO(C-2): The `enabled` flag currently comes verbatim from the client.
 * Per the C-1 plan §6.8 the server must also validate this against the
 * user's persisted setting (a future `AppSettings.voiceSessionLoggingEnabled`
 * field introduced in C-2) and override the client value if they disagree.
 * Until that AppSettings field exists this defensive lookup cannot be
 * implemented; the lookup + 60 s cache will be added in C-2.
 *
 * Threat model gap until then: a tampered client could opt itself into
 * session logging even if the user toggled it off in Settings. Risk is
 * bounded — a tampered client can already issue any tool call on the
 * user's behalf — but the gap is real and tracked here.
 */
export async function appendSessionTurn(
  serviceClient: SupabaseClient,
  args: {
    sessionId: string;
    userId: string;
    turn: Turn;
    costUsd: number;
    enabled: boolean;
  },
): Promise<void> {
  if (!args.enabled) return;

  const { error } = await serviceClient.rpc("voice_session_append_turn", {
    p_session_id: args.sessionId,
    p_user_id: args.userId,
    p_turn: args.turn,
    p_cost_usd: args.costUsd,
  });

  if (error) {
    // Swallow — session logging failure must never block the user's request.
    console.error("[voice] appendSessionTurn failed:", error);
  }
}
