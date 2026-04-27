# Saral Pooja - Project Implementation Overview

## Executive Summary
**Saral Pooja** is a comprehensive Flutter-based spiritual services marketplace for India with Supabase backend. The application supports multiple service types (poojas, consultations, special events), pandit marketplace, user bookings, e-commerce shop, and administrative controls.

**Latest Migration**: 023_admin_statistics_and_profile_updates.sql

---

## 1. CART IMPLEMENTATION

### Current State: ✅ IMPLEMENTED (In-Memory)

#### Location
- **Models**: [lib/shop/models/cart_item.dart](lib/shop/models/cart_item.dart)
- **Controller**: [lib/shop/controllers/shop_controller.dart](lib/shop/controllers/shop_controller.dart)
- **Provider**: [lib/shop/providers/shop_provider.dart](lib/shop/providers/shop_provider.dart)
- **Screens**: [lib/shop/screens/cart_screen.dart](lib/shop/screens/cart_screen.dart)

#### Key Features
```dart
// Model Structure (CartItem)
class CartItem {
  final ProductModel product;
  int quantity;
  int get totalPaise;  // price in paise (₹1 = 100 paise)
}

// Cart Summary
class CartSummary {
  List<CartItem> items;
  int subtotalPaise;
  int taxPaise;      // GST @ 5%
  int totalPaise;
  int itemCount;
  String formattedSubtotal/Tax/Total;
}
```

#### Implementation Details
- **State Management**: Riverpod `StateNotifierProvider<CartController, CartState>`
- **Persistence**: In-memory (session-based) - NOT persisted to database
- **Tax Calculation**: Automatic GST @ 5% on subtotal
- **Price Format**: Display with currency formatting (₹10,000)
- **Global Cart**: Single cart instance persists across navigation

#### Providers
```dart
final cartProvider;          // Global cart state
final cartItemCountProvider; // Total items count
final cartSummaryProvider;   // Summary calculations
```

#### Database Integration
- ❌ No persistent cart storage in DB
- ⚠️ Cart lost on app restart
- **Recommendation**: Consider session-based persistence for abandoned carts

---

## 2. BOOKING FLOW & MODELS

### Current State: ✅ FULLY IMPLEMENTED

#### Location
- **Models**: [lib/booking/models/](lib/booking/models/)
  - `booking_model.dart` - Main booking entity
  - `booking_status.dart` - Status enum & helpers
  - `booking_draft.dart` - Incomplete booking state
  - `time_slot_model.dart` - Booking time slots
  - `proof_model.dart` - Service completion proof
  
- **Repository**: [lib/booking/repository/booking_repository.dart](lib/booking/repository/booking_repository.dart)
- **Screens**: [lib/booking/screens/](lib/booking/screens/)
  - `booking_wizard_screen.dart` - Multi-step booking flow
  - `booking_detail_screen.dart` - View booking details
  - `booking_screen.dart` - List user's bookings

#### Booking Status Workflow
```
pending → confirmed → assigned → completed
   ↓          ↓          ↓
   └──────────→ cancelled
```

#### Booking Model Structure
```dart
class BookingModel {
  String id;
  String userId;
  String packageId;
  String packageTitle;
  String category;
  
  // Location
  BookingLocation location;  // Online or offline address
  
  // Pandit assignment
  String? panditId;
  bool isAutoAssigned;
  
  // Payment
  int amount;      // in paise
  bool isPaid;
  String? paymentId;
  
  // Timing
  DateTime date;
  TimeSlot slot;
  
  // Status tracking
  BookingStatus status;
  DateTime createdAt;
}

class BookingLocation {
  bool isOnline;
  String? addressLine1;
  String? addressLine2;
  String? city;
  String? pincode;
  String? meetLink;      // Set by admin/pandit
  String? contactPhone;
}
```

