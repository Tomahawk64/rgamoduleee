# Quick Start Guide - Cart & Payment System

## 🚀 Getting Started in 5 Steps

### Step 1: Run Database Migration
```bash
# From project root
supabase migration up

# Or if you need to reset:
supabase db push
```

This creates:
- `shopping_carts` table
- Updated `orders` table with payment fields
- `payment_logs` table
- `payment_reminders` table

### Step 2: Deploy Supabase Functions
```bash
# Deploy payment order creation function
supabase functions deploy create-razorpay-order

# Deploy payment verification function
supabase functions deploy verify-razorpay-payment

# Verify functions are deployed
supabase functions list
```

### Step 3: Add Dependencies (if not already installed)
```bash
flutter pub get

# Key dependencies already in pubspec.yaml:
# - razorpay_flutter: ^1.3.6
# - supabase_flutter: ^2.3.4
# - flutter_riverpod: ^2.5.1
# - dio: ^5.4.0
```

### Step 4: Configure App Router (if needed)
Update your app router to include the new checkout screen:

```dart
// In lib/core/router/app_router.dart
GoRoute(
  path: 'checkout-v2',
  name: 'checkout-v2',
  builder: (context, state) => const CheckoutScreenV2(),
),
```

### Step 5: Run the App
```bash
# Clean build
flutter clean

# Get packages
flutter pub get

# Run on mobile (Razorpay payment works on Android/iOS)
flutter run

# Or build APK
flutter build apk --release
```

---

## 🧪 Quick Test Flow

### Test as User
1. **Open app** → Navigate to Shop
2. **Add items** → Cart shows items
3. **Click Checkout** → Goes to `CheckoutScreenV2`
4. **Fill form** → Name, email, phone, address
5. **Select Razorpay** → Choose payment method
6. **Tap Pay** → Razorpay SDK opens
7. **Complete payment** → Use test card:
   - Card: `4111 1111 1111 1111`
   - Expiry: `12/25`
   - CVV: `123`
8. **Success!** → Order created, cart cleared
9. **View order** → Navigate to Orders tab

### Test as Admin
1. **Login as admin**
2. **Navigate to Admin → Orders**
3. **See pending orders** → Filter by "Pending Payment"
4. **Send reminder** → Click "Send Reminder" button
5. **Mark as paid** → Manual confirmation option
6. **View details** → Full order information

---

## 📱 App Navigation

```
Home
├── Shop Tab
│   ├── Product List
│   ├── Add to Cart
│   ├── View Cart
│   └── Checkout [NEW]
│       ├── Order Summary
│       ├── Delivery Details
│       ├── Payment Method Selection
│       └── Razorpay Payment
└── Orders Tab
    ├── My Orders
    ├── Payment Status [UPDATED]
    └── Order Details

Admin Panel [NEW ORDER MANAGEMENT]
├── Admin Home
├── Orders Management [NEW]
│   ├── Filter by Payment Status
│   ├── Search Orders
│   ├── Send Payment Reminders
│   └── Mark as Paid
└── ... (existing admin screens)
```

---

## 🔑 Razorpay Test Credentials

**Test Key ID:**
```
rzp_test_SVVU9qRyec0rdR
```

**Test Key Secret:**
```
Yx5REGSkT9DMlLFBvDSrXEZF
```

**Test Payment Methods:**
- ✅ Cards: `4111 1111 1111 1111` (any future date, any CVV)
- ✅ UPI: Any UPI ID
- ✅ Wallets: NetBanking, PayPal (if enabled)

---

## ✅ Implementation Checklist

### Backend
- [x] Database migration created
- [x] Edge functions created (create-razorpay-order, verify-razorpay-payment)
- [x] RLS policies configured
- [x] RPC functions created

### Frontend
- [x] Cart repository with database persistence
- [x] Cart provider V2 with Riverpod
- [x] Razorpay payment service V2
- [x] Order service
- [x] Checkout screen V2
- [x] Admin orders management screen

### Features
- [x] Persistent cart storage
- [x] Cart auto-restoration
- [x] Order creation from cart
- [x] Razorpay payment integration
- [x] Server-side payment verification
- [x] Payment status tracking
- [x] Admin payment management
- [x] Payment reminders
- [x] Notifications

### Security
- [x] HMAC-SHA256 signature verification
- [x] Row-level security
- [x] Audit logging
- [x] Error tracking

---

## 🛠️ Troubleshooting

### Build Errors

**Error: `razorpay_flutter` plugin not found**
```bash
# Solution:
flutter pub get
flutter clean
flutter pub get
```

