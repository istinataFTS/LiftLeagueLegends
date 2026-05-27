import {
  createClient,
  SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";
import { AuthedUser } from "./types.ts";
import { ErrorCodes, VoiceError } from "./errors.ts";

export async function authenticate(
  req: Request,
  supabaseClient?: SupabaseClient,
): Promise<AuthedUser> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    throw new VoiceError(
      ErrorCodes.UNAUTHORIZED,
      "Missing or malformed Authorization header",
      401,
    );
  }

  const jwt = authHeader.slice(7);

  const client = supabaseClient ?? createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
  );

  const { data: { user }, error } = await client.auth.getUser(jwt);

  if (error || !user) {
    throw new VoiceError(
      ErrorCodes.UNAUTHORIZED,
      "Invalid or expired JWT",
      401,
    );
  }

  if (user.is_anonymous) {
    throw new VoiceError(
      ErrorCodes.GUEST_FORBIDDEN,
      "Voice features require an authenticated account",
      403,
    );
  }

  return { id: user.id, jwt };
}
