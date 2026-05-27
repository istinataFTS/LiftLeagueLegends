// Wildcard origin is intentional. This API serves a native mobile app
// (iOS / Android) which does not send an Origin header — origin-based
// restrictions are ineffective. Access control is enforced via Supabase
// JWT auth on every request, not CORS. Supabase's own Edge Function
// docs recommend '*' for mobile-only backends.
export const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
} as const;

export function preflight(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  return null;
}
