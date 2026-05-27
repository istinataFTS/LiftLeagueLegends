export const PRICING_VERSION = "2026-05-26";

// USD per unit. Verify against https://openai.com/api/pricing before each release.
// TTS is device-native (free). STT was device-native until the Whisper
// migration — Whisper is billed per second of audio.
const PRICES = {
  "gpt-4o-mini-2024-07-18": {
    perInputToken: 0.150 / 1_000_000,
    perOutputToken: 0.600 / 1_000_000,
  },
  "whisper-1": {
    perAudioSecond: 0.006 / 60, // $0.006/minute → $0.0001/second
  },
} as const;

type ChatPricingModel = "gpt-4o-mini-2024-07-18";
type WhisperPricingModel = "whisper-1";

export function costForChat(
  model: ChatPricingModel,
  inputTokens: number,
  outputTokens: number,
): number {
  const pricing = PRICES[model];
  return round6(
    inputTokens * pricing.perInputToken + outputTokens * pricing.perOutputToken,
  );
}

/// Cost of one Whisper transcription. OpenAI bills audio in 1-second
/// increments rounded up to the nearest second; callers should pass the
/// integer ceiling of the duration in seconds.
export function costForWhisper(
  model: WhisperPricingModel,
  audioSeconds: number,
): number {
  const pricing = PRICES[model];
  return round6(audioSeconds * pricing.perAudioSecond);
}

export function round6(usd: number): number {
  return Math.round(usd * 1_000_000) / 1_000_000;
}
