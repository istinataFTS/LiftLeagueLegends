// Centralised third-party dependency specifiers for the Edge Functions.
//
// The self-hosted edge-runtime router (`functions/main/index.ts`) creates every
// worker with `importMapPath: null`, so bare specifiers declared in `deno.json`
// are NOT resolved at runtime — a bare `@supabase/supabase-js` import makes the
// worker fail to bootstrap and the platform returns an opaque HTTP 500. Routing
// all third-party imports through this module with a fully-qualified `npm:`
// specifier keeps each function self-resolving regardless of import-map
// configuration, and pins the version in exactly one place.
//
// See KNOWN_ISSUES.md #voice-edge-functions-bare-import-specifiers-fail-to-boot.
export { createClient } from "npm:@supabase/supabase-js@2.106.2";
export type { SupabaseClient } from "npm:@supabase/supabase-js@2.106.2";
