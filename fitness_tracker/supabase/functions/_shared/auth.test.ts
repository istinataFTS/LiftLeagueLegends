import { assertEquals, assertRejects } from "@std/assert";
import { authenticate } from "./auth.ts";
import { ErrorCodes, VoiceError } from "./errors.ts";
import type { SupabaseClient } from "@supabase/supabase-js";

// Minimal Supabase client stub for auth tests.
function makeAuthClient(
  result: { user: unknown | null; error: unknown | null },
) {
  return {
    auth: {
      getUser: (_jwt: string) =>
        Promise.resolve({ data: { user: result.user }, error: result.error }),
    },
  } as unknown as SupabaseClient;
}

function makeReq(authHeader?: string): Request {
  const headers = new Headers();
  if (authHeader !== undefined) headers.set("Authorization", authHeader);
  return new Request("https://example.com/", { method: "POST", headers });
}

Deno.test("authenticate: missing Authorization header → UNAUTHORIZED 401", async () => {
  const req = makeReq();
  const err = await assertRejects(
    () => authenticate(req, makeAuthClient({ user: null, error: null })),
    VoiceError,
  );
  assertEquals(err.code, ErrorCodes.UNAUTHORIZED);
  assertEquals(err.httpStatus, 401);
});

Deno.test("authenticate: malformed header (no Bearer prefix) → UNAUTHORIZED 401", async () => {
  const req = makeReq("Token abc123");
  const err = await assertRejects(
    () => authenticate(req, makeAuthClient({ user: null, error: null })),
    VoiceError,
  );
  assertEquals(err.code, ErrorCodes.UNAUTHORIZED);
});

Deno.test("authenticate: Supabase returns error → UNAUTHORIZED 401", async () => {
  const req = makeReq("Bearer bad-jwt");
  const client = makeAuthClient({
    user: null,
    error: { message: "invalid jwt" },
  });
  const err = await assertRejects(() => authenticate(req, client), VoiceError);
  assertEquals(err.code, ErrorCodes.UNAUTHORIZED);
  assertEquals(err.httpStatus, 401);
});

Deno.test("authenticate: null user from Supabase → UNAUTHORIZED 401", async () => {
  const req = makeReq("Bearer some-jwt");
  const client = makeAuthClient({ user: null, error: null });
  const err = await assertRejects(() => authenticate(req, client), VoiceError);
  assertEquals(err.code, ErrorCodes.UNAUTHORIZED);
});

Deno.test("authenticate: anonymous user → GUEST_FORBIDDEN 403", async () => {
  const req = makeReq("Bearer anon-jwt");
  const client = makeAuthClient({
    user: { id: "uuid-1", is_anonymous: true },
    error: null,
  });
  const err = await assertRejects(() => authenticate(req, client), VoiceError);
  assertEquals(err.code, ErrorCodes.GUEST_FORBIDDEN);
  assertEquals(err.httpStatus, 403);
});

Deno.test("authenticate: valid authenticated user → returns { id, jwt }", async () => {
  const req = makeReq("Bearer valid-jwt");
  const client = makeAuthClient({
    user: { id: "user-uuid-123", is_anonymous: false },
    error: null,
  });
  const result = await authenticate(req, client);
  assertEquals(result.id, "user-uuid-123");
  assertEquals(result.jwt, "valid-jwt");
});
