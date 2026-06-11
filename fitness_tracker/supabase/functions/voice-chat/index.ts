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
  ToolCall,
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

**Internal identifiers — never reveal.** The bracketed \`[id: …]\` values in the
recent sets and logs above are internal database identifiers. Use them ONLY to fill
the \`setId\` / \`logId\` argument of an edit or delete tool call. You MUST NEVER speak,
read aloud, repeat, or write an id — or the bracketed \`[id: …]\` text — in any reply
to the user. Ids are meaningless to the user and must stay internal.

**Answer data questions only through a query tool.** To answer ANY question about the
user's logged data — their recent sets, what they last lifted, weekly volume, daily
macros, or what they ate or trained on a given day — you MUST emit the matching query
tool call (\`getRecentSets\`, \`getRecentNutrition\`, \`getWeeklyVolume\`,
\`getDailyMacros\`, \`getDailyNutritionLog\`, \`getWorkoutForDay\`, or
\`getTrainingDays\`). The client
runs it locally and speaks an id-free result. You MUST NOT answer such a question by
writing your own prose from the recent-sets/-logs context above — that risks leaking
internal ids and produces inconsistent output.

The recent sets/logs above are a **truncated hint** (a few recent rows), **not** the
user's full history. NEVER conclude that something was not logged, or answer any
"what did I log / eat / lift on <day>" question, from that list. You MUST call the
matching query tool and let the client speak the result.

Tool usage rules:
- Use logWorkoutSet / logNutrition to record new entries. Confirm before calling.
- **Duplicates are always allowed.** A workout set or nutrition entry that is identical to an existing one (same exercise/meal, weight, reps, intensity, macros, or date) is a valid, separate log — users repeat the same set across sessions all the time. When the user asks to log something, you MUST emit logWorkoutSet / logNutrition. NEVER refuse, and NEVER suggest editing the existing entry instead, just because a matching entry already exists. The recent sets/logs context is for resolving edit/delete targets ONLY — it is NOT a uniqueness constraint.
- For edits and deletes, find the row ID from the recent sets/logs above.
- For queries (getWeeklyVolume, getDailyMacros, getRecentSets, getRecentNutrition, getDailyNutritionLog, getWorkoutForDay, getTrainingDays), call the tool — the app will execute it locally and speak the result; you do not need to generate a verbal summary.
- Use clarify only when the user's intent cannot be resolved without one specific question.
- Whenever you need ANY information from the user before you can act — a missing field, a yes/no, a disambiguation — you MUST ask via the \`clarify\` tool, never as a plain assistant message. A plain message is treated as a final statement and ends the conversation; only a \`clarify\` call keeps the microphone open for the user's answer.
- If the user confirms ("yes", "do it", "confirm"), and you have enough data, call the mutation tool immediately without re-asking.
- Never repeat a clarifying question you already asked.

**TOOL CALL CONTRACT — NON-NEGOTIABLE:**

After any user turn that confirms a previously read-back mutation (responses such as "yes", "yeah", "yep", "do it", "go ahead", "confirm", "log it", "save it"), you **MUST** emit the corresponding tool call (\`logWorkoutSet\`, \`logNutrition\`, \`editWorkoutSet\`, \`editNutritionLog\`, \`deleteWorkoutSet\`, or \`deleteNutritionLog\`). You **MUST NOT** reply with prose alone — such as "Set logged.", "Done.", "Logged.", "Saved.", "Got it." — when a mutation should have been performed. The client speaks the success message itself based on the actual tool dispatch; if you reply with prose claiming a mutation happened without emitting a tool call, the user's data is silently lost.

When the user provides every required field for a mutation in a single utterance (exercise/meal, quantity, reps/grams, and — for sets — intensity), you SHOULD emit the tool call directly without re-asking for confirmation; the client will render a confirmation card from your tool-call arguments.

- For multi-field edits, prefer issuing one \`clarify\` per ambiguous field rather than expecting the user to dictate every field at once. Example: if the user says "change my breakfast macros," ask "What should the protein be?" — then on the next turn ask about carbs, etc. The 15-second STT window can accept short multi-field utterances, but a clarify-per-field loop is more reliable than a multi-field utterance.

**Dates.** When the user refers to a day — "today", "yesterday", "Monday", "the 8th", or an anaphor like "that day" / "this day" meaning a day mentioned earlier in the conversation — you MUST resolve it to an explicit \`yyyy-MM-dd\` and pass it as the \`date\` argument of \`getWorkoutForDay\`, \`getDailyNutritionLog\`, and \`getDailyMacros\`. Never omit \`date\` and never assume "today" when the user pointed at a different day.`;

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

// ---------------------------------------------------------------------------
// Server-side guard — defense in depth against the LLM claiming a mutation
// succeeded in plain text without emitting a tool_call.
// ---------------------------------------------------------------------------

// Matches common affirmative confirmation phrases at the start of a message.
const AFFIRMATION_REGEX =
  /^\s*(yes|yeah|yep|yup|sure|ok|okay|do it|go ahead|confirm(ed)?|please do|log it|save it|sounds good)\b/i;

// Matches responses that claim a mutation succeeded without a tool_call.
const SUCCESS_CLAIM_REGEX =
  /\b(set|workout|nutrition|meal|log|entry)\s+(logged|added|saved|recorded|updated|deleted|done)\b/i;
const SUCCESS_SHORT_REGEX = /^(done|logged|saved|noted)\.?$/i;

