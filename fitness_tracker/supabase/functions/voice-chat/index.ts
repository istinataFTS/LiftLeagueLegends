import { authenticate } from "../_shared/auth.ts";
import { assertWithinBudget, getBudgetState } from "../_shared/budget.ts";
import { costForChat } from "../_shared/cost.ts";
import { preflight } from "../_shared/cors.ts";
import { ErrorCodes, errorResponse, VoiceError } from "../_shared/errors.ts";
import { completeChat } from "../_shared/openai.ts";
import { appendSessionTurn } from "../_shared/session.ts";
import { TOOL_REGISTRY } from "../_shared/tools.ts";
import type {
  FunctionName,
  RecentNutritionLogContext,
  RecentSetContext,
  Turn,
  VoiceContext,
} from "../_shared/types.ts";
import { logUsage } from "../_shared/usage.ts";
import { json, msSince, serviceClient } from "../_shared/utils.ts";

const FUNCTION_NAME: FunctionName = "voice-chat";
const MODEL = "gpt-4o-mini-2024-07-18";
const MAX_HISTORY_TURNS = 3;

// System prompt template. Placeholders: {{current_date}}, {{weight_unit}},
// {{recent_sets}}, {{recent_nutrition_logs}}.
const SYSTEM_PROMPT_TEMPLATE =
  `You are Julio Velazquez, the voice assistant for a personal fitness-tracking app. Your ONLY responsibilities are:
1. Logging, editing, and deleting workout sets and nutrition entries.
2. Answering factual questions about the user's own logged data.

You MUST refuse, politely and briefly, any other request — fitness advice, training plans, nutrition recommendations, general knowledge.
Example refusal: "I only handle logging and your own stats."

When the user is ambiguous, ask ONE clarifying question. After the user clarifies, propose the action via a tool call and let the app confirm with the user.

Never invent data. If the user asks about something you cannot retrieve via a tool, say so plainly.

Today is {{current_date}}. Weight unit is {{weight_unit}}. Conversation language is English.

Recent workout sets (with IDs for editing/deleting):
{{recent_sets}}

Recent nutrition logs (with IDs for editing/deleting):
{{recent_nutrition_logs}}

Tool usage rules:
- Use logWorkoutSet / logNutrition to record new entries. Confirm before calling.
- For edits and deletes, find the row ID from the recent sets/logs above.
- For queries (getWeeklyVolume, getDailyMacros, getRecentSets), call the tool — the app will execute it locally and speak the result; you do not need to generate a verbal summary.
- Use clarify only when the user's intent cannot be resolved without one specific question.
- If the user confirms ("yes", "do it", "confirm"), and you have enough data, call the mutation tool immediately without re-asking.
- Never repeat a clarifying question you already asked.
- For multi-field edits, prefer issuing one \`clarify\` per ambiguous field rather than expecting the user to dictate every field at once. Example: if the user says "change my breakfast macros," ask "What should the protein be?" — then on the next turn ask about carbs, etc. The 15-second STT window can accept short multi-field utterances, but a clarify-per-field loop is more reliable than a multi-field utterance.`;

interface ParsedChat {
  sessionId: string;
  userMessage: string;
  history: Turn[];
  context: VoiceContext;
  sessionLoggingEnabled: boolean;
}

/**
 * Roles that clients are allowed to include in history. The 'system' role is
 * explicitly excluded — only the server-built `SYSTEM_PROMPT_TEMPLATE` may
 * become a system message. Allowing client-supplied 'system' turns would let
 * an attacker inject "ignore prior instructions" prompts and bypass the
 * bot's scope-refusal.
 */
const ALLOWED_HISTORY_ROLES: ReadonlySet<string> = new Set([
  "user",
  "assistant",
  "tool",
]);

/**
 * Defensively converts an unknown raw-history payload into a typed `Turn[]`.
 * Rejects malformed entries silently, but logs (warns) when a 'system' role
 * is dropped so abuse is observable in server logs without breaking the
 * caller.
 *
 * Exported for direct unit testing — the security guarantees of this
 * function are too important to test only indirectly through the handler.
 */