#### Booking Flow (Database-Level)
1. **Create Booking**: RPC `create_booking()` 
   - Atomic transaction with slot-conflict detection
   - Advisory locking on (pandit_id, date, slot_id)
   - Support for paid-at-checkout flows (payment_id set at creation)
   - Auto-assign or specific pandit option

2. **Status Transitions**:
   - `pending` → Admin reviews & confirms
   - `confirmed` → Admin assigns pandit
   - `assigned` → Service ready (pandit notified)
   - `completed` → Service rendered
   - `cancelled` → User or admin initiated

3. **Notifications**: Created on each status change via RPC `create_app_notification()`

#### Key Features
- ✅ Time slot conflict resolution (advisory locks)
- ✅ Auto-assign pandit mode
- ✅ Payment integration at booking creation
- ✅ Location type selection (online with Meet link or offline)
- ✅ Proof of service upload post-completion
- ✅ Real-time status notifications

---

## 3. PAYMENT INTEGRATION

### Current State: ✅ IMPLEMENTED (Razorpay Mobile + Mock Web)

#### Location
- **Service**: [lib/payment/payment_service.dart](lib/payment/payment_service.dart)
- **Provider**: [lib/payment/payment_provider.dart](lib/payment/payment_provider.dart)
- **Dependency**: `razorpay_flutter: ^1.3.6` (mobile only)

#### Architecture
```dart
// Abstract interface (multiple implementations)
abstract class IPaymentService {
  Future<PaymentResult> initiatePayment(PaymentRequest request);
  void dispose();
}

// Production implementation
class RazorpayPaymentService implements IPaymentService {
  // Mobile Android/iOS only
}

// Web fallback
class MockPaymentService implements IPaymentService {
  // Mock for web platform (Razorpay SDK not available)
}

// Auto-selection provider
final paymentServiceProvider = Provider<IPaymentService>(
  (ref) => (kIsWeb || !RazorpayPaymentService.isConfigured)
      ? MockPaymentService()
      : RazorpayPaymentService(),
);
```

#### Payment Request Structure
```dart
class PaymentRequest {
  String orderId;
  int amountPaise;           // ₹1 = 100 paise
  String description;
  
  // Customer details
  String customerName;
  String customerEmail;
  String customerPhone;
  
  // Optional
  String? razorpayOrderId;   // Pre-created server-side
  Map<String, dynamic> metadata;
}

class PaymentResult {
  PaymentStatus status;    // success | failed | cancelled
  String? transactionId;
  String? providerPaymentId;
  String? errorMessage;
  Map<String, dynamic>? providerData;
}
```

#### Integration Points
1. **Shop Orders** → Checkout screen triggers payment
2. **Bookings** → Payment at confirmation (special poojas)
3. **Consultations** → Session payment via order flow

#### Status Flow
```
idle → processing → success/failed/cancelled
```

#### Checkout Integration
- Location: [lib/shop/screens/checkout_screen.dart](lib/shop/screens/checkout_screen.dart)
- Form pre-fills from user profile
- Supports multiple payment methods (UPI, Cards, etc.)
- Address prefill from default user address

#### Database Support
- **Orders table**: Stores `payment_id` reference
- **Bookings table**: Stores `payment_id` + `is_paid` flag
- **Consultations table**: Stores payment session data

---

## 4. ADMIN PANEL STRUCTURE

### Current State: ✅ COMPREHENSIVE IMPLEMENTATION

#### Location
- **Main Screen**: [lib/admin/screens/admin_shell_screen.dart](lib/admin/screens/admin_shell_screen.dart)
- **Dashboard Tabs**: [lib/admin/screens/](lib/admin/screens/)
- **Controller**: [lib/admin/controllers/admin_controller.dart](lib/admin/controllers/admin_controller.dart)
- **Models**: [lib/admin/models/](lib/admin/models/)

