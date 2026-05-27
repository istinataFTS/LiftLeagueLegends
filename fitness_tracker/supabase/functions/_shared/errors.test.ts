import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { ErrorCodes, errorResponse, VoiceError } from "./errors.ts";

Deno.test("VoiceError carries code and httpStatus", () => {
  const e = new VoiceError(ErrorCodes.UNAUTHORIZED, "No auth", 401);
  assertEquals(e.code, ErrorCodes.UNAUTHORIZED);
  assertEquals(e.httpStatus, 401);
  assertEquals(e.message, "No auth");
});

const STATUS_MAP: Array<[string, number]> = [
  [ErrorCodes.UNAUTHORIZED, 401],
  [ErrorCodes.GUEST_FORBIDDEN, 403],
  [ErrorCodes.BUDGET_EXCEEDED, 402],
  [ErrorCodes.INVALID_REQUEST, 400],
  [ErrorCodes.OPENAI_UNAVAILABLE, 502],
  [ErrorCodes.RATE_LIMITED, 429],
  [ErrorCodes.TIMEOUT, 504],
  [ErrorCodes.INTERNAL, 500],
];

for (const [code, status] of STATUS_MAP) {
  Deno.test(`errorResponse maps VoiceError(${code}) → ${status}`, async () => {
    const err = new VoiceError(code as never, "test", status);
    const res = errorResponse(err);
    assertEquals(res.status, status);
    const body = await res.json();
    assertEquals(body.code, code);
  });
}

Deno.test("errorResponse maps unknown error → 500 and returns INTERNAL code", async () => {
  const consoleSpy: unknown[] = [];
  const originalError = console.error;
  console.error = (...args: unknown[]) => consoleSpy.push(args);

  try {
    const res = errorResponse(new Error("boom"));
    assertEquals(res.status, 500);
    const body = await res.json();
    assertEquals(body.code, ErrorCodes.INTERNAL);
    assertEquals(consoleSpy.length > 0, true);
  } finally {
    console.error = originalError;
  }
});

Deno.test("errorResponse includes CORS headers", () => {
  const err = new VoiceError(ErrorCodes.INTERNAL, "x", 500);
  const res = errorResponse(err);
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), "*");
});
