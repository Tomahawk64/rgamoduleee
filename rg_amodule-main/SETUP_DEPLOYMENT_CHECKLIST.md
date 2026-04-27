# Setup & Deployment Checklist

## ✅ Pre-Deployment Verification

### Database Setup
- [ ] Migration file created: `supabase/migrations/024_payment_tracking_and_cart.sql`
- [ ] Migration ran successfully: `supabase migration up`
- [ ] Verify tables exist:
  - [ ] `shopping_carts`
  - [ ] `payment_logs`
  - [ ] `payment_reminders`
  - [ ] `orders` (updated with payment fields)
- [ ] Verify indexes created:
  - [ ] `idx_orders_payment_status`
  - [ ] `idx_payment_logs_razorpay_payment_id`
  - [ ] `idx_shopping_carts_user`
- [ ] Verify RLS policies enabled:
  - [ ] `shopping_carts` RLS enabled
  - [ ] `payment_logs` RLS enabled
  - [ ] `payment_reminders` RLS enabled

### Edge Functions Deployment
- [ ] `supabase/functions/create-razorpay-order/index.ts` created
- [ ] `supabase/functions/verify-razorpay-payment/index.ts` created
- [ ] Functions deployed: `supabase functions deploy create-razorpay-order`
- [ ] Functions deployed: `supabase functions deploy verify-razorpay-payment`
- [ ] Functions verified: `supabase functions list`
- [ ] Test functions:
  - [ ] `create-razorpay-order` returns valid order ID
  - [ ] `verify-razorpay-payment` verifies signatures correctly
  - [ ] Error handling works properly

### Backend Services
- [ ] `lib/payment/services/razorpay_payment_service_v2.dart` created
  - [ ] Has correct Razorpay test keys
  - [ ] `initiatePayment()` implemented
  - [ ] `verifyPayment()` implemented
  - [ ] `_createRazorpayOrder()` calls Edge Function
  - [ ] `_logPaymentAttempt()` logs to database
  - [ ] `updatePaymentStatus()` updates order

- [ ] `lib/payment/services/order_service.dart` created
  - [ ] `SupabaseOrderService` implemented
  - [ ] `getOrder()` method works
  - [ ] `getPendingOrders()` method works
  - [ ] `createPaymentReminder()` creates reminders
  - [ ] `sendPaymentReminder()` sends notifications
  - [ ] `updateOrderPaymentStatus()` updates status

### Repositories
- [ ] `lib/shop/repository/cart_repository.dart` created
  - [ ] `ICartRepository` interface defined
  - [ ] `SupabaseCartRepository` implemented
  - [ ] `loadCart()` retrieves from database
  - [ ] `saveCart()` persists to database
  - [ ] `clearCart()` works properly

### Providers & State Management
- [ ] `lib/shop/providers/cart_provider_v2.dart` created
  - [ ] `CartControllerV2` implemented
  - [ ] `cartProviderV2` riverpod provider created
  - [ ] `addItem()`, `removeItem()`, `updateQuantity()` work
  - [ ] `saveCartToDB()` persists cart
  - [ ] `createOrderFromCart()` creates orders

- [ ] `lib/payment/payment_provider.dart` updated
  - [ ] Uses `RazorpayPaymentServiceV2`
  - [ ] Falls back to `MockPaymentService` on web
  - [ ] Service provider initialized correctly

### UI Screens
- [ ] `lib/shop/screens/checkout_screen_v2.dart` created
  - [ ] Form validation works
  - [ ] Cart summary displays correctly
  - [ ] Payment method selection works
  - [ ] Razorpay payment initiates correctly
  - [ ] Success/error handling displays properly
  - [ ] Cart clears after successful payment

- [ ] `lib/admin/screens/admin_orders_screen.dart` created
  - [ ] Orders list displays all orders
  - [ ] Payment status badges show correctly:
    - [ ] Green for completed
    - [ ] Orange for pending
    - [ ] Red for failed
  - [ ] Filter by payment status works
  - [ ] Search by order ID/customer works
  - [ ] "Send Reminder" button functional
  - [ ] "Mark as Paid" button functional
  - [ ] "View Details" shows order info

