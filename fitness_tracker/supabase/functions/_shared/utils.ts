import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { CORS_HEADERS } from "./cors.ts";

export function serviceClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) {
    throw new Error(
      "Service client misconfigured: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set",
    );
  }
  return createClient(url, key);
}

export function msSince(t0: number): number {
  return Math.round(performance.now() - t0);
}

export function json(
  status: number,
  body: unknown,
  extraHeaders?: Record<string, string>,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json",
      ...(extraHeaders ?? {}),
    },
  });
}
