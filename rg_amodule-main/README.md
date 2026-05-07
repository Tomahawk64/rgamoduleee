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

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=RAZORPAY_KEY_ID=rzp_live_or_test_key \
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
