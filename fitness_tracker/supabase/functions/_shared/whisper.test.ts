import { assertEquals, assertRejects } from "@std/assert";
import {
  _setFetch,
  gateHallucinatedTranscript,
  transcribeAudio,
  WHISPER_VOCABULARY_PROMPT,
} from "./whisper.ts";
import { ErrorCodes, VoiceError } from "./errors.ts";

if (!Deno.env.get("OPENAI_API_KEY")) {
  Deno.env.set("OPENAI_API_KEY", "sk-test-dummy-key");
}

const realFetch = globalThis.fetch;

function mockFetch(response: Response): void {
  _setFetch(() => Promise.resolve(response));
}

function restoreFetch(): void {
  _setFetch(realFetch);
}

function makeAudioBlob(): Blob {
  return new Blob([new Uint8Array([0, 1, 2, 3, 4, 5])], { type: "audio/m4a" });
}

Deno.test("transcribeAudio: parses verbose_json response and ceilings duration", async () => {
  mockFetch(
    new Response(
      JSON.stringify({
        text: "log bench press 80 kilograms 10 reps",
        language: "english",
        duration: 4.3,
      }),
      { status: 200 },
    ),
  );
  try {
    const result = await transcribeAudio({
      audio: makeAudioBlob(),
      filename: "test.m4a",
    });
    assertEquals(result.text, "log bench press 80 kilograms 10 reps");
    assertEquals(result.durationSeconds, 5);
  } finally {
    restoreFetch();
  }
});

Deno.test("transcribeAudio: floors duration at 1 second when reported as 0", async () => {
  mockFetch(
    new Response(
      JSON.stringify({ text: "hi", duration: 0 }),
      { status: 200 },
    ),
  );
  try {
    const result = await transcribeAudio({
      audio: makeAudioBlob(),
      filename: "test.m4a",
    });
    assertEquals(result.durationSeconds, 1);
  } finally {
    restoreFetch();
  }
});

Deno.test("transcribeAudio: trims whitespace from text", async () => {
  mockFetch(
    new Response(
      JSON.stringify({ text: "  log squat 100 kg 5 reps  ", duration: 3 }),
      { status: 200 },
    ),
  );
  try {
    const result = await transcribeAudio({
      audio: makeAudioBlob(),
      filename: "test.m4a",
    });
    assertEquals(result.text, "log squat 100 kg 5 reps");
  } finally {
    restoreFetch();
  }
});

Deno.test("transcribeAudio: 429 → RATE_LIMITED", async () => {
  mockFetch(new Response("{}", { status: 429 }));
  try {
    await assertRejects(
      () => transcribeAudio({ audio: makeAudioBlob(), filename: "x.m4a" }),
      VoiceError,
      "OpenAI rate limit",
    );
  } finally {
    restoreFetch();
  }
});

Deno.test("transcribeAudio: 401 → OPENAI_UNAVAILABLE (server misconfig)", async () => {
  mockFetch(new Response("{}", { status: 401 }));
  try {
    const err = await assertRejects(
      () => transcribeAudio({ audio: makeAudioBlob(), filename: "x.m4a" }),
      VoiceError,
    ) as VoiceError;
    assertEquals(err.code, ErrorCodes.OPENAI_UNAVAILABLE);
    assertEquals(err.httpStatus, 502);
  } finally {
    restoreFetch();
  }
});

Deno.test("transcribeAudio: 500 → OPENAI_UNAVAILABLE", async () => {
  mockFetch(new Response("{}", { status: 500 }));
  try {
    const err = await assertRejects(
      () => transcribeAudio({ audio: makeAudioBlob(), filename: "x.m4a" }),
      VoiceError,
    ) as VoiceError;
    assertEquals(err.code, ErrorCodes.OPENAI_UNAVAILABLE);
  } finally {
    restoreFetch();
  }
});

