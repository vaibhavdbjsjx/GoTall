# Accounts and backup: backend setup

Accounts in Stature are optional. With no backend configured the Account row is hidden and the app is fully local, exactly as before. Turning accounts on takes about 20 minutes.

## What it is

- **Supabase** (free tier is enough to launch): Auth for Sign in with Apple and email/password, one Postgres table `backups` protected by row-level security, and one Edge Function `delete-account`.
- No third-party SDK in the app: `Sources/GrowthCore/Account/AccountBackend.swift` talks to Supabase over HTTPS.
- Tokens are stored in the Keychain (`KeychainSessionStorage`), never in the profile file.

## Steps

1. Create a project at supabase.com. Pick a region near your users. Note the **Project URL** and **anon public key** (Project Settings › API).
2. Database: run `supabase/migrations/20261021000000_backups.sql` in the SQL editor (or `supabase db push` with the CLI).
3. Auth › Providers:
   - **Email**: on. Turn "Confirm email" on (recommended). Set Site URL to `https://stature.netlify.app`.
   - **Apple**: on. Client IDs: `app.stature.height`. This is the native flow, so no Services ID or secret is needed for sign-in itself.
4. Apple Developer › Certificates, IDs & Profiles:
   - App ID `app.stature.height`: enable **Sign in with Apple**.
   - Keys: create a key with Sign in with Apple enabled. Download the `.p8`, note the Key ID and your Team ID. This is for revoking tokens when someone deletes their account (required by App Review).
5. Edge Function:
   ```
   supabase functions deploy delete-account
   supabase secrets set APPLE_TEAM_ID=XXXXXXXXXX APPLE_KEY_ID=YYYYYYYYYY APPLE_CLIENT_ID=app.stature.height
   supabase secrets set APPLE_PRIVATE_KEY="$(cat AuthKey_YYYYYYYYYY.p8)"
   ```
6. App: in `App/project.yml` set
   ```
   STATURE_BACKEND_URL: "https://<project-ref>.supabase.co"
   STATURE_BACKEND_ANON_KEY: "<anon public key>"
   ```
   then `cd App && xcodegen generate`. The anon key is meant to be public; row-level security keeps each account's backup private.
7. Email templates (Auth › Email Templates): change the sender name to Stature and the support address to support@stature.app. For production, add custom SMTP so emails don't come from Supabase's shared sender.

## How backup works

- Signing in on a phone that already has data asks once: use the backup, or keep this iPhone's data (which then becomes the backup). Automatic backups wait until that choice is made, so a new phone never overwrites an existing backup by accident.
- After that, changes are backed up about 5 seconds after they happen (can be turned off in Profile › Account).
- The backup is the same JSON the app saves on the device, one row per account.

## Deleting an account

Profile › Account › Delete account calls the Edge Function, which deletes the backup row and the auth user. For Apple accounts the app first asks Apple for a fresh authorization code; the function exchanges it and calls Apple's `/auth/revoke`. Data on the phone is left alone (Profile › Privacy & data › Delete all data removes it).
