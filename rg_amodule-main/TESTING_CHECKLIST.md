# Saral Pooja App - Manual Testing Checklist

## Test Credentials

| Role | Email | Password |
|------|-------|----------|
| **Admin** | demo_admin@saralpooja.com | Demo@123 |
| **User** | user2@user.com | Abc@123 |
| **Pandit** | pandit2@pandit.com | Abc@123 |

---

## Phase 1: Authentication Tests

### 1.1 User Login
- [ ] Open app → Navigate to login screen
- [ ] Enter `user2@user.com` / `Abc@123`
- [ ] Tap "Sign In"
- [ ] **Expected:** User is logged in, redirected to Home screen
- [ ] **Expected:** User sees "👤 User" avatar in app bar

### 1.2 Pandit Login
- [ ] Logout from user account
- [ ] Enter `pandit2@pandit.com` / `Abc@123`
- [ ] Tap "Sign In"
- [ ] **Expected:** Pandit is logged in, redirected to Pandit Dashboard
- [ ] **Expected:** Pandit sees "🙏 Pandit" avatar and online/offline toggle

### 1.3 Admin Login
- [ ] Logout from pandit account
- [ ] Enter `demo_admin@saralpooja.com` / `Demo@123`
- [ ] Tap "Sign In"
- [ ] **Expected:** Admin is logged in, redirected to Admin Panel
- [ ] **Expected:** Admin sees all management options

---

## Phase 2: User Features Tests

### 2.1 Home Screen
- [ ] User logged in → Home screen displays
- [ ] **Expected:** Special Poojas carousel visible
- [ ] **Expected:** Packages/Poojas grid visible
- [ ] **Expected:** Bottom navigation works (Home, Bookings, Shop, Account)

### 2.2 Offline Pandit Booking Flow
- [ ] Navigate to "Book Pandit" / "Offline Pandit"
- [ ] **Expected:** Pandit browsing screen opens
- [ ] **Expected:** Search bar visible
- [ ] **Expected:** Filter chips (City, Specialty, Price) visible

#### 2.2.1 Search Pandits
- [ ] Enter city name in search
- [ ] **Expected:** Pandit list filters by city
- [ ] Tap on a pandit card
- [ ] **Expected:** Pandit profile screen opens

#### 2.2.2 Book Pandit
- [ ] On pandit profile → Tap "Book Now"
- [ ] **Expected:** Booking form opens
- [ ] Fill in:
  - [ ] Address Line 1
  - [ ] City
  - [ ] State
  - [ ] Pincode
  - [ ] Select Date
  - [ ] Select Time Slot
- [ ] Tap "Continue to Payment"
- [ ] **Expected:** Payment screen opens with booking summary

#### 2.2.3 Payment (Razorpay Test Mode)
- [ ] On payment screen → Tap "Pay Now"
- [ ] **Expected:** Razorpay checkout opens (test mode)
- [ ] Use test card: `5267 3181 8797 5449`
- [ ] Any future expiry, any CVV
- [ ] Tap "Pay"
- [ ] **Expected:** Payment success, booking confirmed
- [ ] **Expected:** Booking appears in "My Bookings"

### 2.3 My Bookings
- [ ] Navigate to "My Bookings" from bottom nav
- [ ] **Expected:** List of user's bookings displayed
- [ ] **Expected:** Each booking shows status (Pending/Confirmed/Completed/Cancelled)
- [ ] Tap on a booking
- [ ] **Expected:** Booking details screen with pandit info

### 2.4 Consultation/Chat (if available)
- [ ] Navigate to "Consultations"
- [ ] **Expected:** List of available pandits for online chat
- [ ] Tap on a pandit
- [ ] **Expected:** Chat/Consultation screen opens

---

## Phase 3: Pandit Dashboard Tests

### 3.1 Dashboard Overview
- [ ] Login as pandit (`pandit2@pandit.com`)
- [ ] **Expected:** Pandit Dashboard opens
- [ ] **Expected:** NO earnings/money information visible
- [ ] **Expected:** Shows:
  - [ ] Profile header with name
  - [ ] Online/Offline toggle button (Green/White)
  - [ ] Offline Booking toggle button (Blue/White)
  - [ ] Upcoming Bookings list
  - [ ] Chat/Consultation requests

