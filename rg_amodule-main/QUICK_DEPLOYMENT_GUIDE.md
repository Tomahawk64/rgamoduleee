# QUICK START - RAZORPAY DEPLOYMENT GUIDE

## For Developers & DevOps

### Step 1: Clone & Setup (Local Development)
```bash
# Clone repo
git clone <repo>
cd rg_amodule-main

# Install dependencies
flutter pub get

# Run tests to verify
flutter test
# Expected: ✅ 80+ tests passing
```

### Step 2: Configure Local Environment
```bash
# Set environment variables for local testing
export RAZORPAY_KEY_ID="rzp_test_YOUR_TEST_KEY"
export RAZORPAY_KEY_SECRET="YOUR_TEST_SECRET"

# Or on Windows (PowerShell):
$env:RAZORPAY_KEY_ID="rzp_test_YOUR_TEST_KEY"
$env:RAZORPAY_KEY_SECRET="YOUR_TEST_SECRET"
```

### Step 3: Verify Code is Clean
```bash
# Run analyzer
flutter analyze lib/payment lib/shop/screens lib/booking/screens lib/special_poojas/screens
# Expected: ✅ No issues found

# Run specific payment tests
flutter test test/payment/
# Expected: ✅ All payment tests passing
```

### Step 4: Deploy Database Migration
```bash
# Link to Supabase project
supabase link --project-ref esxttdierlivqpblpnyw

# Deploy migration
supabase db push --linked
# Expected: ✅ Tables created (payment_logs, shopping_carts, payment_reminders)
```

### Step 5: Configure Supabase Edge Function Secrets
```bash
# Get your Razorpay credentials
# From: https://dashboard.razorpay.com/app/keys

# Set secrets
supabase secrets set RAZORPAY_KEY_ID "rzp_live_YOUR_PRODUCTION_KEY"
supabase secrets set RAZORPAY_KEY_SECRET "YOUR_PRODUCTION_SECRET"

# Verify secrets are set
supabase secrets list
# Expected: ✅ RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET listed
```

### Step 6: Deploy Edge Functions
```bash
# Deploy create-razorpay-order function
supabase functions deploy create-razorpay-order

# Deploy verify-razorpay-payment function
supabase functions deploy verify-razorpay-payment

# Verify functions are deployed
supabase functions list
# Expected: ✅ Both functions listed as deployed
```

### Step 7: Build & Deploy App
```bash
# For Android APK (development/testing):
flutter build apk \
  --dart-define=RAZORPAY_KEY_ID=rzp_test_YOUR_TEST_KEY \
  --dart-define=RAZORPAY_KEY_SECRET=YOUR_TEST_SECRET

# For Android APK (production):
flutter build apk --release \
  --dart-define=RAZORPAY_KEY_ID=rzp_live_YOUR_PROD_KEY \
  --dart-define=RAZORPAY_KEY_SECRET=YOUR_PROD_SECRET

# For iOS IPA (production):
flutter build ios --release \
  --dart-define=RAZORPAY_KEY_ID=rzp_live_YOUR_PROD_KEY \
  --dart-define=RAZORPAY_KEY_SECRET=YOUR_PROD_SECRET

# Deploy to stores
# Google Play: flutter pub pub login; flutter pub publish
# Apple App Store: Use Xcode or fastlane
```

### Step 8: Verify Deployment
```bash
# Check all systems are working:

# 1. Test database connection
supabase db connect
SELECT COUNT(*) FROM public.payment_logs;
# Expected: ✅ Table exists and returns row count

# 2. Test edge functions
supabase functions invoke create-razorpay-order --debug
# Expected: ✅ Function response or auth error (not deployment error)

# 3. Test app build locally
flutter run --dart-define=RAZORPAY_KEY_ID=... --dart-define=RAZORPAY_KEY_SECRET=...
# Expected: ✅ App runs without errors
```

---

## Environment Variables Reference

### For Flutter Build (Compile-Time):
```bash
RAZORPAY_KEY_ID        # Razorpay Account Key ID (starts with rzp_live_ or rzp_test_)
RAZORPAY_KEY_SECRET    # Razorpay Account Key Secret (keep secure!)
```

### For Supabase Edge Functions:
```
RAZORPAY_KEY_ID        # Same as above
RAZORPAY_KEY_SECRET    # Same as above (set via: supabase secrets set)
```

---

## Production Checklist

- [ ] Razorpay account created and active
- [ ] Razorpay API keys obtained (rzp_live_* for production)
- [ ] Supabase project linked and ready
- [ ] Environment variables configured in CI/CD
- [ ] Database migration deployed to production Supabase
- [ ] Edge functions deployed with credentials
- [ ] All 80+ tests passing locally
- [ ] Flutter analyzer: Clean (no issues)
- [ ] App builds successfully with credentials
- [ ] Manual testing complete (3 payment flows working)
- [ ] Code pushed to main branch
- [ ] App deployed to Google Play Store
- [ ] App deployed to Apple App Store
- [ ] Monitoring configured for payment failures

---

## Troubleshooting

### "String.fromEnvironment returned null"
**Issue:** Razorpay Key not provided at build time
```bash
# Fix: Add --dart-define flags
flutter build apk \
  --dart-define=RAZORPAY_KEY_ID=your_key_id \
  --dart-define=RAZORPAY_KEY_SECRET=your_secret
```

### "Supabase function invocation failed"
**Issue:** Edge function secrets not configured
```bash
# Fix: Set secrets and redeploy
supabase secrets set RAZORPAY_KEY_ID xxx
supabase secrets set RAZORPAY_KEY_SECRET yyy
supabase functions deploy verify-razorpay-payment
```

### "Payment modal not opening"
**Issue:** Razorpay SDK not initialized properly
```bash
# Fix: Check:
# 1. PaymentRequest amount > 0
# 2. Customer email and phone provided
# 3. Razorpay key ID is valid (rzp_* format)
# 4. Network connectivity available
```

### "Order creation fails after payment success"
**Issue:** Database migration not deployed
```bash
# Fix: Deploy migration
supabase link --project-ref <project_id>
supabase db push --linked
```

---

## Useful Commands

### Check Supabase Status
```bash
supabase status
```

### View Supabase Logs
```bash
supabase functions logs verify-razorpay-payment
```

### Test Payment Function Locally
```bash
supabase functions serve
# Then in another terminal:
curl -X POST http://localhost:54321/functions/v1/verify-razorpay-payment \
  -H "Content-Type: application/json" \
  -d '{"order_id":"test","payment_id":"test","signature":"test"}'
```

### View Payment Logs in Database
```bash
supabase db push --dry-run  # Preview changes
supabase db connect        # Connect to database
SELECT * FROM payment_logs LIMIT 10;
```

---

## Support Resources

- **Razorpay Docs:** https://razorpay.com/docs/
- **Flutter Docs:** https://flutter.dev/docs
- **Supabase Docs:** https://supabase.com/docs
- **Project Docs:** See E2E_VALIDATION_REPORT.md and RAZORPAY_DELIVERY_SUMMARY.md

---

**Status:** ✅ Ready for production deployment