export const GUARD_CORRECTIVE_MESSAGE =
  "Sorry, I didn't actually log that. Please repeat your request.";

export interface GuardResult {
  tripped: boolean;
  responseContent: string | undefined;
}

/**
 * Detects when the LLM returned success-claiming prose without emitting the
 * required tool_call after the user confirmed a mutation. When tripped,
 * returns a corrective message; otherwise passes through chatResult.message.
 *
 * Exported for direct unit testing.
 *
 * Guard conditions (ALL must hold):
 *   1. No tool_call in the LLM response.
 *   2. Current user message is an affirmative confirmation.
 *   3. LLM response content matches a known success-claim pattern.
 */
export function applyAssistantGuard(
  userMessage: string,
  chatResult: { toolCall?: unknown; message?: string },
): GuardResult {
  if (
    chatResult.toolCall !== undefined ||
    !AFFIRMATION_REGEX.test(userMessage) ||
    chatResult.message === undefined ||
    (!SUCCESS_CLAIM_REGEX.test(chatResult.message) &&
      !SUCCESS_SHORT_REGEX.test(chatResult.message))
  ) {
    return { tripped: false, responseContent: chatResult.message };
  }
  return { tripped: true, responseContent: GUARD_CORRECTIVE_MESSAGE };
}

// A no-tool-call assistant message ending in a question mark is a clarify the
// model failed to route through the `clarify` tool — `tool_choice:"auto"` does
// not force it (see openai.ts:133-134). Left as a plain message, the client
// treats it as a final statement and goes idle without re-opening the mic. This
// re-tags such a reply as a `clarify` tool call so the client re-listens. Pure
// and exported for direct unit testing.
// See KNOWN_ISSUES.md #voice-clarify-questions-must-be-coerced-to-the-clarify-tool.
const QUESTION_TAIL = /\?\s*$/;

export function coerceQuestionToClarify(
  chatResult: { toolCall?: ToolCall; message?: string },
): ToolCall | undefined {
  if (chatResult.toolCall !== undefined) return undefined;
  // Sanitize first. The client speaks `arguments.question` verbatim and, unlike
  // a `kind:"message"` reply, a tool call never passes through the
  // response-shaping `sanitizeAssistantText`, so strip ids here to keep the
  // never-surface-ids guarantee (KNOWN_ISSUES.md
  // #voice-bot-must-never-surface-internal-ids). Test the question-mark tail on
  // the sanitized text so a trailing "[id: …]" cannot hide the "?".
  const msg = sanitizeAssistantText(chatResult.message)?.trim();
  if (!msg || !QUESTION_TAIL.test(msg)) return undefined;
  return {
    id: `clarify_${crypto.randomUUID()}`,
    name: "clarify",
    arguments: { question: msg },
  };
}

// Strips internal identifiers from assistant *message* text. Defense-in-depth:
// the prompt forbids surfacing ids, but this guarantees it even if the model
// disobeys. Tool calls are unaffected — their structured args are consumed by the
// client and never spoken. See KNOWN_ISSUES.md
// `#voice-bot-must-never-surface-internal-ids`.
const _UUID =
  /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/g;
const _BRACKETED_ID = /\s*[\[(]\s*id:\s*[0-9a-fA-F-]{36}\s*[\])]/gi;

export function sanitizeAssistantText(
  input: string | undefined,
): string | undefined {
  if (input === undefined) return undefined;
  return input
    .replace(_BRACKETED_ID, "")
    .replace(_UUID, "")
    .replace(/[ \t]{2,}/g, " ")
    .replace(/[ \t]+([.,!?])/g, "$1")
    .trim();
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

  // Apply the guard before billing so the status row reflects the real outcome.
  const guard = applyAssistantGuard(parsed.userMessage, chatResult);
  if (guard.tripped) {
    console.warn(
      "[voice-chat] guard: LLM claimed success without tool_call; rewriting response",
      {
        sessionId: parsed.sessionId,
        userMessage: parsed.userMessage,
        llmContent: chatResult.message,
      },
    );
  }
  const safeContent = sanitizeAssistantText(guard.responseContent);

  // A question the model returned as prose (instead of a `clarify` tool call)
  // is re-tagged here so the client keeps the mic open. Applied to the
  // guard-resolved content; GUARD_CORRECTIVE_MESSAGE ends in "request." (not
  // "?") so it is never coerced — it stays a statement (DECISION: do not
  // re-open the mic on the corrective). Setting `chatResult.toolCall` makes the
  // existing tool_call branches below handle session logging and the
  // `kind:"tool_call"` response automatically; the client already re-listens
  // for `clarify` (supabase_voice_remote_datasource.dart:251).
  const coerced = coerceQuestionToClarify({
    message: guard.responseContent,
    toolCall: chatResult.toolCall,
  });
  if (coerced) chatResult.toolCall = coerced;

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
    status: guard.tripped ? ErrorCodes.GUARD_FAILED_TOOL_OMITTED : "OK",
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
  } else if (guard.responseContent !== undefined) {
    await appendSessionTurn(supabase, {
      sessionId: parsed.sessionId,
      userId: user.id,
      turn: { role: "assistant", content: safeContent ?? "" },
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
  return json(200, {
    kind: "message",
    content: safeContent,
    ...(guard.tripped ? { guard: "tool_omitted" } : {}),
    ...base,
  });
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