export function sanitizeHistory(raw: unknown[]): Turn[] {
  const out: Turn[] = [];
  for (const entry of raw) {
    if (typeof entry !== "object" || entry === null) continue;
    const t = entry as Record<string, unknown>;
    const role = t.role;
    const content = t.content;

    if (typeof role !== "string" || typeof content !== "string") continue;

    if (role === "system") {
      console.warn(
        "[voice-chat] dropped client-supplied system turn — possible prompt-injection attempt",
      );
      continue;
    }
    if (!ALLOWED_HISTORY_ROLES.has(role)) continue;

    if (role === "tool") {
      const toolCallId = t.toolCallId;
      if (typeof toolCallId !== "string") continue;
      out.push({ role: "tool", content, toolCallId });
    } else if (role === "assistant") {
      out.push({ role: "assistant", content });
    } else {
      out.push({ role: "user", content });
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Context array type guards — silently drop malformed entries rather than
// crashing on a bad cast.
// ---------------------------------------------------------------------------

function isRecentSet(v: unknown): v is RecentSetContext {
  if (typeof v !== "object" || v === null) return false;
  const o = v as Record<string, unknown>;
  return typeof o.setId === "string" &&
    typeof o.exerciseName === "string" &&
    typeof o.weight === "number" &&
    typeof o.reps === "number" &&
    typeof o.intensity === "number" &&
    typeof o.date === "string";
}

function isRecentNutritionLog(v: unknown): v is RecentNutritionLogContext {
  if (typeof v !== "object" || v === null) return false;
  const o = v as Record<string, unknown>;
  return typeof o.logId === "string" &&
    typeof o.mealName === "string" &&
    typeof o.calories === "number" &&
    typeof o.date === "string";
}

async function parseChat(req: Request): Promise<ParsedChat> {
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    throw new VoiceError(
      ErrorCodes.INVALID_REQUEST,
      "Request body must be valid JSON",
      400,
    );
  }

  const sessionId = body.session_id;
  if (!sessionId || typeof sessionId !== "string") {
    throw new VoiceError(
      ErrorCodes.INVALID_REQUEST,
      "Missing required field: session_id",
      400,
    );
  }

  const userMessage = body.user_message;
  if (!userMessage || typeof userMessage !== "string") {
    throw new VoiceError(
      ErrorCodes.INVALID_REQUEST,
      "Missing required field: user_message",
      400,
    );
  }

  const rawHistory = Array.isArray(body.history) ? body.history : [];
  // Validate every turn before forwarding to OpenAI. Without this, a
  // client could inject a 'system' role turn whose content overrides the
  // server-built system prompt — bypassing the bot's scope-refusal and
  // turning the endpoint into a free general-purpose ChatGPT proxy on
  // our budget. Validation rejects 'system' from clients explicitly,
  // logs the attempt for observability, and only forwards user/assistant/
  // tool turns with string content. Then truncates to the 3-turn limit.
  const history = sanitizeHistory(rawHistory).slice(-MAX_HISTORY_TURNS);

  const ctx = (body.context ?? {}) as Partial<VoiceContext>;
  const context: VoiceContext = {
    currentDate: typeof ctx.currentDate === "string"
      ? ctx.currentDate
      : new Date().toISOString().slice(0, 10),
    weightUnit: ctx.weightUnit === "lb" ? "lb" : "kg",
    recentExerciseIds: Array.isArray(ctx.recentExerciseIds)
      ? ctx.recentExerciseIds
      : [],
    recentSets: Array.isArray(ctx.recentSets)
      ? ctx.recentSets.filter(isRecentSet)
      : [],
    recentNutritionLogs: Array.isArray(ctx.recentNutritionLogs)
      ? ctx.recentNutritionLogs.filter(isRecentNutritionLog)
      : [],
  };

  const sessionLoggingEnabled = body.session_logging_enabled === true;

  return { sessionId, userMessage, history, context, sessionLoggingEnabled };
}

function formatRecentSets(
  sets: readonly RecentSetContext[] | undefined,
  weightUnit: string,
): string {
  if (!sets || sets.length === 0) return "None logged yet.";
  return sets
    .map(
      (s) =>
        `${s.date}: ${s.exerciseName} — ${s.weight} ${weightUnit} × ${s.reps} reps ` +
        `(intensity ${s.intensity}) [id: ${s.setId}]`,
    )
    .join("\n");
}

function formatRecentNutritionLogs(
  logs: readonly RecentNutritionLogContext[] | undefined,
): string {
  if (!logs || logs.length === 0) return "None logged yet.";
  return logs
    .map((l) =>
      `${l.date}: ${l.mealName} — ${l.calories} kcal [id: ${l.logId}]`
    )
    .join("\n");
}

export function buildSystemPrompt(context: VoiceContext): string {
  return SYSTEM_PROMPT_TEMPLATE
    .replace("{{current_date}}", context.currentDate)
    .replace("{{weight_unit}}", context.weightUnit)
    .replace(
      "{{recent_sets}}",
      formatRecentSets(context.recentSets, context.weightUnit),
    )
    .replace(
      "{{recent_nutrition_logs}}",
      formatRecentNutritionLogs(context.recentNutritionLogs),
    );
}

async function handleChat(req: Request, t0: number): Promise<Response> {
  const user = await authenticate(req);
  const parsed = await parseChat(req);
  const supabase = serviceClient();

  await assertWithinBudget(supabase, user.id);

  const systemPrompt = buildSystemPrompt(parsed.context);
  const messages = [
    { role: "system" as const, content: systemPrompt },
    ...parsed.history.map((t) => ({
      role: t.role as "user" | "assistant" | "tool",
      content: t.content,
      ...(t.role === "tool"
        ? { tool_call_id: (t as Extract<Turn, { role: "tool" }>).toolCallId }
        : {}),
    })),
    { role: "user" as const, content: parsed.userMessage },
  ];

  const tools = TOOL_REGISTRY.map((td) => ({
    type: "function" as const,
    function: {
      name: td.name,
      description: td.description,
      parameters: td.parameters,
    },
  }));

  let chatResult: Awaited<ReturnType<typeof completeChat>>;
  try {
    chatResult = await completeChat({ history: messages, tools });
  } catch (err) {
    const code = err instanceof VoiceError ? err.code : ErrorCodes.INTERNAL;
    await logUsage(supabase, {
      userId: user.id,
      functionName: FUNCTION_NAME,
      model: MODEL,
      latencyMs: msSince(t0),
      sessionId: parsed.sessionId,
      status: code,
    }, 0);
    throw err;
  }

  const cost = costForChat(
    MODEL,
    chatResult.inputTokens,
    chatResult.outputTokens,
  );

  await logUsage(supabase, {
    userId: user.id,
    functionName: FUNCTION_NAME,
    model: chatResult.model,
    inputTokens: chatResult.inputTokens,
    outputTokens: chatResult.outputTokens,
    latencyMs: msSince(t0),
    sessionId: parsed.sessionId,
    status: "OK",
  }, cost);

  // Log the user message turn and assistant reply to the session.
  await appendSessionTurn(supabase, {
    sessionId: parsed.sessionId,
    userId: user.id,
    turn: { role: "user", content: parsed.userMessage },
    costUsd: 0,
    enabled: parsed.sessionLoggingEnabled,
  });

  if (chatResult.toolCall) {
    // Stable placeholder content for transcript readability — the
    // structured `toolCall` field carries the real intent. An empty
    // string here would render as a blank assistant bubble in any
    // future transcript viewer.
    await appendSessionTurn(supabase, {
      sessionId: parsed.sessionId,
      userId: user.id,
      turn: {
        role: "assistant",
        content: `[tool_call: ${chatResult.toolCall.name}]`,
        toolCall: chatResult.toolCall,
      },
      costUsd: cost,
      enabled: parsed.sessionLoggingEnabled,
    });
  } else if (chatResult.message !== undefined) {
    await appendSessionTurn(supabase, {
      sessionId: parsed.sessionId,
      userId: user.id,
      turn: { role: "assistant", content: chatResult.message },
      costUsd: cost,
      enabled: parsed.sessionLoggingEnabled,
    });
  }

  // Non-throwing read: the work has been billed; a budget gate would penalise
  // a successful call when the cost crosses the cap on this very turn.
  const { remainingUsd } = await getBudgetState(supabase, user.id);

  const base = {
    model: chatResult.model,
    input_tokens: chatResult.inputTokens,
    output_tokens: chatResult.outputTokens,
    cost_usd: cost,
    remaining_budget_usd: remainingUsd,
    request_id: crypto.randomUUID(),
  };

  if (chatResult.toolCall) {
    return json(200, {
      kind: "tool_call",
      tool_call: chatResult.toolCall,
      ...base,
    });
  }
  return json(200, { kind: "message", content: chatResult.message, ...base });
}

Deno.serve(async (req) => {
  const t0 = performance.now();
  const corsResp = preflight(req);
  if (corsResp) return corsResp;

  if (req.method !== "POST") {
    return json(405, {
      code: "METHOD_NOT_ALLOWED",
      message: "Only POST is accepted",
    });
  }

  try {
    return await handleChat(req, t0);
  } catch (err) {
    return errorResponse(err);
  }
});