#### Admin Screens (13 total)
1. ✅ **Overview** (`_admin_overview_tab.dart`) - Dashboard KPIs
2. ✅ **Statistics** (`admin_statistics_screen.dart`) - Analytics & reports
3. ✅ **Bookings** (`admin_bookings_screen.dart`) - Manage regular bookings
4. ✅ **Consultations** (`admin_consultations_screen.dart`) - Manage live sessions
5. ✅ **Offline Bookings** (`admin_offline_bookings_screen.dart`) - Offline service bookings
6. ✅ **Pandits** (`admin_pandits_screen.dart`) - Pandit profile management
7. ✅ **Poojas** (`admin_poojas_screen.dart`) - Package/pooja catalog
8. ✅ **Special Poojas** - (referenced in models)
9. ✅ **Products** (`admin_products_screen.dart`) - Shop inventory
10. ✅ **Packages** (`admin_packages_screen.dart`) - Service packages
11. ✅ **Reports** (`admin_reports_screen.dart`) - Analytics reports
12. ✅ **Users** (`admin_users_screen.dart`) - User management
13. ✅ **Catalogue** (`_admin_catalogue_tab.dart`) - Unified catalog view

#### Key Admin Features
- **Real-time Statistics**: Via RPC functions `get_pandit_booking_stats()`, `get_all_pandits_stats()`
- **Booking Management**: Accept/reject/assign workflow
- **Pandit Management**: Toggle online/offline status, consultation availability
- **Pooja Management**: Create/edit/deactivate service offerings
- **User Management**: Profile management, role assignment
- **Analytics**: Monthly/weekly statistics per pandit and user
- **Offline Booking Mode**: For marketplace-style bookings

#### Admin Models
```dart
class AdminPooja {
  String id, title, category, description;
  double basePrice;
  int durationMinutes;
  bool isActive, isOnlineAvailable;
  List<String> tags;
}

class AdminPandit {
  String id, name;
  double rating;
  int totalBookings;
  List<String> specialties;
  bool isOnline, consultationEnabled;
}

class AdminReport {
  int totalBookings, completedBookings, pendingBookings;
  int totalUsers, activePandits;
  double totalRevenue;
  // ... monthly/weekly breakdowns
}
```

#### Statistics RPC Functions (Migration 023)
- `get_pandit_booking_stats(pandit_id)` → Returns JSON with:
  - Total/completed/cancelled/pending bookings
  - Monthly & weekly breakdown
  - Pandit performance metrics
  
- `get_all_pandits_stats()` → Array of all pandit stats
- `get_user_booking_stats(user_id)` → User booking history

---

## 5. DATABASE SCHEMA

### Current State: ✅ 23 MIGRATIONS COMPLETED

#### Core Tables

##### **profiles** (Users)
```sql
id (uuid, PK)
full_name (text)
phone (text)
avatar_url (text)
role (enum: user | pandit | admin)
rating (numeric)
is_active (boolean)
created_at, updated_at (timestamptz)
```

##### **pandit_details** (Extended Pandit Profile)
```sql
id (uuid, FK → profiles)
specialties (text[])
languages (text[])
experience_years (int)
bio (text)
is_online (boolean)
consultation_enabled (boolean)
offline_booking_enabled (boolean)  ← NEW in Migration 023
location (text)
created_at, updated_at (timestamptz)
```

##### **packages** (Puja/Service Offerings)
```sql
id (uuid, PK)
title, description (text)
price (numeric, rupees)
discount_price (numeric, optional)
duration_minutes (int)
is_online, is_offline (boolean)
category (text)
includes (text[], denormalized list)
image_url (text)
is_featured, is_popular (boolean)
booking_count (int)
rating (numeric)
review_count (int)
is_active (boolean)
created_at, updated_at (timestamptz)
```

##### **special_poojas** (Online Paid Poojas)
```sql
id (uuid, PK)
title, description (text)
price (numeric, rupees)
duration_minutes (int)
temple_location (jsonb)
availability (jsonb)
image_url (text)
rating (numeric)
is_active (boolean)
created_at, updated_at (timestamptz)
```