Deno.test("transcribeAudio: missing OPENAI_API_KEY → OPENAI_UNAVAILABLE", async () => {
  const original = Deno.env.get("OPENAI_API_KEY");
  Deno.env.delete("OPENAI_API_KEY");
  try {
    await assertRejects(
      () => transcribeAudio({ audio: makeAudioBlob(), filename: "x.m4a" }),
      VoiceError,
      "misconfigured",
    );
  } finally {
    if (original) Deno.env.set("OPENAI_API_KEY", original);
  }
});

// ---------------------------------------------------------------------------
// gateHallucinatedTranscript — pure helper that drops silence/noise clips
// Whisper hallucinated into fluent prose. Verified against the OpenAI
// verbose_json schema (segments[].no_speech_prob, segments[].avg_logprob).
// ---------------------------------------------------------------------------

Deno.test("gateHallucinatedTranscript: drops a silence-hallucination (high no_speech_prob + low avg_logprob)", () => {
  const json = {
    text: "For more information visit www.fema.gov",
    duration: 2.1,
    segments: [
      { no_speech_prob: 0.95, avg_logprob: -1.8 },
    ],
  };
  assertEquals(gateHallucinatedTranscript(json), "");
});

Deno.test("gateHallucinatedTranscript: passes a real speech clip through unchanged", () => {
  const json = {
    text: "log bench press 80 kilograms 10 reps",
    duration: 4.3,
    segments: [
      { no_speech_prob: 0.02, avg_logprob: -0.25 },
    ],
  };
  assertEquals(
    gateHallucinatedTranscript(json),
    "log bench press 80 kilograms 10 reps",
  );
});

Deno.test("gateHallucinatedTranscript: does NOT gate a real one-word confirm", () => {
  // Regression: a single-word "Confirm." (~0.5 s) is real speech and must
  // never be silenced — the confirm classifier downstream depends on it.
  const json = {
    text: "Confirm.",
    duration: 0.6,
    segments: [
      { no_speech_prob: 0.05, avg_logprob: -0.4 },
    ],
  };
  assertEquals(gateHallucinatedTranscript(json), "Confirm.");
});

Deno.test("gateHallucinatedTranscript: high no_speech_prob alone gates (clause a)", () => {
  // Clause (a): very high no_speech_prob alone is enough — this is the case
  // the previous AND-only gate missed. A hallucinated phrase on pure noise
  // can have a normal-looking avg_logprob, so we cannot require both.
  const json = {
    text: "thanks for watching",
    duration: 1.0,
    segments: [{ no_speech_prob: 0.9, avg_logprob: -0.3 }],
  };
  assertEquals(gateHallucinatedTranscript(json), "");
});

Deno.test("gateHallucinatedTranscript: SOFT no_speech + low avg_logprob gates (clause b)", () => {
  // Clause (b): a moderately high no_speech_prob combined with a low
  // avg_logprob is the classic low-confidence hallucination signature.
  const json = {
    text: "you",
    duration: 0.4,
    segments: [{ no_speech_prob: 0.55, avg_logprob: -1.2 }],
  };
  assertEquals(gateHallucinatedTranscript(json), "");
});

Deno.test("gateHallucinatedTranscript: low no_speech + low avg_logprob does NOT gate", () => {
  // Regression guard: a real but acoustically difficult word can produce a
  // low avg_logprob with a low no_speech_prob. Neither clause should fire.
  const json = {
    text: "log squat",
    duration: 1.0,
    segments: [{ no_speech_prob: 0.4, avg_logprob: -1.5 }],
  };
  assertEquals(gateHallucinatedTranscript(json), "log squat");
});

Deno.test("gateHallucinatedTranscript: exact boundary (== thresholds) gates", () => {
  // Clause (b) thresholds use `>=` / `<=`, so a value sitting exactly on the
  // line is treated as silence. Documented so future tuning is intentional.
  const json = {
    text: "you",
    duration: 0.4,
    segments: [{ no_speech_prob: 0.5, avg_logprob: -1.0 }],
  };
  assertEquals(gateHallucinatedTranscript(json), "");
});

