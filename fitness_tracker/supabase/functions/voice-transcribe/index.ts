import { authenticate } from "../_shared/auth.ts";
import { assertWithinBudget, getBudgetState } from "../_shared/budget.ts";
import { costForWhisper } from "../_shared/cost.ts";
import { preflight } from "../_shared/cors.ts";
import { ErrorCodes, errorResponse, VoiceError } from "../_shared/errors.ts";
import { transcribeAudio } from "../_shared/whisper.ts";
import type { FunctionName } from "../_shared/types.ts";
import { logUsage } from "../_shared/usage.ts";
import { json, msSince, serviceClient } from "../_shared/utils.ts";

const FUNCTION_NAME: FunctionName = "voice-transcribe";
const MODEL = "whisper-1";

/// Hard cap on the audio file size accepted by this endpoint. Whisper's own
/// hard limit is 25 MB; we cap lower (4 MB ~= 2-3 minutes of m4a/aac) to
/// match the client's `whisperMaxAudioSeconds` envelope and reject runaway
/// uploads early.
const MAX_AUDIO_BYTES = 4 * 1024 * 1024;

interface ParsedTranscription {
  audio: Blob;
  filename: string;
  language?: string;
  sessionId?: string;
}

async function parseTranscription(req: Request): Promise<ParsedTranscription> {
  const contentType = req.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().startsWith("multipart/form-data")) {
    throw new VoiceError(
      ErrorCodes.INVALID_REQUEST,
      "Request must be multipart/form-data",
      400,
    );
  }

  let form: FormData;
  try {
    form = await req.formData();
  } catch {
    throw new VoiceError(
      ErrorCodes.INVALID_REQUEST,
      "Malformed multipart body",
      400,
    );
  }

  const file = form.get("file");
  if (!(file instanceof File) && !(file instanceof Blob)) {
    throw new VoiceError(
      ErrorCodes.INVALID_REQUEST,
      "Missing required field: file",
      400,
    );
  }

  if (file.size === 0) {
    throw new VoiceError(
      ErrorCodes.INVALID_REQUEST,
      "Audio file is empty",
      400,
    );
  }

  if (file.size > MAX_AUDIO_BYTES) {
    throw new VoiceError(
      ErrorCodes.INVALID_REQUEST,
      `Audio file exceeds ${MAX_AUDIO_BYTES} bytes`,
      413,
    );
  }

  const filename = file instanceof File ? file.name : "audio.m4a";
  const language = form.get("language");
  const sessionId = form.get("session_id");

  return {
    audio: file,
    filename,
    language: typeof language === "string" && language.length > 0
      ? language
      : undefined,
    sessionId: typeof sessionId === "string" && sessionId.length > 0
      ? sessionId
      : undefined,
  };
}

async function handleTranscription(
  req: Request,
  t0: number,
): Promise<Response> {
  const user = await authenticate(req);
  const parsed = await parseTranscription(req);
  const supabase = serviceClient();

  await assertWithinBudget(supabase, user.id);

  let transcription: Awaited<ReturnType<typeof transcribeAudio>>;
  try {
    transcription = await transcribeAudio({
      audio: parsed.audio,
      filename: parsed.filename,
      language: parsed.language ?? "en",
    });
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

  const cost = costForWhisper(MODEL, transcription.durationSeconds);

  await logUsage(supabase, {
    userId: user.id,
    functionName: FUNCTION_NAME,
    model: MODEL,
    // Audio seconds are recorded in `input_tokens` so the daily-budget gate
    // and pricing audits can correlate cost with audio duration without a
    // schema migration. Whisper has no concept of output tokens.
    inputTokens: transcription.durationSeconds,
    latencyMs: msSince(t0),
    sessionId: parsed.sessionId,
    status: "OK",
  }, cost);

  const { remainingUsd } = await getBudgetState(supabase, user.id);

  return json(200, {
    transcript: transcription.text,
    duration_seconds: transcription.durationSeconds,
    cost_usd: cost,
    remaining_budget_usd: remainingUsd,
    request_id: crypto.randomUUID(),
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
    return await handleTranscription(req, t0);
  } catch (err) {
    return errorResponse(err);
  }
});