##### **bookings** (Core Booking Entity)
```sql
id (uuid, PK)
user_id (uuid, FK)
pandit_id (uuid, FK, nullable for auto-assign)
package_id (uuid, FK)
special_pooja_id (uuid, FK, nullable)
package_title (text, denormalized)
category (text)
booking_date (date)
slot_id (text)
slot (jsonb: {startHour, startMinute, endHour, endMinute})
location (jsonb: {isOnline, address*, meetLink, contactPhone})
status (enum: pending | confirmed | assigned | completed | cancelled)
amount (numeric, rupees)
is_paid (boolean)              ← Payment flag
payment_id (text)              ← Razorpay order ID
notes (text)
pandit_accepted (boolean)
pandit_name (text, denormalized)
is_auto_assigned (boolean)
created_at, updated_at (timestamptz)

-- UNIQUE INDEX (handles slot conflicts)
UNIQUE (pandit_id, booking_date, slot_id) 
WHERE status != 'cancelled' AND pandit_id IS NOT NULL
```

##### **orders** (Shop Orders)
```sql
id (uuid, PK)
user_id (uuid, FK)
items (jsonb)                  ← [{productId, name, qty, price}]
subtotal_paise (int)
tax_paise (int)
total_paise (int)
status (enum: pending | confirmed | shipped | delivered | cancelled)
shipping_addr (jsonb)          ← Address + payment method
payment_id (text)              ← Razorpay order ID
created_at, updated_at (timestamptz)
```

##### **consultations** (Live Video Sessions)
```sql
id (uuid, PK)
user_id (uuid, FK)
pandit_id (uuid, FK)
start_ts (timestamptz)
duration_minutes (int)
price (numeric, rupees)        ← Cost per minute
status (enum: active | ended | expired | refunded)
notes (text)
created_at, updated_at (timestamptz)
```

##### **notifications** (In-App Notifications)
```sql
id (uuid, PK)
user_id (uuid, FK)
type (enum: booking_* | payment_* | consultation_* | general)
title (text)
body (text)
entity_type (text)             ← 'booking' | 'consultation' | etc
entity_id (text)
metadata (jsonb)
read_at (timestamptz, nullable)
created_at (timestamptz)
```

##### **products** (Shop Products)
```sql
id (uuid, PK)
name (text)
description (text)
price_paise (int)              ← Amount in paise
category (text)                ← Kit type (Satyanarayan, etc)
rating (numeric)
review_count (int)
stock (int)
includes (text[], denormalized items)
image_url (text)
is_best_seller (boolean)
is_active (boolean)
created_at (timestamptz)
```

##### **offline_bookings** (Marketplace-Style Bookings)
```sql
id (uuid, PK)
user_id (uuid, FK)
pandit_id (uuid, FK)
booking_date (date)
slot (jsonb)
location (jsonb)
notes (text)
status (enum: pending | confirmed | completed | cancelled)
created_at, updated_at (timestamptz)
```

#### Migration Timeline
- **001**: Initial schema (profiles, packages, bookings, orders, consultations)
- **002**: RLS policies
- **003**: RPC functions (create_booking, update booking status)
- **004-009**: Refinements (special poojas, proof videos, conflict resolution)
- **010**: Payment fields (`is_paid`, `payment_id`) in bookings
- **011**: Consultation scheduling, chat media storage
- **012**: Notifications table + `create_app_notification()` RPC
- **013-022**: Bug fixes, offline booking marketplace, pandit toggles
- **023**: Admin statistics functions, offline_booking_enabled field

#### Key Database Functions (RPCs)

**create_booking()**
- Creates booking atomically
- Detects slot conflicts via advisory locks
- Supports payment_id at insert time
- Returns `{booking_id}` or `{error}`

**create_app_notification()**
- Creates notification in DB
- Returns notification ID
- Triggered by booking status changes, payment events

