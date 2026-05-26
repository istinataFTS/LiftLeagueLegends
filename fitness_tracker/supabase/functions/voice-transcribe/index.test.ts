// Integration tests for voice-transcribe.
// Whisper (audio transcriptions) is mocked via _setFetch from whisper.ts.

if (!Deno.env.get('OPENAI_API_KEY')) {
  Deno.env.set('OPENAI_API_KEY', 'sk-test-dummy-key');
}

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { _setFetch, transcribeAudio } from '../_shared/whisper.ts';
import { ErrorCodes } from '../_shared/errors.ts';
import { costForWhisper } from '../_shared/cost.ts';
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

const REAL_FETCH = globalThis.fetch;

function makeTranscribeClient(budgetRows: Array<{ cost_usd: number }> = []) {
  const inserted: unknown[] = [];
  const client = {
    from: (_t: string) => ({
      select: () => ({
        eq: () => ({ gte: () => Promise.resolve({ data: budgetRows, error: null }) }),
      }),
      insert: (r: unknown) => { inserted.push(r); return Promise.resolve({ error: null }); },
    }),
  } as unknown as SupabaseClient;
  return { client, inserted };
}

function mockWhisperResponse(text: string, duration: number): void {
  _setFetch(() =>
    Promise.resolve(
      new Response(
        JSON.stringify({ text, duration, language: 'english' }),
        { status: 200 },
      ),
    )
  );
}

function makeAudioBlob(bytes = 1024): Blob {
  return new Blob([new Uint8Array(bytes)], { type: 'audio/m4a' });
}

// ---------------------------------------------------------------------------

Deno.test('voice-transcribe: preflight OPTIONS returns 204', async () => {
  const { preflight } = await import('../_shared/cors.ts');
  const req = new Request('https://fn/voice-transcribe', { method: 'OPTIONS' });
  assertEquals(preflight(req)?.status, 204);
});

Deno.test('voice-transcribe: missing Authorization → UNAUTHORIZED', async () => {
  const form = new FormData();
  form.append('file', new File([makeAudioBlob()], 'test.m4a'));
  const req = new Request('https://fn/voice-transcribe', { method: 'POST', body: form });

  const { authenticate } = await import('../_shared/auth.ts');
  const mockClient = {
    auth: { getUser: () => Promise.resolve({ data: { user: null }, error: { message: 'no auth' } }) },
  } as unknown as SupabaseClient;

  try {
    await authenticate(req, mockClient);
    throw new Error('Expected VoiceError');
  } catch (e) {
    assertEquals((e as { code: string }).code, ErrorCodes.UNAUTHORIZED);
  }
});

Deno.test('voice-transcribe: guest token → GUEST_FORBIDDEN', async () => {
  const req = new Request('https://fn/voice-transcribe', {
    method: 'POST',
    headers: { Authorization: 'Bearer guest-jwt' },
  });
  const { authenticate } = await import('../_shared/auth.ts');
  const mockClient = {
    auth: { getUser: () => Promise.resolve({ data: { user: { id: 'uid', is_anonymous: true } }, error: null }) },
  } as unknown as SupabaseClient;

  try {
    await authenticate(req, mockClient);
    throw new Error('Expected VoiceError');
  } catch (e) {
    assertEquals((e as { code: string }).code, ErrorCodes.GUEST_FORBIDDEN);
  }
});

Deno.test('voice-transcribe: budget exceeded → BUDGET_EXCEEDED, no Whisper call', async () => {
  let whisperCalled = false;
  _setFetch(() => { whisperCalled = true; return Promise.resolve(new Response('', { status: 200 })); });

  const { assertWithinBudget } = await import('../_shared/budget.ts');
  const { client } = makeTranscribeClient([{ cost_usd: 0.6 }]);

  try {
    await assertWithinBudget(client, 'user-1');
    throw new Error('Expected VoiceError');
  } catch (e) {
    assertEquals((e as { code: string }).code, ErrorCodes.BUDGET_EXCEEDED);
  } finally {
    assertEquals(whisperCalled, false);
    _setFetch(REAL_FETCH);
  }
});

Deno.test('voice-transcribe: Whisper error → OPENAI_UNAVAILABLE + error usage row', async () => {
  _setFetch(() => Promise.resolve(new Response('', { status: 503 })));
  const { inserted, client } = makeTranscribeClient();
  const { logUsage } = await import('../_shared/usage.ts');

  let caughtCode: string | null = null;
  try {
    await transcribeAudio({ audio: makeAudioBlob(), filename: 't.m4a' });
  } catch (e) {
    caughtCode = (e as { code: string }).code;
    await logUsage(client, {
      userId: 'u', functionName: 'voice-transcribe', model: 'whisper-1',
      latencyMs: 100, status: caughtCode,
    }, 0);
  } finally {
    _setFetch(REAL_FETCH);
  }

  assertEquals(caughtCode, ErrorCodes.OPENAI_UNAVAILABLE);
  assertEquals(inserted.length, 1);
  assertEquals((inserted[0] as { status: string }).status, ErrorCodes.OPENAI_UNAVAILABLE);
});

Deno.test('voice-transcribe: happy path → transcript + correct cost row', async () => {
  mockWhisperResponse('log bench press 80 kilograms 10 reps', 4.3);
  const { inserted, client } = makeTranscribeClient();
  const { logUsage } = await import('../_shared/usage.ts');

  try {
    const result = await transcribeAudio({
      audio: makeAudioBlob(),
      filename: 'test.m4a',
    });
    assertEquals(result.text, 'log bench press 80 kilograms 10 reps');
    assertEquals(result.durationSeconds, 5);

    const cost = costForWhisper('whisper-1', result.durationSeconds);
    await logUsage(client, {
      userId: 'u', functionName: 'voice-transcribe', model: 'whisper-1',
      inputTokens: result.durationSeconds, latencyMs: 200, status: 'OK',
    }, cost);

    assertEquals(inserted.length, 1);
    const row = inserted[0] as { status: string; cost_usd: number; input_tokens: number };
    assertEquals(row.status, 'OK');
    assertEquals(row.input_tokens, 5);
    // 5 seconds × ($0.006/60) = $0.0005
    assertEquals(row.cost_usd, 0.0005);
  } finally {
    _setFetch(REAL_FETCH);
  }
});

Deno.test('costForWhisper: bills audio at $0.006/minute', () => {
  // 60 seconds = $0.006
  assertEquals(costForWhisper('whisper-1', 60), 0.006);
  // 30 seconds = $0.003
  assertEquals(costForWhisper('whisper-1', 30), 0.003);
  // 1 second = $0.0001
  assertEquals(costForWhisper('whisper-1', 1), 0.0001);
});