### Dependencies
- [ ] `pubspec.yaml` has all required packages:
  - [ ] `razorpay_flutter: ^1.3.6`
  - [ ] `supabase_flutter: ^2.3.4`
  - [ ] `flutter_riverpod: ^2.5.1`
  - [ ] `dio: ^5.4.0`
  - [ ] `crypto: (for HMAC verification, if added client-side)`

- [ ] Dependencies installed: `flutter pub get`
- [ ] No dependency conflicts
- [ ] No breaking changes in versions

### Documentation
- [ ] `CART_PAYMENT_IMPLEMENTATION.md` created
  - [ ] Covers architecture overview
  - [ ] Documents database schema
  - [ ] Explains all service classes
  - [ ] Includes usage examples
  - [ ] Has security section

- [ ] `QUICK_START_GUIDE.md` created
  - [ ] Step-by-step setup instructions
  - [ ] Testing checklist
  - [ ] Troubleshooting section
  - [ ] Production deployment guide

---

## 🧪 Testing Checklist

### Unit Tests (Optional but Recommended)
- [ ] Cart repository tests
  - [ ] `saveCart()` persists correctly
  - [ ] `loadCart()` retrieves correctly
  - [ ] `clearCart()` clears correctly

- [ ] Payment service tests
  - [ ] `verifyPayment()` validates signatures
  - [ ] `updatePaymentStatus()` updates correctly

### Integration Tests
- [ ] End-to-end cart to order flow
- [ ] Payment verification flow
- [ ] Admin order management flow

### Manual Testing

#### User Flow Test
1. [ ] Add product to cart
2. [ ] Verify cart persists on app restart
3. [ ] Remove product from cart
4. [ ] Update product quantity
5. [ ] Proceed to checkout
6. [ ] Fill all delivery details
7. [ ] Select payment method
8. [ ] Initiate payment
9. [ ] Complete payment with test card:
   - Card: `4111 1111 1111 1111`
   - Expiry: `12/25`
   - CVV: `123`
10. [ ] Payment verified successfully
11. [ ] Order created in database
12. [ ] Cart cleared after payment
13. [ ] User redirected to orders screen
14. [ ] Order visible in orders list

#### Admin Flow Test
1. [ ] Login as admin
2. [ ] Navigate to Admin → Orders
3. [ ] See list of all orders
4. [ ] Filter by "Pending Payment"
5. [ ] Filter by "Paid"
6. [ ] Filter by "Failed"
7. [ ] Search for specific order
8. [ ] Click order to view details
9. [ ] Send payment reminder
10. [ ] Verify notification created
11. [ ] Mark order as paid
12. [ ] Verify payment status updated
13. [ ] View order items and amounts

#### Payment Testing
- [ ] [ ] Successful payment flow
- [ ] [ ] Payment cancellation
- [ ] [ ] Payment retry after failure
- [ ] [ ] Multiple payment attempts
- [ ] [ ] Check `payment_logs` table for entries
- [ ] [ ] Verify `orders` table payment fields updated
- [ ] [ ] Check `payment_reminders` table

#### Database Testing
```sql
-- Verify tables exist
SELECT * FROM information_schema.tables 
WHERE table_name IN ('shopping_carts', 'payment_logs', 'payment_reminders', 'orders');

-- Verify indexes
SELECT * FROM pg_indexes 
WHERE tablename IN ('orders', 'payment_logs', 'shopping_carts');

-- Test RLS
-- (Login as regular user, should only see own data)

-- Verify functions
SELECT routine_name FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name LIKE '%payment%';
```

---

## 🔄 Post-Deployment Verification

### Smoke Tests
- [ ] App starts without errors
- [ ] Cart functionality works
- [ ] Checkout screen loads
- [ ] Razorpay payment opens (on mobile)
- [ ] Admin dashboard loads
- [ ] Orders visible in admin