**get_pandit_booking_stats(pandit_id)**
- Returns JSONB: statistics with monthly/weekly breakdown
- Called by admin statistics screen

**start_consultation_session()**
- Creates consultation session
- Returns `{session_id, started_at}`
- Manages WebSocket connections

---

## 6. NOTIFICATION & STATUS UPDATE MECHANISMS

### Current State: ✅ IMPLEMENTED (Database-Driven + WebSocket)

#### Location
- **Models**: [lib/account/models/app_notification.dart](lib/account/models/app_notification.dart)
- **Repository**: [lib/account/repository/notifications_repository.dart](lib/account/repository/notifications_repository.dart)
- **Provider**: [lib/account/providers/notifications_provider.dart](lib/account/providers/notifications_provider.dart)
- **Screen**: [lib/account/screens/notifications_screen.dart](lib/account/screens/notifications_screen.dart)

#### Notification Types (Enum)
```dart
enum AppNotificationType {
  bookingRequested,
  bookingConfirmed,
  bookingAssigned,
  bookingCancelled,
  paymentPending,
  paymentCompleted,
  consultationRequested,
  consultationConfirmed,
  consultationRescheduleProposed,
  consultationRejected,
  consultationRefunded,
  general,
}
```

#### Notification Model
```dart
class AppNotification {
  String id;
  String userId;
  AppNotificationType type;
  String title;
  String body;
  String? entityType;          // 'booking' | 'consultation'
  String? entityId;
  Map<String, dynamic> metadata;
  DateTime createdAt;
  DateTime? readAt;            // null = unread
  
  bool get isRead => readAt != null;
}
```

#### Real-Time Updates (Supabase Realtime)
```dart
// Watch notifications stream
watchNotifications(userId) {
  _client
    .from('notifications')
    .stream(primaryKey: ['id'])
    .eq('user_id', userId)
    .order('created_at', ascending: false)
    .map(AppNotification.fromJson)
}

// Mark as read
markRead(notificationId) {
  _client
    .from('notifications')
    .update({'read_at': now()})
    .eq('id', notificationId)
}

// Mark all as read
markAllRead(userId) {
  _client
    .from('notifications')
    .update({'read_at': now()})
    .eq('user_id', userId)
    .isFilter('read_at', null)
}
```

#### Status Update Flow

**Booking Status Changes**
1. User/Admin changes booking status
2. Server-side RPC executes transaction
3. DB trigger or RPC creates notification
4. Supabase Realtime broadcasts to all connected clients
5. UI updates via Riverpod `watchNotifications()` stream

**Consultation Updates**
1. WebSocket listens for pandit messages
2. `WsSessionRepository` manages session state
3. Real-time chat media upload support
4. Status transitions (active → ended/expired)
5. Notifications created for state changes

**Payment Updates**
1. Razorpay webhook confirms payment
2. Order/booking status updated
3. `payment_completed` notification created
4. User receives notification in real-time

#### Notification Triggers (Auto-Created)
- Booking requested (user creates booking)
- Booking confirmed (admin accepts)
- Booking assigned (admin assigns pandit)
- Payment completed (Razorpay confirmation)
- Consultation started (WebSocket connect)
- Consultation ended (Session expires or user leaves)
- Refund processed (Admin initiates refund)

#### WebSocket for Consultations
- **Protocol**: Supabase Realtime (PostgreSQL LISTEN/NOTIFY)
- **Location**: [lib/consultation/repository/ws_session_repository.dart](lib/consultation/repository/ws_session_repository.dart)
- **Features**:
  - Real-time chat messages from pandit
  - Session timer updates (interpolated locally every 1 sec)
  - Automatic cleanup on session end
  - Handles reconnection gracefully

#### Unread Notification Badge
```dart
final unreadCountProvider = Provider<int>(
  (ref) => ref
    .watch(notificationsProvider)
    .whenData((list) => list.where((n) => !n.isRead).length)
);
```

---

## 7. PROJECT STRUCTURE SUMMARY

