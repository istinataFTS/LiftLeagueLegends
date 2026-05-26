import { assertEquals, assertRejects } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { transcribeAudio, _setFetch, WHISPER_VOCABULARY_PROMPT } from './whisper.ts';
import { ErrorCodes, VoiceError } from './errors.ts';

if (!Deno.env.get('OPENAI_API_KEY')) {
  Deno.env.set('OPENAI_API_KEY', 'sk-test-dummy-key');
}

const realFetch = globalThis.fetch;

function mockFetch(response: Response): void {
  _setFetch(() => Promise.resolve(response));
}

function restoreFetch(): void {
  _setFetch(realFetch);
}

function makeAudioBlob(): Blob {
  return new Blob([new Uint8Array([0, 1, 2, 3, 4, 5])], { type: 'audio/m4a' });
}

Deno.test('transcribeAudio: parses verbose_json response and ceilings duration', async () => {
  mockFetch(
    new Response(
      JSON.stringify({
        text: 'log bench press 80 kilograms 10 reps',
        language: 'english',
        duration: 4.3,
      }),
      { status: 200 },
    ),
  );
  try {
    const result = await transcribeAudio({
      audio: makeAudioBlob(),
      filename: 'test.m4a',
    });
    assertEquals(result.text, 'log bench press 80 kilograms 10 reps');
    assertEquals(result.durationSeconds, 5);
  } finally {
    restoreFetch();
  }
});

Deno.test('transcribeAudio: floors duration at 1 second when reported as 0', async () => {
  mockFetch(
    new Response(
      JSON.stringify({ text: 'hi', duration: 0 }),
      { status: 200 },
    ),
  );
  try {
    const result = await transcribeAudio({
      audio: makeAudioBlob(),
      filename: 'test.m4a',
    });
    assertEquals(result.durationSeconds, 1);
  } finally {
    restoreFetch();
  }
});

Deno.test('transcribeAudio: trims whitespace from text', async () => {
  mockFetch(
    new Response(
      JSON.stringify({ text: '  log squat 100 kg 5 reps  ', duration: 3 }),
      { status: 200 },
    ),
  );
  try {
    const result = await transcribeAudio({
      audio: makeAudioBlob(),
      filename: 'test.m4a',
    });
    assertEquals(result.text, 'log squat 100 kg 5 reps');
  } finally {
    restoreFetch();
  }
});

Deno.test('transcribeAudio: 429 → RATE_LIMITED', async () => {
  mockFetch(new Response('{}', { status: 429 }));
  try {
    await assertRejects(
      () => transcribeAudio({ audio: makeAudioBlob(), filename: 'x.m4a' }),
      VoiceError,
      'OpenAI rate limit',
    );
  } finally {
    restoreFetch();
  }
});

Deno.test('transcribeAudio: 401 → OPENAI_UNAVAILABLE (server misconfig)', async () => {
  mockFetch(new Response('{}', { status: 401 }));
  try {
    const err = await assertRejects(
      () => transcribeAudio({ audio: makeAudioBlob(), filename: 'x.m4a' }),
      VoiceError,
    ) as VoiceError;
    assertEquals(err.code, ErrorCodes.OPENAI_UNAVAILABLE);
    assertEquals(err.httpStatus, 502);
  } finally {
    restoreFetch();
  }
});

Deno.test('transcribeAudio: 500 → OPENAI_UNAVAILABLE', async () => {
  mockFetch(new Response('{}', { status: 500 }));
  try {
    const err = await assertRejects(
      () => transcribeAudio({ audio: makeAudioBlob(), filename: 'x.m4a' }),
      VoiceError,
    ) as VoiceError;
    assertEquals(err.code, ErrorCodes.OPENAI_UNAVAILABLE);
  } finally {
    restoreFetch();
  }
});

Deno.test('transcribeAudio: missing OPENAI_API_KEY → OPENAI_UNAVAILABLE', async () => {
  const original = Deno.env.get('OPENAI_API_KEY');
  Deno.env.delete('OPENAI_API_KEY');
  try {
    await assertRejects(
      () => transcribeAudio({ audio: makeAudioBlob(), filename: 'x.m4a' }),
      VoiceError,
      'misconfigured',
    );
  } finally {
    if (original) Deno.env.set('OPENAI_API_KEY', original);
  }
});

Deno.test('WHISPER_VOCABULARY_PROMPT contains gym-jargon terms', () => {
  // Regression: if the prompt is accidentally emptied, recognition quality
  // drops back to generic English. Pin the key terms.
  const required = ['bench press', 'deadlift', 'squat', 'protein', 'reps', 'kilograms'];
  for (const term of required) {
    if (!WHISPER_VOCABULARY_PROMPT.toLowerCase().includes(term)) {
      throw new Error(`Whisper vocabulary prompt missing required term: "${term}"`);
    }
  }
});
