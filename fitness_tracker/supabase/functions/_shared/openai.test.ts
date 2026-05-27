import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { _setFetch, completeChat } from "./openai.ts";
import { ErrorCodes, VoiceError } from "./errors.ts";

// Ensure the API-key env var is set for the bulk of tests below.
// `getApiKey()` fails fast when missing — without this shim every test
// errors before reaching the mocked fetch. The dedicated "missing key"
// test deletes and restores this value.
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

// ---------------------------------------------------------------------------
// completeChat
// ---------------------------------------------------------------------------

const chatReq = {
  history: [
    { role: "user" as const, content: "log bench press 80kg 10 reps" },
  ],
  tools: [],
};

Deno.test("completeChat: message response is parsed correctly", async () => {
  mockFetch(
    new Response(
      JSON.stringify({
        model: "gpt-4o-mini-2024-07-18",
        choices: [{ message: { content: "Got it!", tool_calls: null } }],
        usage: { prompt_tokens: 50, completion_tokens: 10 },
      }),
      { status: 200 },
    ),
  );
  try {
    const result = await completeChat(chatReq);
    assertEquals(result.message, "Got it!");
    assertEquals(result.inputTokens, 50);
    assertEquals(result.outputTokens, 10);
    assertEquals(result.toolCall, undefined);
  } finally {
    restoreFetch();
  }
});

Deno.test("completeChat: tool_call response is parsed correctly", async () => {
  mockFetch(
    new Response(
      JSON.stringify({
        model: "gpt-4o-mini-2024-07-18",
        choices: [{
          message: {
            content: null,
            tool_calls: [{
              id: "call_1",
              function: { name: "echo", arguments: '{"text":"hi"}' },
            }],
          },
        }],
        usage: { prompt_tokens: 100, completion_tokens: 20 },
      }),
      { status: 200 },
    ),
  );
  try {
    const result = await completeChat(chatReq);
    assertEquals(result.toolCall?.id, "call_1");
    assertEquals(result.toolCall?.name, "echo");
    assertEquals(result.toolCall?.arguments, { text: "hi" });
    assertEquals(result.message, undefined);
  } finally {
    restoreFetch();
  }
});

Deno.test("completeChat: Authorization header is present", async () => {
  let capturedHeaders: Headers = new Headers();
  _setFetch((_, opts) => {
    capturedHeaders = new Headers(opts?.headers as HeadersInit);
    return Promise.resolve(
      new Response(
        JSON.stringify({
          model: "gpt-4o-mini-2024-07-18",
          choices: [{ message: { content: "ok", tool_calls: null } }],
          usage: { prompt_tokens: 10, completion_tokens: 5 },
        }),
        { status: 200 },
      ),
    );
  });
  try {
    await completeChat(chatReq);
    assertEquals(capturedHeaders?.has("Authorization"), true);
  } finally {
    restoreFetch();
  }
});

Deno.test("completeChat: HTTP 429 → RATE_LIMITED", async () => {
  mockFetch(new Response("", { status: 429 }));
  try {
    const err = await assertRejects(() => completeChat(chatReq), VoiceError);
    assertEquals(err.code, ErrorCodes.RATE_LIMITED);
  } finally {
    restoreFetch();
  }
});

Deno.test("completeChat: HTTP 503 → OPENAI_UNAVAILABLE 502", async () => {
  mockFetch(new Response("", { status: 503 }));
  try {
    const err = await assertRejects(() => completeChat(chatReq), VoiceError);
    assertEquals(err.code, ErrorCodes.OPENAI_UNAVAILABLE);
    assertEquals(err.httpStatus, 502);
  } finally {
    restoreFetch();
  }
});

Deno.test("completeChat: HTTP 401 → OPENAI_UNAVAILABLE (server misconfig, not user auth)", async () => {
  // OpenAI 401/403 means OUR key is bad — not the user's JWT. Surfacing as
  // UNAUTHORIZED would mislead the client into prompting the user to sign in.
  mockFetch(new Response("", { status: 401 }));
  try {
    const err = await assertRejects(() => completeChat(chatReq), VoiceError);
    assertEquals(err.code, ErrorCodes.OPENAI_UNAVAILABLE);
    assertEquals(err.httpStatus, 502);
  } finally {
    restoreFetch();
  }
});

Deno.test("completeChat: AbortError → TIMEOUT", async () => {
  _setFetch(() =>
    Promise.reject(Object.assign(new Error("aborted"), { name: "AbortError" }))
  );
  try {
    const err = await assertRejects(() => completeChat(chatReq), VoiceError);
    assertEquals(err.code, ErrorCodes.TIMEOUT);
  } finally {
    restoreFetch();
  }
});

Deno.test("OPENAI_API_KEY missing → OPENAI_UNAVAILABLE before any HTTP call", async () => {
  // Server misconfig must surface as such, not as a per-request issue.
  const originalKey = Deno.env.get("OPENAI_API_KEY");
  Deno.env.delete("OPENAI_API_KEY");

  let fetchCalled = false;
  _setFetch(() => {
    fetchCalled = true;
    return Promise.resolve(new Response("", { status: 200 }));
  });

  try {
    const err = await assertRejects(() => completeChat(chatReq), VoiceError);
    assertEquals(err.code, ErrorCodes.OPENAI_UNAVAILABLE);
    assertEquals(err.httpStatus, 502);
    assertEquals(
      fetchCalled,
      false,
      "should not reach the network when key is missing",
    );
  } finally {
    if (originalKey !== undefined) Deno.env.set("OPENAI_API_KEY", originalKey);
    restoreFetch();
  }
});
