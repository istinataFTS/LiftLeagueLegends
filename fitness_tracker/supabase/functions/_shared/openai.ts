import { ErrorCodes, VoiceError } from "./errors.ts";
import type { ToolCall } from "./types.ts";

const OPENAI_BASE = "https://api.openai.com/v1";
const TIMEOUT_MS = 30_000;
const USER_AGENT = "fitness-tracker-voice/c1";

// Injectable fetch for testing.
let _fetch: typeof fetch = globalThis.fetch;
export function _setFetch(f: typeof fetch): void {
  _fetch = f;
}

/**
 * Reads the OpenAI API key from the environment. Fails fast with a clear
 * error if the secret is unset — otherwise an empty bearer token would be
 * sent to OpenAI, OpenAI would return 401, and we'd surface a confusing
 * error. Server misconfig must surface as such, not as a per-request issue.
 */
function getApiKey(): string {
  const key = Deno.env.get("OPENAI_API_KEY");
  if (!key) {
    console.error(
      "[voice] OPENAI_API_KEY is not set — set via `supabase secrets set OPENAI_API_KEY=...`",
    );
    throw new VoiceError(
      ErrorCodes.OPENAI_UNAVAILABLE,
      "Voice service is misconfigured",
      502,
    );
  }
  return key;
}

function makeHeaders(extra?: Record<string, string>): Headers {
  return new Headers({
    Authorization: `Bearer ${getApiKey()}`,
    "User-Agent": USER_AGENT,
    ...extra,
  });
}

/**
 * Runs `fn` with an abort signal that fires after TIMEOUT_MS. The previous
 * implementation tried to fake an abort by dispatching a synthetic event on
 * the signal, which is a no-op — only `controller.abort()` actually puts the
 * signal in aborted state. Without this fix, real-world OpenAI hangs would
 * never be canceled by the timer.
 */
async function withTimeout<T>(
  fn: (signal: AbortSignal) => Promise<T>,
): Promise<T> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    return await fn(controller.signal);
  } catch (err) {
    if ((err as Error).name === "AbortError") {
      throw new VoiceError(ErrorCodes.TIMEOUT, "OpenAI request timed out", 504);
    }
    throw err;
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Maps OpenAI HTTP status codes to our VoiceError codes.
 *
 * Note: 401/403 from OpenAI means OUR API key is bad (server misconfig),
 * NOT that the user's JWT is bad. Mapping to UNAUTHORIZED would mislead
 * the client into prompting the user to sign in again. Surface as
 * OPENAI_UNAVAILABLE (502) instead, with a server-side log so the
 * misconfig is observable.
 */
function mapOpenAiStatus(status: number): never {
  if (status === 429) {
    throw new VoiceError(
      ErrorCodes.RATE_LIMITED,
      "OpenAI rate limit exceeded",
      429,
    );
  }
  if (status === 401 || status === 403) {
    console.error(
      "[voice] OpenAI rejected our API key — check OPENAI_API_KEY secret",
    );
    throw new VoiceError(
      ErrorCodes.OPENAI_UNAVAILABLE,
      "OpenAI authentication failed",
      502,
    );
  }
  throw new VoiceError(
    ErrorCodes.OPENAI_UNAVAILABLE,
    `OpenAI returned HTTP ${status}`,
    502,
  );
}

// ---------------------------------------------------------------------------
// Chat completion
// ---------------------------------------------------------------------------

export interface ChatRequest {
  history: ReadonlyArray<{
    role: "system" | "user" | "assistant" | "tool";
    content: string;
    tool_call_id?: string;
  }>;
  tools: ReadonlyArray<{
    type: "function";
    function: { name: string; description: string; parameters: object };
  }>;
}

export interface ChatResponse {
  model: string;
  inputTokens: number;
  outputTokens: number;
  message?: string;
  toolCall?: ToolCall;
}

export async function completeChat(req: ChatRequest): Promise<ChatResponse> {
  const res = await withTimeout((signal) =>
    _fetch(`${OPENAI_BASE}/chat/completions`, {
      method: "POST",
      headers: makeHeaders({ "Content-Type": "application/json" }),
      body: JSON.stringify({
        model: "gpt-4o-mini-2024-07-18",
        messages: req.history,
        tools: req.tools.length > 0 ? req.tools : undefined,
        tool_choice: req.tools.length > 0 ? "auto" : undefined,
      }),
      signal,
    })
  );

  if (!res.ok) mapOpenAiStatus(res.status);

  const json = await res.json();
  const choice = json.choices?.[0];
  const msg = choice?.message;

  const result: ChatResponse = {
    model: json.model,
    inputTokens: json.usage?.prompt_tokens ?? 0,
    outputTokens: json.usage?.completion_tokens ?? 0,
  };

  if (msg?.tool_calls?.[0]) {
    const tc = msg.tool_calls[0];
    let parsedArgs: Record<string, unknown> = {};
    try {
      parsedArgs = JSON.parse(tc.function.arguments ?? "{}");
    } catch {
      console.warn(
        `[voice] malformed tool-call arguments from model: ${tc.function.arguments}`,
      );
    }
    result.toolCall = {
      id: tc.id,
      name: tc.function.name,
      arguments: parsedArgs,
    };
  } else {
    result.message = msg?.content ?? "";
  }

  return result;
}