### High-Level Architecture
```
lib/
├── auth/                 # Authentication (Supabase Auth)
├── account/              # User profile, notifications, settings
├── booking/              # Booking flow (poojas, packages)
├── consultation/         # Live consultation sessions (WebSocket)
├── special_poojas/       # Online pooja catalog + booking
├── shop/                 # E-commerce (products, cart, orders)
├── payment/              # Razorpay integration
├── admin/                # Admin dashboard & statistics
├── pandit/               # Pandit profile & dashboard
├── home/                 # Home screen & navigation
├── offline_booking/      # Marketplace-style offline bookings
├── core/                 # Shared constants, router, theme, providers
├── services/             # Generic services (API, websocket, etc)
├── packages/             # Reusable utility packages
├── widgets/              # Shared UI components
└── main.dart             # App entry point
```

### Key Dependencies
```yaml
# State management
flutter_riverpod: ^2.5.1      # Reactive state
riverpod_annotation: ^2.3.5   # Codegen

# Backend
supabase_flutter: ^2.3.4      # Database, Auth, Realtime
dio: ^5.4.0                   # HTTP client

# Payment
razorpay_flutter: ^1.3.6      # Razorpay SDK (mobile only)

# UI
flutter_animate: ^4.5.0       # Animations
table_calendar: ^3.1.2        # Calendar widget
fl_chart: ^0.70.2             # Charts

# Utilities
go_router: ^14.0.2            # Navigation
web_socket_channel: ^3.0.1    # WebSocket for consultation
image_picker: ^1.0.7          # Image/video upload
```

---

## 8. CURRENT IMPLEMENTATION STATUS

### ✅ Fully Implemented
- [x] User authentication (Supabase Auth)
- [x] Multi-role system (user, pandit, admin)
- [x] Booking creation with conflict detection
- [x] Pandit assignment & auto-assign
- [x] Payment integration (Razorpay)
- [x] Shop cart & checkout flow
- [x] Orders management
- [x] Special poojas (online paid bookings)
- [x] Live consultations (WebSocket)
- [x] In-app notifications (real-time)
- [x] Admin dashboard (13 screens)
- [x] Admin statistics & reporting
- [x] Offline booking marketplace
- [x] Service proof upload (proof_model)
- [x] Profile avatars (storage buckets)

### ⚠️ Partially Implemented / Needs Enhancement
- [ ] Cart persistence (in-memory only, lost on app restart)
- [ ] Abandoned cart recovery (not implemented)
- [ ] Order tracking visualization (basic status only)
- [ ] Email notifications (in-app only)
- [ ] Push notifications (not implemented)
- [ ] Payment webhook validation (Razorpay confirmation)
- [ ] Refund workflow (DB structure ready, UI pending)
- [ ] Review & ratings (DB ready, UI pending)

### 📋 Not Yet Implemented
- [ ] SMS notifications
- [ ] In-app chat (separate from consultation)
- [ ] Pandit scheduling calendar
- [ ] Advanced analytics dashboard
- [ ] Export reports (CSV/PDF)
- [ ] Subscription/recurring bookings
- [ ] Multi-language support (i18n)

---

## 9. IMPORTANT NOTES FOR DEVELOPMENT

### Database Connection
- **Supabase URL**: Set via environment or Supabase Flutter SDK
- **Auth**: Row-Level Security (RLS) enforced on all tables
- **Realtime**: Enabled for notifications, consultations, bookings
- **Storage**: Buckets for product images, consultation media, proofs

### Payment Workflow
1. User adds items to cart
2. Checkout creates order with `status='pending'`
3. Payment initiated via Razorpay SDK
4. Success → Update `order.payment_id`, `order.status='confirmed'`
5. Failure → Keep as pending, allow retry

### Booking Atomic Transaction
- All booking data (location, slot, pandit) inserted in single RPC call
- Advisory lock prevents duplicate slot assignments
- Supports paid bookings (payment_id set at creation)