### 3.2 Online/Offline Toggle
- [ ] Observe current status (Online/Offline)
- [ ] Tap the toggle button
- [ ] **Expected:** Status changes (Online ↔ Offline)
- [ ] **Expected:** Color changes (Green ↔ White)
- [ ] **Expected:** Loading indicator during toggle
- [ ] **Expected:** Success message on completion

### 3.3 Offline Booking Toggle
- [ ] Observe current status (Booking/No Booking)
- [ ] Tap the toggle button
- [ ] **Expected:** Status changes (Booking ↔ No Booking)
- [ ] **Expected:** Color changes (Blue ↔ White)
- [ ] **Expected:** Loading indicator during toggle
- [ ] **Expected:** Success message on completion

### 3.4 View Bookings
- [ ] On pandit dashboard → View "My Bookings"
- [ ] **Expected:** List of bookings assigned to this pandit
- [ ] **Expected:** Each booking shows:
  - [ ] User name
  - [ ] Service type
  - [ ] Date & time
  - [ ] Address
  - [ ] Status
- [ ] **Expected:** NO payment/amount information visible

### 3.5 Accept/Reject Booking (if feature exists)
- [ ] New booking request appears
- [ ] **Expected:** Accept/Reject buttons visible
- [ ] Tap "Accept"
- [ ] **Expected:** Booking status changes to "Confirmed"

### 3.6 Chat/Consultation
- [ ] Navigate to "Chats" or "Consultations"
- [ ] **Expected:** List of active chat sessions
- [ ] Tap on a chat
- [ ] **Expected:** Chat interface opens
- [ ] Send a message
- [ ] **Expected:** Message sent successfully

---

## Phase 4: Admin Panel Tests

### 4.1 Admin Dashboard
- [ ] Login as admin (`demo_admin@saralpooja.com`)
- [ ] **Expected:** Admin Panel opens
- [ ] **Expected:** Admin badge visible
- [ ] **Expected:** Statistics cards visible:
  - [ ] Total Users
  - [ ] Total Pandits
  - [ ] Total Bookings
  - [ ] Revenue (if applicable)

### 4.2 Manage Pandits
- [ ] Tap "Manage Pandits"
- [ ] **Expected:** List of all pandits
- [ ] **Expected:** Each pandit shows:
  - [ ] Name
  - [ ] Status (Active/Inactive)
  - [ ] Specialties
- [ ] Tap on a pandit
- [ ] **Expected:** Pandit details screen
- [ ] **Expected:** Toggle pandit active/inactive

### 4.3 Manage Users
- [ ] Tap "Manage Users"
- [ ] **Expected:** List of all users
- [ ] **Expected:** Each user shows name, email, booking count

### 4.4 Booking Statistics (NEW FEATURE)
- [ ] Tap "Booking Statistics"
- [ ] **Expected:** Statistics screen opens with two tabs:
  - [ ] "Pandits" tab
  - [ ] "Users" tab

#### 4.4.1 Pandit Statistics Tab
- [ ] Tap "Pandits" tab
- [ ] **Expected:** List of all pandits with stats cards
- [ ] **Expected:** Each card shows:
  - [ ] Pandit name & ID
  - [ ] **Total Bookings** count
  - [ ] **Completed Bookings** count
  - [ ] **Cancelled Bookings** count
  - [ ] **Pending Bookings** count
  - [ ] **Monthly Stats** (current month)
  - [ ] **Weekly Stats** (current week)
- [ ] Pull down to refresh
- [ ] **Expected:** Stats refresh

#### 4.4.2 User Statistics Tab
- [ ] Tap "Users" tab
- [ ] **Expected:** List of all users with stats cards
- [ ] **Expected:** Each card shows:
  - [ ] User name & ID
  - [ ] **Total Bookings** count
  - [ ] **Completed Bookings** count
  - [ ] **Cancelled Bookings** count
  - [ ] **Pending Bookings** count
  - [ ] **Monthly Stats** (current month)
  - [ ] **Weekly Stats** (current week)

### 4.5 Offline Bookings Management
- [ ] Tap "All Bookings" or "Offline Bookings"
- [ ] **Expected:** List of all offline bookings
- [ ] **Expected:** Filter chips (All, Pending, Confirmed, Completed, Cancelled)
- [ ] Tap on a booking
- [ ] **Expected:** Booking details with:
  - [ ] User info
  - [ ] Pandit info
  - [ ] Service details
  - [ ] Status
  - [ ] **Admin Actions:**
    - [ ] Update Status
    - [ ] Process Refund
    - [ ] Process Payout

