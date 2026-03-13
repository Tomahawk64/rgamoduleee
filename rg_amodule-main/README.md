# Divine Pooja Services

A production-ready Religious Services Marketplace + Live Consultation Platform built with **Flutter** (Android & iOS) and **Supabase** backend.

---

## Table of Contents

1. [Features](#features)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Project Structure](#project-structure)
6. [Database Migrations](#database-migrations)
7. [Deployment](#deployment)
8. [Running Tests](#running-tests)
9. [Environment Variables](#environment-variables)
10. [Roadmap — Phase 2](#roadmap--phase-2)

---

## Features

| Feature | Status |
|---|---|
| User / Pandit / Admin role-based auth (Supabase Auth) | ✅ |
| 5-tab navigation (Home / Poojas / Special Poojas / Shop / Account) | ✅ |
| Booking wizard (7 steps, slot conflict prevention via advisory lock) | ✅ |
| Video/photo proof upload (Supabase Storage) | ✅ |
| Paid timed consultation chat (Realtime + countdown timer) | ✅ |
| Special Poojas module (temple events, calendar availability) | ✅ |
| Online shop (puja kits with cart & checkout) | ✅ |
| Admin dashboard (stats, user management, booking oversight) | ✅ |
| Pandit earnings dashboard | ✅ |
| Payment abstraction (Mock in Phase 1, Razorpay in Phase 2) | ✅ |
| Full RLS security on all tables | ✅ |
| GitHub Actions CI (analyze → test → build) | ✅ |

---

## Architecture

```
┌─────────────────────────────────────────┐
│              Flutter App                │
│  ┌──────────┐  ┌───────────┐           │
│  │ Riverpod │  │ go_router │           │
│  │ Providers│  │ (5-tab)   │           │
│  └────┬─────┘  └─────┬─────┘           │
│       │ (Repository  │                 │
│       │  Pattern)    │                 │
└───────┼──────────────┼─────────────────┘
        │              │
   ┌────▼──────────────▼──────┐
   │       Supabase            │
   │ ┌──────┐ ┌──────────────┐│
   │ │ Auth │ │  PostgREST   ││
   │ └──────┘ └──────────────┘│
   │ ┌──────┐ ┌──────────────┐│
   │ │ RLS  │ │   Realtime   ││
   │ └──────┘ └──────────────┘│
   │ ┌──────┐ ┌──────────────┐│
   │ │ RPCs │ │   Storage    ││
   │ └──────┘ └──────────────┘│
   └───────────────────────────┘
```

**Repository Pattern:**
Every data source has an abstract interface (`IBookingRepository`, `IPackageRepository`, etc.) with:
- **Mock implementation** — in-memory, instant, for dev/testing
- **Supabase implementation** — real DB, all queries respect RLS

Switch between them by overriding the provider:
```dart
// In tests or dev overrides:
bookingRepositoryProvider.overrideWithValue(MockBookingRepository())
```

---

## Prerequisites

| Tool | Version |
|---|---|
| Flutter SDK | ≥ 3.22.0 |
| Dart SDK | ≥ 3.4.0 |
| Supabase project | Any |
| Node.js (backend only) | ≥ 20 |
| Docker + Compose | Optional (local stack) |

---

## Quick Start

### 1 — Clone and install dependencies

```bash
git clone https://github.com/your-org/divine-pooja-services.git
cd divine-pooja-services
flutter pub get
```

### 2 — Configure environment

```bash
cp .env.example .env
# Edit .env with your Supabase project URL and anon key
```

### 3 — Run database migrations

```bash
# Using Supabase CLI (recommended):
supabase db push

# Or run manually in the Supabase SQL Editor in this order:
#   supabase/migrations/001_initial_schema.sql
#   supabase/migrations/002_rls_policies.sql
#   supabase/migrations/003_rpc_functions.sql
```

### 4 — Run the app

```bash
flutter run
```

---

## Project Structure

```
lib/
├── main.dart
├── core/
│   ├── config/          # AppConfig (env keys)
│   ├── providers/       # supabaseClientProvider
│   ├── router/          # app_router.dart (5-tab StatefulShellRoute)
│   └── theme/           # AppColors, AppTheme
├── auth/                # Supabase Auth + UserModel + providers
├── booking/             # 7-step wizard, MockBookingRepository, SupabaseBookingRepository
├── consultation/        # Session model, MockSessionRepository, WsSessionRepository
├── packages/            # Package list/filter, SupabasePackageRepository
├── special_poojas/      # Temple poojas module (calendar, booking)
├── shop/                # Product list, cart, SupabaseShopRepository
├── payment/             # IPaymentService, MockPaymentService
├── pandit/              # Pandit detail + proof upload
├── admin/               # Admin screens (stats, assignment, oversight)
├── account/             # Role-adaptive account tab (user/pandit/admin/unauth)
├── home/                # Home screen, hero slider, categories
└── widgets/             # Shared: LoadingShimmer, etc.

supabase/
└── migrations/
    ├── 001_initial_schema.sql   # All 13 tables
    ├── 002_rls_policies.sql     # Row Level Security
    └── 003_rpc_functions.sql    # Booking/consultation RPCs

test/
├── booking/booking_wizard_test.dart
├── payment/payment_service_test.dart
├── consultation/session_repository_test.dart
└── special_poojas/special_poojas_filter_test.dart
```

---

## Database Migrations

| File | Contents |
|---|---|
| `001_initial_schema.sql` | 13 tables: profiles, pandit_details, packages, special_poojas, bookings, booking_proofs, consultations, messages, consultation_rates, transactions, addresses, products, orders, package_reviews |
| `002_rls_policies.sql` | RLS on all tables. `get_my_role()` SECURITY DEFINER prevents recursion |
| `003_rpc_functions.sql` | `create_booking` (advisory lock), `get_booked_slots`, `update_booking_status`, `assign_pandit_to_booking`, `start/end_consultation_session`, `get_admin_stats`, `get_pandit_earnings` |

### Key design decisions

- **Slot conflict prevention:** `pg_advisory_xact_lock` in `create_booking` + partial unique index `(package_id, booking_date, slot_id) WHERE status != 'cancelled'`
- **RLS without recursion:** `get_my_role()` is `SECURITY DEFINER` — reads `profiles` as function owner
- **Role-authoritative transitions:** `update_booking_status` RPC validates state moves per role

---

## Deployment

### Android

```bash
flutter build apk --release --split-per-abi
flutter build appbundle --release   # for Play Store
```

### iOS

```bash
flutter build ios --release
# Open Xcode → Product → Archive → Distribute App
```

### Backend (Docker)

```bash
docker compose up -d
docker compose logs -f ws-server
docker compose down
```

### Supabase (Production)

1. Create project at [supabase.com](https://supabase.com)
2. Run migrations: `supabase db push`
3. Enable Email + OTP auth providers
4. Create Storage buckets: `booking-proofs` (private), `avatars` (public)
5. Update `.env` with production keys

---

## Running Tests

```bash
# All tests
flutter test

# Single suite
flutter test test/booking/booking_wizard_test.dart

# With coverage
flutter test --coverage
```

---

## Environment Variables

See [.env.example](.env.example) for all required variables.

| Variable | Required | Description |
|---|---|---|
| `SUPABASE_URL` | ✅ | Supabase project URL |
| `SUPABASE_ANON_KEY` | ✅ | Public anon key (Flutter app) |
| `SUPABASE_SERVICE_ROLE_KEY` | ⚠️ Server side only | Never put in Flutter app |
| `REDIS_URL` | Backend only | For consultation session timers |
| `RAZORPAY_KEY_ID` | Phase 2 | Payment integration |

---

## Roadmap — Phase 2

- [ ] Razorpay payment integration
- [ ] FCM push notifications (booking status, consultation requests)
- [ ] Hive offline cache for packages and pandit list
- [ ] Video consultation (Agora SDK)
- [ ] Multi-language (Hindi / Tamil / Telugu)
- [ ] k6 load testing scripts (10k concurrent users)
- [ ] Astrological chart / Kundali generation