### Admin Statistics
- Real-time aggregation via RPC functions
- Monthly/weekly breakdown per pandit
- Performance metrics (completed vs cancelled)

### WebSocket Consultation Flow
- Timer driven by periodic DB updates
- Local interpolation for smooth countdown
- Channel cleanup on session end

---

## 10. FILE LOCATIONS REFERENCE

### Core Features
| Feature | Files |
|---------|-------|
| **Cart** | [lib/shop/models/cart_item.dart](lib/shop/models/cart_item.dart), [lib/shop/controllers/](lib/shop/controllers/), [lib/shop/providers/shop_provider.dart](lib/shop/providers/shop_provider.dart) |
| **Booking** | [lib/booking/models/booking_model.dart](lib/booking/models/booking_model.dart), [lib/booking/repository/booking_repository.dart](lib/booking/repository/booking_repository.dart), [lib/booking/screens/](lib/booking/screens/) |
| **Payment** | [lib/payment/payment_service.dart](lib/payment/payment_service.dart), [lib/payment/payment_provider.dart](lib/payment/payment_provider.dart), [lib/shop/screens/checkout_screen.dart](lib/shop/screens/checkout_screen.dart) |
| **Admin** | [lib/admin/screens/](lib/admin/screens/), [lib/admin/controllers/admin_controller.dart](lib/admin/controllers/admin_controller.dart), [lib/admin/models/admin_models.dart](lib/admin/models/admin_models.dart) |
| **Notifications** | [lib/account/models/app_notification.dart](lib/account/models/app_notification.dart), [lib/account/repository/notifications_repository.dart](lib/account/repository/notifications_repository.dart), [lib/account/screens/notifications_screen.dart](lib/account/screens/notifications_screen.dart) |
| **Consultations** | [lib/consultation/repository/ws_session_repository.dart](lib/consultation/repository/ws_session_repository.dart), [lib/consultation/models/consultation_session.dart](lib/consultation/models/consultation_session.dart) |

### Database
| Schema | Migrations |
|--------|-----------|
| **Initial** | [supabase/migrations/001_initial_schema.sql](supabase/migrations/001_initial_schema.sql) |
| **Policies** | [supabase/migrations/002_rls_policies.sql](supabase/migrations/002_rls_policies.sql) |
| **Payment Fields** | [supabase/migrations/010_create_booking_payment_fields.sql](supabase/migrations/010_create_booking_payment_fields.sql) |
| **Notifications** | [supabase/migrations/012_notifications_and_profile_media.sql](supabase/migrations/012_notifications_and_profile_media.sql) |
| **Admin Stats** | [supabase/migrations/023_admin_statistics_and_profile_updates.sql](supabase/migrations/023_admin_statistics_and_profile_updates.sql) |

---

## 11. NEXT STEPS & RECOMMENDATIONS

### High Priority
1. **Persistent Cart**: Implement SessionStorage or LocalDatabase persistence
2. **Payment Webhook**: Add webhook listener for Razorpay confirmations
3. **Email Notifications**: Integrate email service (Firebase/SendGrid)
4. **Push Notifications**: Add FCM or OneSignal integration

### Medium Priority
1. **Refund Workflow**: Complete UI for admin refund operations
2. **Review System**: UI for star ratings & reviews
3. **Advanced Reports**: PDF export, custom date ranges
4. **Analytics**: Event tracking, user behavior insights

### Low Priority
1. **SMS Notifications**: For critical alerts
2. **Multi-language**: i18n support
3. **Recurring Bookings**: Subscription model
4. **Chat**: General messaging outside consultations

---

## Document Metadata
- **Generated**: 2026-04-21
- **Migrations**: 001-023 analyzed
- **Flutter Version**: 3.11.0+
- **Dart Version**: 3.11.0+
- **Total Implementations**: 50+ screens, 15+ RPC functions, 11 core tables
