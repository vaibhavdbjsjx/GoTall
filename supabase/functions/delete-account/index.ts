// Deletes the calling user's account and backup. For Sign in with Apple accounts, also revokes the app's Apple
// token (App Store Review Guideline 5.1.1(v)). The app sends a fresh authorization code from Apple for that.
//
// Secrets (supabase secrets set ...):
//   APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY (the .p8 contents), APPLE_CLIENT_ID (the app's bundle ID)
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase automatically.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "npm:jose@5.9.6";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

async function appleClientSecret(): Promise<string | null> {
  const teamId = Deno.env.get("APPLE_TEAM_ID");
  const keyId = Deno.env.get("APPLE_KEY_ID");
  const privateKey = Deno.env.get("APPLE_PRIVATE_KEY");
  const clientId = Deno.env.get("APPLE_CLIENT_ID");
  if (!teamId || !keyId || !privateKey || !clientId) return null;
  const key = await importPKCS8(privateKey.replace(/\\n/g, "\n"), "ES256");
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt()
    .setExpirationTime("5m")
    .setAudience("https://appleid.apple.com")
    .setSubject(clientId)
    .sign(key);
}

async function revokeApple(code: string): Promise<void> {
  const clientId = Deno.env.get("APPLE_CLIENT_ID");
  const secret = await appleClientSecret();
  if (!clientId || !secret) {
    console.warn("Apple secrets missing; skipping token revocation");
    return;
  }
  const form = (fields: Record<string, string>) => new URLSearchParams(fields);
  const tokenResponse = await fetch("https://appleid.apple.com/auth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: form({ client_id: clientId, client_secret: secret, code, grant_type: "authorization_code" }),
  });
  if (!tokenResponse.ok) {
    console.warn("Apple code exchange failed", tokenResponse.status);
    return;
  }
  const tokens = await tokenResponse.json();
  const token = tokens.refresh_token ?? tokens.access_token;
  if (!token) return;
  await fetch("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: form({
      client_id: clientId,
      client_secret: secret,
      token,
      token_type_hint: tokens.refresh_token ? "refresh_token" : "access_token",
    }),
  });
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json(405, { message: "Use POST" });
  const authorization = request.headers.get("Authorization") ?? "";
  const jwt = authorization.replace(/^Bearer\s+/i, "");
  if (!jwt) return json(401, { message: "Not signed in" });

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  const { data: userData, error: userError } = await admin.auth.getUser(jwt);
  if (userError || !userData?.user) return json(401, { message: "Not signed in" });
  const user = userData.user;

  let body: { apple_authorization_code?: string } = {};
  try {
    body = await request.json();
  } catch {
    // empty body is fine
  }

  if (body.apple_authorization_code) {
    try {
      await revokeApple(body.apple_authorization_code);
    } catch (error) {
      console.warn("Apple revocation error", error);
    }
  }

  const { error: backupError } = await admin.from("backups").delete().eq("user_id", user.id);
  if (backupError) return json(500, { message: "Couldn't delete the backup. Please try again." });
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) return json(500, { message: "Couldn't delete the account. Please try again." });
  return json(200, { deleted: true });
});
