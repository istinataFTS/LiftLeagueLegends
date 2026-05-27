import { CORS_HEADERS } from "./cors.ts";

export const ErrorCodes = {
  UNAUTHORIZED: "UNAUTHORIZED",
  GUEST_FORBIDDEN: "GUEST_FORBIDDEN",
  BUDGET_EXCEEDED: "BUDGET_EXCEEDED",
  INVALID_REQUEST: "INVALID_REQUEST",
  OPENAI_UNAVAILABLE: "OPENAI_UNAVAILABLE",
  RATE_LIMITED: "RATE_LIMITED",
  TIMEOUT: "TIMEOUT",
  INTERNAL: "INTERNAL",
} as const;

export type ErrorCode = (typeof ErrorCodes)[keyof typeof ErrorCodes];

export class VoiceError extends Error {
  constructor(
    public readonly code: ErrorCode,
    message: string,
    public readonly httpStatus: number,
  ) {
    super(message);
    this.name = "VoiceError";
  }
}

/**
 * Builds an error response. Always sets CORS headers and JSON content-type;
 * callers may pass `extraHeaders` for function-specific additions
 * (typically none — function handlers send extra headers only on success).
 */
export function errorResponse(
  err: unknown,
  extraHeaders?: Record<string, string>,
): Response {
  const headers = {
    ...CORS_HEADERS,
    "Content-Type": "application/json",
    ...(extraHeaders ?? {}),
  };

  if (err instanceof VoiceError) {
    return new Response(
      JSON.stringify({ code: err.code, message: err.message }),
      { status: err.httpStatus, headers },
    );
  }

  console.error("[voice] unhandled error:", err);
  return new Response(
    JSON.stringify({
      code: ErrorCodes.INTERNAL,
      message: "Internal server error",
    }),
    { status: 500, headers },
  );
}
