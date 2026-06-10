import { ErrorCodes, VoiceError } from "./errors.ts";

const OPENAI_BASE = "https://api.openai.com/v1";
const TIMEOUT_MS = 30_000;
const USER_AGENT = "fitness-tracker-voice/whisper";

/// Gym/nutrition vocabulary hint passed to Whisper. Improves recognition of
/// terms the generic English model otherwise mishears (`bench press` → `walk me lunch`,
/// `RPE` → `R&P`, etc). Kept short — Whisper's `prompt` field truncates around
/// 224 tokens.
export const WHISPER_VOCABULARY_PROMPT =
  "Workout logging. Exercises: bench press, incline press, decline press, dumbbell flyes, " +
  "push-ups, cable crossover, pull-ups, chin-ups, barbell row, dumbbell row, deadlift, " +
  "lat pulldown, T-bar row, seated cable row, overhead press, Arnold press, lateral raises, " +
  "front raises, rear delt flyes, face pulls, barbell curl, dumbbell curl, hammer curl, " +
  "preacher curl, concentration curl, tricep dips, tricep pushdown, overhead tricep extension, " +
  "skull crushers, close-grip bench press, wrist curl, squat, front squat, leg press, lunges, " +
  "Bulgarian split squat, leg extension, leg curl, Romanian deadlift, Nordic curls, calf raises, " +
  "crunches, sit-ups, planks, side planks, Russian twists, hanging leg raises, ab wheel rollout, " +
  "cable crunches, shrugs, upright row. Units: kilograms, kg, pounds, lbs, reps, sets, RPE, " +
  "intensity. Nutrition: protein, carbs, fats, calories, grams, macros. Commands: log, edit, " +
  "delete, change, update.";

// Injectable fetch for testing.
let _fetch: typeof fetch = globalThis.fetch;
export function _setFetch(f: typeof fetch): void {
  _fetch = f;
}

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

export interface TranscriptionRequest {
  audio: Blob;
  filename: string;
  language?: string; // ISO-639-1, e.g. "en"
}

export interface TranscriptionResponse {
  text: string;
  durationSeconds: number;
}

// Confidence thresholds for the silence/hallucination gate. OpenAI's own docs
// flag `avg_logprob < -1` as unreliable and high `no_speech_prob` combined with
// low `avg_logprob` as a silent segment. A real one-word confirm ("Confirm.")
// in practice has no_speech_prob ≈ 0.05 and avg_logprob ≈ -0.4, well clear of
// these bounds — the gate only catches genuine silence/noise hallucinations.
const NO_SPEECH_PROB_MAX = 0.6;
const AVG_LOGPROB_MIN = -1.0;

/**
 * Pure, exported, unit-tested. Returns "" when Whisper's per-segment
 * confidence indicates the clip is silence or noise that the model
 * hallucinated into a fluent sentence (e.g. "For more information visit
 * www.fema.gov" on a near-silent recording).
 *
 * IMPORTANT: only gates when segment-level confidence is PRESENT. If
 * `segments` is missing or empty, we cannot judge confidence, so we pass the
 * raw text through unchanged. This is both safer (no false-negatives on
 * legitimate responses that omit segments) and non-breaking for existing
 * tests whose mocks emit `{text, duration}` without segments.
 *
 * The `verbose_json` response shape (top-level `text`, `duration`,
 * `segments[]` with `no_speech_prob` and `avg_logprob`) was verified against
 * the OpenAI audio API reference before this helper was written.
 *
 * Returns the (whitespace-trimmed) text on pass; empty string on gate.
 */
export function gateHallucinatedTranscript(json: unknown): string {
  const obj = (json ?? {}) as Record<string, unknown>;
  const rawText = typeof obj.text === "string" ? obj.text.trim() : "";
  if (rawText === "") return "";
  const segments = Array.isArray(obj.segments)
    ? (obj.segments as Array<Record<string, unknown>>)
    : [];
  if (segments.length === 0) return rawText; // can't judge → pass through
  const noSpeechProbs = segments
    .map((s) => Number(s.no_speech_prob))
    .filter((n) => Number.isFinite(n));
  const avgLogprobs = segments
    .map((s) => Number(s.avg_logprob))
    .filter((n) => Number.isFinite(n));
  if (noSpeechProbs.length === 0 || avgLogprobs.length === 0) return rawText;
  const maxNoSpeech = Math.max(...noSpeechProbs);
  const minAvgLogprob = Math.min(...avgLogprobs);
  const isSilence = maxNoSpeech >= NO_SPEECH_PROB_MAX &&
    minAvgLogprob <= AVG_LOGPROB_MIN;
  return isSilence ? "" : rawText;
}

/// Calls OpenAI Whisper `/v1/audio/transcriptions` with `response_format=verbose_json`
/// so the response includes the audio `duration` field needed for cost accounting.
/// The gym-jargon `WHISPER_VOCABULARY_PROMPT` is sent as the `prompt` field to bias
/// recognition toward exercise/nutrition terms.
export async function transcribeAudio(
  req: TranscriptionRequest,
): Promise<TranscriptionResponse> {
  const form = new FormData();
  form.append("file", req.audio, req.filename);
  form.append("model", "whisper-1");
  form.append("response_format", "verbose_json");
  form.append("prompt", WHISPER_VOCABULARY_PROMPT);
  if (req.language) form.append("language", req.language);

  const res = await withTimeout((signal) =>
    _fetch(`${OPENAI_BASE}/audio/transcriptions`, {
      method: "POST",
      headers: new Headers({
        Authorization: `Bearer ${getApiKey()}`,
        "User-Agent": USER_AGENT,
      }),
      body: form,
      signal,
    })
  );

  if (!res.ok) mapOpenAiStatus(res.status);

  const json = await res.json();
  // Gate on Whisper's per-segment confidence — when no_speech_prob is high
  // AND avg_logprob is low, the clip is silence/noise that Whisper
  // hallucinated into a fluent sentence. Empty text falls through to the
  // client's existing `text.isEmpty` branch (reprompt-once-then-idle), so
  // the user never sees a phantom turn. Billing still uses the raw duration
  // because the audio was processed regardless of gating.
  const text = gateHallucinatedTranscript(json);
  // `duration` is a float in seconds; bill the ceiling so partial seconds
  // are not free.
  const rawDuration = typeof json.duration === "number" ? json.duration : 0;
  const durationSeconds = Math.max(1, Math.ceil(rawDuration));

  return { text, durationSeconds };
}
