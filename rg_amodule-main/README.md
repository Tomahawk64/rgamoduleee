# Saral Pooja

Production-oriented Flutter Android app for pooja services with User, Pandit,
and Admin roles. Razorpay checkout runs in the mobile app, while order creation
and signature verification stay in Supabase Edge Functions.

## Structure

```text
android/              Android host project
assets/images/        Bundled app imagery
lib/main.dart         App entrypoint
lib/src/core/         Runtime configuration
lib/src/domain/       Domain models and enums
lib/src/data/         Repository and service implementations
lib/src/presentation/ Riverpod, routing, and screens
supabase/migrations/  Clean schema, RLS, and seed data
supabase/functions/   Razorpay, Cloudflare R2, and maintenance functions
test/                 Focused app/domain tests
```

## Configuration

Pass secrets and backend config with `--dart-define`; do not commit secrets.

For local development, copy `.env.example` to `.env` and fill in the Supabase
values. Then use the helper scripts below, which pass those values to Flutter as
compile-time defines.

```powershell
.\scripts\run_supabase_android.ps1
.\scripts\build_supabase_apk.ps1
.\scripts\setup_client_demo_accounts.ps1
```

`setup_client_demo_accounts.ps1` requires `SUPABASE_SERVICE_ROLE_KEY` in `.env`.
Use it only locally; never ship or commit the service role key.

For a client-review APK, set `CLIENT_DEMO_ACCESS=true` in `.env`. The APK will
still initialize Supabase and include only the public Razorpay key id, but login
uses the seeded review accounts below so all roles are available immediately:

| Role | Email | Password |
| --- | --- | --- |
| User | `client.user@saralpooja.app` | `Saral@Client2026` |
| Pandit | `client.pandit@saralpooja.app` | `Saral@Client2026` |
| Admin | `client.admin@saralpooja.app` | `Saral@Client2026` |

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=RAZORPAY_KEY_ID=rzp_live_or_test_key \
  --dart-define=CLIENT_DEMO_ACCESS=true \
  --dart-define=CLOUDFLARE_UPLOAD_FUNCTION=cloudflare-r2-upload-url
```

If Supabase env values are omitted, the app runs against the in-memory demo
repository for local UI/testing.

## Supabase

Apply migrations:

```bash
supabase db push
```

Deploy functions:

```bash
supabase functions deploy create-razorpay-order
supabase functions deploy verify-razorpay-payment-v2
supabase functions deploy cloudflare-r2-upload-url
supabase functions deploy run-scheduled-maintenance
```

Required function secrets:

```text
RAZORPAY_KEY_ID
RAZORPAY_KEY_SECRET
SUPABASE_SERVICE_ROLE_KEY
R2_ACCOUNT_ID
R2_ACCESS_KEY_ID
R2_SECRET_ACCESS_KEY
R2_BUCKET
R2_PUBLIC_BASE_URL optional
MAINTENANCE_TOKEN for scheduled maintenance calls
```

## Verify

```bash
flutter analyze
flutter test
flutter build apk --debug
```
