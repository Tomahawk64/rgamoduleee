-- =============================================================================
-- MIGRATION 001 â€” Initial Schema  (IDEMPOTENT â€” safe to re-run)
-- RG AModule â€” Religious Service Marketplace
-- Run order: 001 â†’ 002 â†’ 003 â†’ 004
-- =============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =============================================================================
-- ENUMS  (skip if already exist)
-- =============================================================================

DO $$ BEGIN CREATE TYPE user_role    AS ENUM ('user','pandit','admin'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE booking_status AS ENUM ('pending','confirmed','assigned','completed','cancelled'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE session_status AS ENUM ('active','ended','expired','refunded'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE order_status   AS ENUM ('pending','confirmed','shipped','delivered','cancelled'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- =============================================================================
-- HELPER FUNCTION: updated_at trigger
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- =============================================================================
-- PROFILES TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.profiles (
  id         uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name  text NOT NULL DEFAULT '',
  phone      text,
  role       text NOT NULL DEFAULT 'user',
  is_active  boolean NOT NULL DEFAULT true,
  rating     numeric(3,2) DEFAULT 0.0,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Add columns that may be missing from the live DB
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url  text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at  timestamptz NOT NULL DEFAULT now();

-- profiles_role_check: drop old constraint (may allow wrong values) and recreate
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('user','pandit','admin'));

CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);

DROP TRIGGER IF EXISTS profiles_updated_at ON public.profiles;
CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Trigger: auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'user')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;  -- never block auth signup
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- PANDIT DETAILS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.pandit_details (
  id                   uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  specialties          text[] NOT NULL DEFAULT '{}',
  languages            text[] NOT NULL DEFAULT '{}',
  experience_years     int NOT NULL DEFAULT 0,
  bio                  text,
  is_online            boolean NOT NULL DEFAULT false,
  consultation_enabled boolean NOT NULL DEFAULT false,
  location             text,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS pandit_details_updated_at ON public.pandit_details;
CREATE TRIGGER pandit_details_updated_at
  BEFORE UPDATE ON public.pandit_details
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================================================
-- PACKAGES TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.packages (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title            text NOT NULL,
  description      text NOT NULL DEFAULT '',
  price            numeric(10,2) NOT NULL CHECK (price >= 0),
  duration_minutes int NOT NULL DEFAULT 60,
  is_online        boolean NOT NULL DEFAULT false,
  is_active        boolean NOT NULL DEFAULT true,
  created_at       timestamptz NOT NULL DEFAULT now()
);

-- Add columns missing from older live-DB deployments
ALTER TABLE public.packages ADD COLUMN IF NOT EXISTS discount_price  numeric(10,2) CHECK (discount_price >= 0);
ALTER TABLE public.packages ADD COLUMN IF NOT EXISTS is_offline       boolean NOT NULL DEFAULT true;
ALTER TABLE public.packages ADD COLUMN IF NOT EXISTS category         text NOT NULL DEFAULT 'puja';
ALTER TABLE public.packages ADD COLUMN IF NOT EXISTS includes         text[] NOT NULL DEFAULT '{}';
ALTER TABLE public.packages ADD COLUMN IF NOT EXISTS image_url        text;
ALTER TABLE public.packages ADD COLUMN IF NOT EXISTS is_featured      boolean NOT NULL DEFAULT false;
ALTER TABLE public.packages ADD COLUMN IF NOT EXISTS is_popular       boolean NOT NULL DEFAULT false;
ALTER TABLE public.packages ADD COLUMN IF NOT EXISTS booking_count    int NOT NULL DEFAULT 0;
ALTER TABLE public.packages ADD COLUMN IF NOT EXISTS rating           numeric(3,2) DEFAULT 0.0;
ALTER TABLE public.packages ADD COLUMN IF NOT EXISTS review_count     int NOT NULL DEFAULT 0;
ALTER TABLE public.packages ADD COLUMN IF NOT EXISTS updated_at       timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_packages_active   ON public.packages(is_active);
CREATE INDEX IF NOT EXISTS idx_packages_category ON public.packages(category);
CREATE INDEX IF NOT EXISTS idx_packages_featured ON public.packages(is_featured) WHERE is_featured = true;
CREATE INDEX IF NOT EXISTS idx_packages_popular  ON public.packages(is_popular)  WHERE is_popular  = true;

DROP TRIGGER IF EXISTS packages_updated_at ON public.packages;
CREATE TRIGGER packages_updated_at
  BEFORE UPDATE ON public.packages
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================================================
-- SPECIAL POOJAS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.special_poojas (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title            text NOT NULL,
  description      text NOT NULL DEFAULT '',
  significance     text,
  temple_name      text,
  location         jsonb,
  price            numeric(10,2) NOT NULL CHECK (price >= 0),
  duration_minutes int NOT NULL DEFAULT 60,
  image_url        text,
  is_active        boolean NOT NULL DEFAULT true,
  available_from   date,
  available_until  date,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_special_poojas_active ON public.special_poojas(is_active);

DROP TRIGGER IF EXISTS special_poojas_updated_at ON public.special_poojas;
CREATE TRIGGER special_poojas_updated_at
  BEFORE UPDATE ON public.special_poojas
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================================================
-- BOOKINGS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.bookings (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  pandit_id        uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  package_id       uuid REFERENCES public.packages(id) ON DELETE RESTRICT,
  package_title    text NOT NULL,
  category         text NOT NULL DEFAULT 'puja',
  booking_date     date NOT NULL,
  slot_id          text NOT NULL,
  slot             jsonb NOT NULL,
  location         jsonb NOT NULL,
  status           text NOT NULL DEFAULT 'pending',
  amount           numeric(10,2) NOT NULL DEFAULT 0,
  is_paid          boolean NOT NULL DEFAULT false,
  payment_id       text,
  notes            text,
  is_auto_assigned boolean NOT NULL DEFAULT false,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

-- Add columns that may be missing
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS special_pooja_id uuid REFERENCES public.special_poojas(id) ON DELETE RESTRICT;

-- Bookings status check
ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_status_check;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_status_check
  CHECK (status IN ('pending','confirmed','assigned','completed','cancelled'));

CREATE INDEX IF NOT EXISTS idx_bookings_user    ON public.bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_pandit  ON public.bookings(pandit_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status  ON public.bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_date    ON public.bookings(booking_date);
CREATE INDEX IF NOT EXISTS idx_bookings_created ON public.bookings(created_at DESC);

-- Partial unique index for slot conflict prevention (safe to re-run)
DROP INDEX IF EXISTS idx_unique_slot_per_package;
CREATE UNIQUE INDEX idx_unique_slot_per_package
  ON public.bookings(package_id, booking_date, slot_id)
  WHERE status <> 'cancelled';

ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS unique_active_slot;

DROP TRIGGER IF EXISTS bookings_updated_at ON public.bookings;
CREATE TRIGGER bookings_updated_at
  BEFORE UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================================================
-- BOOKING PROOFS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.booking_proofs (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id           uuid NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  pandit_id            uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  video_storage_path   text,
  video_duration_secs  int,
  image_storage_paths  text[] NOT NULL DEFAULT '{}',
  uploaded_at          timestamptz NOT NULL DEFAULT now(),
  is_verified          boolean NOT NULL DEFAULT false,
  verifier_note        text,
  CONSTRAINT unique_proof_per_booking UNIQUE (booking_id)
);

CREATE INDEX IF NOT EXISTS idx_proofs_booking ON public.booking_proofs(booking_id);
CREATE INDEX IF NOT EXISTS idx_proofs_pandit  ON public.booking_proofs(pandit_id);

-- =============================================================================
-- CONSULTATIONS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.consultations (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  pandit_id        uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  start_ts         timestamptz,
  end_ts           timestamptz,
  duration_minutes int NOT NULL DEFAULT 10,
  consumed_minutes int NOT NULL DEFAULT 0,
  status           text NOT NULL DEFAULT 'active',
  price            numeric(10,2) NOT NULL DEFAULT 0,
  created_at       timestamptz NOT NULL DEFAULT now()
);

-- Add columns that may be missing
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS package_id  uuid REFERENCES public.packages(id) ON DELETE SET NULL;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS is_paid     boolean NOT NULL DEFAULT false;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS payment_id  text;

ALTER TABLE public.consultations DROP CONSTRAINT IF EXISTS consultations_status_check;
ALTER TABLE public.consultations ADD CONSTRAINT consultations_status_check
  CHECK (status IN ('active','ended','expired','refunded'));

CREATE INDEX IF NOT EXISTS idx_consultations_user   ON public.consultations(user_id);
CREATE INDEX IF NOT EXISTS idx_consultations_pandit ON public.consultations(pandit_id);
CREATE INDEX IF NOT EXISTS idx_consultations_status ON public.consultations(status);

-- =============================================================================
-- MESSAGES TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.messages (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  consultation_id uuid NOT NULL REFERENCES public.consultations(id) ON DELETE CASCADE,
  sender_id       uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  content         text NOT NULL,
  metadata        jsonb,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_messages_consultation      ON public.messages(consultation_id);
CREATE INDEX IF NOT EXISTS idx_messages_consultation_time ON public.messages(consultation_id, created_at);

-- =============================================================================
-- CONSULTATION RATES TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.consultation_rates (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pandit_id        uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  duration_minutes int NOT NULL,
  price            numeric(10,2) NOT NULL,
  is_active        boolean NOT NULL DEFAULT true,
  CONSTRAINT unique_rate_per_duration UNIQUE (pandit_id, duration_minutes)
);

CREATE INDEX IF NOT EXISTS idx_rates_pandit ON public.consultation_rates(pandit_id);

-- =============================================================================
-- TRANSACTIONS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.transactions (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  booking_id       uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  consultation_id  uuid REFERENCES public.consultations(id) ON DELETE SET NULL,
  payment_provider text NOT NULL DEFAULT 'mock',
  provider_data    jsonb,
  amount           numeric(10,2) NOT NULL,
  status           text NOT NULL DEFAULT 'pending',
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_transactions_user    ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_booking ON public.transactions(booking_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status  ON public.transactions(status);

-- =============================================================================
-- ADDRESSES TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.addresses (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  label        text NOT NULL DEFAULT 'Home',
  address_line text NOT NULL,
  city         text NOT NULL,
  state        text NOT NULL DEFAULT '',
  pincode      text NOT NULL,
  is_default   boolean NOT NULL DEFAULT false,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_addresses_user ON public.addresses(user_id);

-- =============================================================================
-- SHOP PRODUCTS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.products (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name           text NOT NULL,
  description    text NOT NULL DEFAULT '',
  price_paise    int NOT NULL CHECK (price_paise >= 0),
  category       text NOT NULL DEFAULT 'other',
  image_url      text,
  stock          int NOT NULL DEFAULT 0,
  includes       text[] NOT NULL DEFAULT '{}',
  is_active      boolean NOT NULL DEFAULT true,
  is_best_seller boolean NOT NULL DEFAULT false,
  rating         numeric(3,2) DEFAULT 0.0,
  review_count   int NOT NULL DEFAULT 0,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_products_active   ON public.products(is_active);
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category);

DROP TRIGGER IF EXISTS products_updated_at ON public.products;
CREATE TRIGGER products_updated_at
  BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================================================
-- ORDERS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.orders (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  items          jsonb NOT NULL,
  subtotal_paise int NOT NULL,
  tax_paise      int NOT NULL DEFAULT 0,
  total_paise    int NOT NULL,
  status         text NOT NULL DEFAULT 'pending',
  shipping_addr  jsonb,
  payment_id     text,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_orders_user   ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);

DROP TRIGGER IF EXISTS orders_updated_at ON public.orders;
CREATE TRIGGER orders_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================================================
-- PACKAGE REVIEWS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.package_reviews (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id uuid NOT NULL REFERENCES public.packages(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rating     int NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment    text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT one_review_per_user UNIQUE (package_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_reviews_package ON public.package_reviews(package_id);