### Database Verification
- [ ] All tables created: `\d`
- [ ] All triggers created: `\dt`
- [ ] All functions created: `\df`
- [ ] RLS policies applied: `\dP`

### Function Testing
```bash
# Test Edge Function 1
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/create-razorpay-order \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"amount_paise": 50000, "customer_id": "test"}'

# Test Edge Function 2
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/verify-razorpay-payment \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"order_id": "test", "payment_id": "test", "signature": "test"}'
```

### Performance Check
- [ ] Cart loads within 2 seconds
- [ ] Checkout screen loads within 3 seconds
- [ ] Payment initiation within 2 seconds
- [ ] Admin orders load within 3 seconds
- [ ] No excessive database queries

---

## 🚀 Production Deployment Steps

### 1. Pre-Production Testing
- [ ] All manual tests passed
- [ ] Database backup created
- [ ] Edge functions tested in staging
- [ ] Error handling verified

### 2. Update Configuration
- [ ] Replace test Razorpay keys with live keys
- [ ] Update Supabase project if needed
- [ ] Verify API endpoints
- [ ] Check CORS settings

### 3. Database Migration
```bash
# Back up current database
pg_dump your_db > backup.sql

# Run new migration
supabase migration up

# Verify migration
SELECT COUNT(*) FROM shopping_carts;
SELECT COUNT(*) FROM payment_logs;
```

### 4. Deploy Functions
```bash
supabase functions deploy create-razorpay-order
supabase functions deploy verify-razorpay-payment
```

### 5. Deploy App
- [ ] Build production APK/iOS: `flutter build apk --release`
- [ ] Upload to Play Store / App Store
- [ ] Wait for approval
- [ ] Release to users

### 6. Verify Live Deployment
- [ ] Process live test payment
- [ ] Verify order in database
- [ ] Check payment logs
- [ ] Verify admin notification
- [ ] Test payment reminder

---

## 🔐 Security Checklist

- [ ] Razorpay secret key not exposed in frontend
- [ ] Server-side payment verification enabled
- [ ] RLS policies enforced on all tables
- [ ] HTTPS enabled for all connections
- [ ] API keys rotated if exposed
- [ ] Audit logs reviewed
- [ ] Payment data encrypted
- [ ] PCI DSS compliance verified

---

## 📊 Monitoring & Maintenance

### Daily Checks
- [ ] Check failed payments: `SELECT * FROM orders WHERE payment_status = 'failed';`
- [ ] Check pending reminders: `SELECT * FROM payment_reminders WHERE is_resolved = false;`
- [ ] Monitor Error logs: Check Edge Function logs
- [ ] Verify database performance: Check query performance

### Weekly Checks
- [ ] Payment reconciliation with Razorpay dashboard
- [ ] Database backup verification
- [ ] User support tickets related to payments
- [ ] Performance metrics review

### Monthly Checks
- [ ] Payment report generation
- [ ] Revenue reconciliation
- [ ] Database optimization
- [ ] Security audit

---

## 🐛 Common Issues & Solutions

| Issue | Solution | Status |
|-------|----------|--------|
| "Cart not loading" | Check RLS, verify user authenticated | [ ] |
| "Payment fails" | Check Razorpay keys, verify internet | [ ] |
| "Edge function 404" | Deploy functions, verify names | [ ] |
| "Orders not appearing" | Check RLS policy, verify admin role | [ ] |
| "Signature verification fails" | Check secret key, verify timestamps | [ ] |

---

## 📝 Notes

- **Razorpay Settlement**: Typically 2-3 business days
- **Fee Structure**: 2% + ₹0 for most payment methods
- **Test Mode**: Use provided test keys, switch to live after verification
- **Support**: Contact Razorpay support@razorpay.com

---

**Deployment Status:** ✅ Ready for Testing  
**Last Updated:** April 21, 2026  
**Next Review:** After 1st production payment processed