Deno.test("gateHallucinatedTranscript: passes through when segments missing", () => {
  // Cannot judge → trust raw text. Keeps every existing test (whose mock
  // omits segments) green and never silences a legitimate response that
  // omits per-segment confidence.
  assertEquals(
    gateHallucinatedTranscript({ text: "hello", duration: 1 }),
    "hello",
  );
});

Deno.test("gateHallucinatedTranscript: passes through when segments empty", () => {
  assertEquals(
    gateHallucinatedTranscript({
      text: "hello",
      duration: 1,
      segments: [],
    }),
    "hello",
  );
});

Deno.test("gateHallucinatedTranscript: returns trimmed text on pass-through", () => {
  const json = {
    text: "  log squat 100 kg  ",
    duration: 2,
    segments: [{ no_speech_prob: 0.02, avg_logprob: -0.2 }],
  };
  assertEquals(gateHallucinatedTranscript(json), "log squat 100 kg");
});

Deno.test("gateHallucinatedTranscript: empty text input returns empty", () => {
  assertEquals(gateHallucinatedTranscript({ text: "", duration: 0 }), "");
  assertEquals(gateHallucinatedTranscript({ duration: 0 }), "");
  assertEquals(gateHallucinatedTranscript(null), "");
  assertEquals(gateHallucinatedTranscript(undefined), "");
});

Deno.test("gateHallucinatedTranscript: uses max no_speech and min avg_logprob across multi-segment clips", () => {
  // Multi-segment clip where the WORST segment trips the gate — even if one
  // segment looks clean, a single high-confidence-silence segment in a
  // mostly-silent recording is what we want to catch.
  const json = {
    text: "Thanks for watching. Please subscribe.",
    duration: 4,
    segments: [
      { no_speech_prob: 0.55, avg_logprob: -0.9 }, // borderline
      { no_speech_prob: 0.92, avg_logprob: -1.7 }, // silence → trips gate
    ],
  };
  assertEquals(gateHallucinatedTranscript(json), "");
});

Deno.test("gateHallucinatedTranscript: ignores non-numeric confidence values in a segment", () => {
  // Defensive: a malformed segment must not throw or crash Math.max/min.
  const json = {
    text: "log bench press",
    duration: 2,
    segments: [
      { no_speech_prob: "bad", avg_logprob: "bad" },
      { no_speech_prob: 0.03, avg_logprob: -0.3 },
    ],
  };
  assertEquals(gateHallucinatedTranscript(json), "log bench press");
});

Deno.test("transcribeAudio: gates a silence-hallucination at the response boundary", async () => {
  // End-to-end: when the Whisper response includes high-no_speech_prob /
  // low-avg_logprob segments, transcribeAudio returns an empty transcript so
  // the client treats the upload as no-speech and never spawns a ghost turn.
  mockFetch(
    new Response(
      JSON.stringify({
        text: "For more information visit www.fema.gov",
        duration: 2.0,
        segments: [{ no_speech_prob: 0.95, avg_logprob: -1.8 }],
      }),
      { status: 200 },
    ),
  );
  try {
    const result = await transcribeAudio({
      audio: makeAudioBlob(),
      filename: "silence.m4a",
    });
    assertEquals(result.text, "");
    // Duration is still billed — audio was processed regardless of gating.
    assertEquals(result.durationSeconds, 2);
  } finally {
    restoreFetch();
  }
});

Deno.test("WHISPER_VOCABULARY_PROMPT contains gym-jargon terms", () => {
  // Regression: if the prompt is accidentally emptied, recognition quality
  // drops back to generic English. Pin the key terms.
  const required = [
    "bench press",
    "deadlift",
    "squat",
    "protein",
    "reps",
    "kilograms",
  ];
  for (const term of required) {
    if (!WHISPER_VOCABULARY_PROMPT.toLowerCase().includes(term)) {
      throw new Error(
        `Whisper vocabulary prompt missing required term: "${term}"`,
      );
    }
  }
});