**Error: `import 'package:razorpay_flutter/razorpay_flutter.dart'` not found**
```bash
# Add to pubspec.yaml:
dependencies:
  razorpay_flutter: ^1.3.6

# Then:
flutter pub get
```

### Runtime Errors

**Error: "Payment gateway not configured"**
```dart
// Solution: Check RazorpayPaymentServiceV2 has keys
static const String _keyId = 'rzp_test_SVVU9qRyec0rdR';
static const String _keySecret = 'Yx5REGSkT9DMlLFBvDSrXEZF';
```

**Error: "Cart not loading from database"**
```dart
// Solution: Ensure authenticated and check RLS
final userId = supabase.auth.currentUser?.id;
if (userId == null) {
  // User not authenticated
}
```

**Error: "Edge function not found"**
```bash
# Solution: Deploy functions
supabase functions deploy create-razorpay-order
supabase functions deploy verify-razorpay-payment

# Verify
supabase functions list
```

### Payment Issues

**Payment doesn't process**
- ✅ Check internet connection
- ✅ Verify Razorpay keys in code
- ✅ Check if running on Android/iOS (not web)
- ✅ Check database migrations ran

**Order not created after payment**
- ✅ Check Edge Function logs
- ✅ Verify `orders` table exists
- ✅ Check user is authenticated
- ✅ Review `payment_logs` table for errors

---

## 📊 Monitoring

### Check Database Status

```sql
-- Count orders
SELECT COUNT(*) FROM orders;

-- See recent payments
SELECT * FROM payment_logs ORDER BY created_at DESC LIMIT 10;

-- Check pending payments
SELECT * FROM payment_reminders WHERE is_resolved = false;

-- View cart data
SELECT * FROM shopping_carts;
```

### Check Edge Function Logs

```bash
# View function logs
supabase functions logs create-razorpay-order
supabase functions logs verify-razorpay-payment
```

### Monitor Real-time Data

```dart
// Listen to order updates
supabase
  .from('orders')
  .on(RealtimeListenTypes.all, (payload) {
    print('Order updated: ${payload.newRecord}');
  })
  .subscribe();
```

---

## 🎓 Learning Resources

### Razorpay Documentation
- https://razorpay.com/docs/payments/
- https://razorpay.com/docs/payments/payment-gateway/web-integration/standard/
- Test cards: https://razorpay.com/docs/payments/payments/payment-methods/cards/test-cards/

### Supabase Documentation
- https://supabase.com/docs
- Edge Functions: https://supabase.com/docs/guides/functions
- RLS: https://supabase.com/docs/guides/auth/row-level-security

### Flutter Documentation
- Riverpod: https://riverpod.dev/
- GoRouter: https://pub.dev/packages/go_router

---

## 🚀 Production Deployment

### Before Going Live

1. **Replace Test Keys with Live Keys**
   ```dart
   // In RazorpayPaymentServiceV2
   static const String _keyId = 'rzp_live_YOUR_LIVE_KEY';
   static const String _keySecret = 'YOUR_LIVE_SECRET';
   ```

2. **Update Environment Configuration**
   ```bash
   # Update .env or secrets
   RAZORPAY_KEY_ID=rzp_live_...
   RAZORPAY_KEY_SECRET=...
   ```

3. **Test in Production Mode**
   - Use live Razorpay keys on test server
   - Process test payments with live amount
   - Verify bank settlement

4. **Enable Webhook Integration** (Optional)
   - Add webhook URL in Razorpay dashboard
   - Process payment notifications
   - Update order status in real-time

5. **Run Final Tests**
   - [ ] Create test order
   - [ ] Complete payment
   - [ ] Verify in admin dashboard
   - [ ] Check database records
   - [ ] Verify notifications

---

## 📞 Support

### File Locations

```
supabase/
├── migrations/
│   └── 024_payment_tracking_and_cart.sql
└── functions/
    ├── create-razorpay-order/
    │   └── index.ts
    └── verify-razorpay-payment/
        └── index.ts

lib/
├── payment/
│   ├── services/
│   │   ├── razorpay_payment_service_v2.dart
│   │   └── order_service.dart
│   └── payment_provider.dart
├── shop/
│   ├── repository/
│   │   └── cart_repository.dart
│   ├── providers/
│   │   └── cart_provider_v2.dart
│   └── screens/
│       └── checkout_screen_v2.dart
└── admin/
    └── screens/
        └── admin_orders_screen.dart
```

### Key Files
- **Database**: `CART_PAYMENT_IMPLEMENTATION.md`
- **Setup Guide**: This file
- **Implementation Details**: `supabase/migrations/024_payment_tracking_and_cart.sql`

---

**Last Updated:** April 21, 2026  
**Status:** ✅ Production Ready  
**Razorpay Mode:** Test ✅