### 4.6 Manage Poojas/Packages
- [ ] Tap "Manage Special Poojas"
- [ ] **Expected:** List of poojas
- [ ] Tap "Manage Poojas" (packages)
- [ ] **Expected:** List of packages
- [ ] **Expected:** Can toggle active/inactive

---

## Phase 5: Edge Cases & Error Handling

### 5.1 Network Errors
- [ ] Turn off WiFi/Mobile data
- [ ] Try to login
- [ ] **Expected:** Error message "No internet connection"
- [ ] Turn on WiFi
- [ ] **Expected:** Retry succeeds

### 5.2 Invalid Credentials
- [ ] Enter wrong password
- [ ] **Expected:** "Invalid credentials" error

### 5.3 Session Expiry
- [ ] Leave app idle for extended period
- [ ] **Expected:** Session refresh or redirect to login

---

## Phase 6: UI/UX Checks

### 6.1 Responsive Design
- [ ] Test on different screen sizes
- [ ] **Expected:** UI adapts correctly
- [ ] **Expected:** No overflow errors

### 6.2 Loading States
- [ ] Navigate to screens with data loading
- [ ] **Expected:** Loading indicators visible
- [ ] **Expected:** No "white screen" during load

### 6.3 Empty States
- [ ] Navigate to screens with no data
- [ ] **Expected:** Friendly "No data" message
- [ ] **Expected:** Action button to add/create (if applicable)

### 6.4 Error Messages
- [ ] Trigger errors (offline, invalid input)
- [ ] **Expected:** Clear, user-friendly error messages
- [ ] **Expected:** Snackbar or dialog with action buttons

---

## Known Issues Check

### Issue 1: Unnecessary Cast Warnings
- [ ] **Status:** Minor warning in `offline_booking_repository.dart`
- [ ] **Impact:** Non-blocking, app works fine
- [ ] **Fix:** Add `// ignore: unnecessary_cast` comments

### Issue 2: Payment Test Mode
- [ ] **Status:** Razorpay configured with demo keys
- [ ] **Action:** User needs to add real keys for production
- [ ] **Location:** `lib/payment/payment_service.dart` line ~20

---

## Summary Checklist

| Feature | Status | Notes |
|---------|--------|-------|
| User Login | ⬜ | Test with user2@user.com |
| Pandit Login | ⬜ | Test with pandit2@pandit.com |
| Admin Login | ⬜ | Test with demo_admin@saralpooja.com |
| Offline Pandit Search | ⬜ | Browse, filter, view profiles |
| Offline Booking Creation | ⬜ | Fill form, select date/time |
| Razorpay Payment | ⬜ | Test mode payment flow |
| My Bookings (User) | ⬜ | View booking status |
| Pandit Dashboard | ⬜ | No earnings visible |
| Online/Offline Toggle | ⬜ | Status change works |
| Offline Booking Toggle | ⬜ | Status change works |
| Pandit Bookings List | ⬜ | View assigned bookings |
| Admin Panel | ⬜ | All sections accessible |
| Admin Statistics | ⬜ | Monthly & weekly stats |
| Admin Bookings Management | ⬜ | Update status, refunds |

---

## Post-Testing Actions

If all tests pass:
1. ✅ App is ready for production
2. ⚠️ Update Razorpay keys in `lib/payment/payment_service.dart`
3. ⚠️ Run SQL migration in Supabase
4. ⚠️ Switch from Mock to Supabase repository (uncomment lines in `offline_booking_provider.dart`)

If issues found:
1. 📝 Document issue with steps to reproduce
2. 🔧 Fix issue
3. 🔄 Re-run affected tests

---

## Quick Reference: File Locations

| Feature | File Path |
|---------|-----------|
| Razorpay Keys | `lib/payment/payment_service.dart` |
| Mock/Real Repository Toggle | `lib/offline_booking/providers/offline_booking_provider.dart` line 11-15 |
| Pandit Dashboard | `lib/pandit/screens/pandit_screen.dart` |
| Admin Statistics | `lib/admin/screens/admin_statistics_screen.dart` |
| SQL Migration | `supabase/migrations/023_admin_statistics_and_profile_updates.sql` |

---

## Support

For issues or questions:
1. Check the code comments
2. Review the architecture documentation
3. Check Supabase logs for backend issues
