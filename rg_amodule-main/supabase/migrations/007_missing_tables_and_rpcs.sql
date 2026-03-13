-- =============================================================================
-- MIGRATION 007 - Compatibility Cleanup + Required RPC Fixes
--
-- Why this exists:
-- - A previous 007 variant used a newer transactions shape
--   (reference_type/reference_id) that breaks on existing DBs where
--   transactions has booking_id/consultation_id columns.
-- - This script normalizes schema safely and keeps only what the Flutter app
--   currently depends on.
--
-- Safe to re-run.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Clean up experimental artifacts from failed/partial 007 attempts
-- -----------------------------------------------------------------------------

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'i'
      AND n.nspname = 'public'
      AND c.relname = 'idx_transactions_ref'
  ) THEN
    EXECUTE 'DROP INDEX public.idx_transactions_ref';
  END IF;
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'transactions'
      AND column_name = 'reference_type'
  ) THEN
    EXECUTE 'ALTER TABLE public.transactions DROP COLUMN reference_type';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'transactions'
      AND column_name = 'reference_id'
  ) THEN
    EXECUTE 'ALTER TABLE public.transactions DROP COLUMN reference_id';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'transactions'
      AND column_name = 'gateway'
  ) THEN
    EXECUTE 'ALTER TABLE public.transactions DROP COLUMN gateway';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'transactions'
      AND column_name = 'gateway_txn_id'
  ) THEN
    EXECUTE 'ALTER TABLE public.transactions DROP COLUMN gateway_txn_id';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'transactions'
      AND column_name = 'amount_paise'
  ) THEN
    EXECUTE 'ALTER TABLE public.transactions DROP COLUMN amount_paise';
  END IF;
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'addresses'
      AND column_name = 'address_line'
  ) THEN
    UPDATE public.addresses
    SET address_line = ''
    WHERE address_line IS NULL;

    ALTER TABLE public.addresses
      ALTER COLUMN address_line SET NOT NULL;
  END IF;
END;
$$;

-- Keep transactions aligned with migration 001 shape
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

CREATE INDEX IF NOT EXISTS idx_transactions_user
  ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_booking
  ON public.transactions(booking_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status
  ON public.transactions(status);

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "transactions_select_own" ON public.transactions;
DROP POLICY IF EXISTS "transactions_select" ON public.transactions;

CREATE POLICY "transactions_select_own" ON public.transactions
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.get_my_role() = 'admin');

-- -----------------------------------------------------------------------------
-- 2) Normalize addresses column names to canonical schema
-- -----------------------------------------------------------------------------

ALTER TABLE public.addresses
  ADD COLUMN IF NOT EXISTS address_line text;
ALTER TABLE public.addresses
  ADD COLUMN IF NOT EXISTS state text NOT NULL DEFAULT '';

UPDATE public.addresses
SET address_line = ''
WHERE address_line IS NULL;

ALTER TABLE public.addresses
  ALTER COLUMN address_line SET NOT NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'addresses'
      AND column_name = 'line1'
  ) THEN
    EXECUTE 'UPDATE public.addresses
             SET address_line = COALESCE(address_line, line1)';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'addresses'
      AND column_name = 'state_name'
  ) THEN
    EXECUTE 'UPDATE public.addresses
             SET state = COALESCE(NULLIF(state, ''''), state_name, '''')';
  END IF;
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'addresses'
      AND column_name = 'line1'
  ) THEN
    EXECUTE 'ALTER TABLE public.addresses DROP COLUMN line1';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'addresses'
      AND column_name = 'line2'
  ) THEN
    EXECUTE 'ALTER TABLE public.addresses DROP COLUMN line2';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'addresses'
      AND column_name = 'state_name'
  ) THEN
    EXECUTE 'ALTER TABLE public.addresses DROP COLUMN state_name';
  END IF;
END;
$$;

-- Remove optional booking_id from package_reviews if introduced by an old script
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'package_reviews'
      AND column_name = 'booking_id'
  ) THEN
    EXECUTE 'ALTER TABLE public.package_reviews DROP COLUMN booking_id';
  END IF;
END;
$$;

-- -----------------------------------------------------------------------------
-- 3) Remove unused notification subsystem (not used by current app code)
-- -----------------------------------------------------------------------------

DROP TRIGGER IF EXISTS on_booking_status_change ON public.bookings;
DROP FUNCTION IF EXISTS public.handle_booking_status_change();
DROP FUNCTION IF EXISTS public.notify_user(uuid, text, text, text, jsonb);
DROP TABLE IF EXISTS public.notifications;

-- -----------------------------------------------------------------------------
-- 4) Ensure products schema/policies expected by shop + admin modules
-- -----------------------------------------------------------------------------

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

ALTER TABLE public.products ADD COLUMN IF NOT EXISTS image_url text;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS includes text[] NOT NULL DEFAULT '{}';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS is_best_seller boolean NOT NULL DEFAULT false;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS rating numeric(3,2) DEFAULT 0.0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS review_count int NOT NULL DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_products_active
  ON public.products(is_active);
CREATE INDEX IF NOT EXISTS idx_products_category
  ON public.products(category);

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "products_select_active" ON public.products;
DROP POLICY IF EXISTS "products_admin_all" ON public.products;

CREATE POLICY "products_select_active" ON public.products
  FOR SELECT USING (is_active = true OR public.get_my_role() = 'admin');

CREATE POLICY "products_admin_all" ON public.products
  FOR ALL TO authenticated
  USING (public.get_my_role() = 'admin');

DROP TRIGGER IF EXISTS products_updated_at ON public.products;
CREATE TRIGGER products_updated_at
  BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- -----------------------------------------------------------------------------
-- 5) Profiles email column + admin users RPC
-- -----------------------------------------------------------------------------

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS email text;

UPDATE public.profiles p
SET email = u.email
FROM auth.users u
WHERE p.id = u.id
  AND (p.email IS NULL OR p.email = '');

CREATE OR REPLACE FUNCTION public.get_users_for_admin()
RETURNS TABLE (
  id         uuid,
  full_name  text,
  role       text,
  is_active  boolean,
  phone      text,
  created_at timestamptz,
  email      text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF public.get_my_role() <> 'admin' THEN
    RAISE EXCEPTION 'Admin only';
  END IF;

  RETURN QUERY
    SELECT
      p.id,
      p.full_name,
      p.role,
      p.is_active,
      p.phone,
      p.created_at,
      COALESCE(p.email, u.email) AS email
    FROM public.profiles p
    LEFT JOIN auth.users u ON u.id = p.id
    ORDER BY p.created_at DESC;
END;
$$;

-- -----------------------------------------------------------------------------
-- 6) Admin stats RPC used by admin dashboard report
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_admin_stats()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text := public.get_my_role();
  v_now timestamptz := now();
  v_month_start timestamptz := date_trunc('month', v_now);

  v_total_bookings bigint;
  v_monthly_bookings bigint;
  v_total_consultations bigint;
  v_monthly_consultations bigint;
  v_monthly_revenue numeric;
  v_total_revenue numeric;
  v_active_users bigint;
  v_total_users bigint;
  v_active_pandits bigint;
BEGIN
  IF v_role <> 'admin' THEN
    RETURN jsonb_build_object('error', 'Admin only');
  END IF;

  SELECT COUNT(*) INTO v_total_bookings FROM public.bookings;
  SELECT COUNT(*) INTO v_monthly_bookings
    FROM public.bookings
    WHERE created_at >= v_month_start;

  SELECT COUNT(*) INTO v_total_consultations FROM public.consultations;
  SELECT COUNT(*) INTO v_monthly_consultations
    FROM public.consultations
    WHERE created_at >= v_month_start;

  SELECT COALESCE(SUM(amount), 0) INTO v_monthly_revenue
    FROM public.bookings
    WHERE created_at >= v_month_start
      AND is_paid = true;

  SELECT COALESCE(SUM(amount), 0) INTO v_total_revenue
    FROM public.bookings
    WHERE is_paid = true;

  SELECT COUNT(*) INTO v_total_users
    FROM public.profiles
    WHERE role = 'user';

  SELECT COUNT(*) INTO v_active_users
    FROM public.profiles
    WHERE role = 'user'
      AND is_active = true;

  SELECT COUNT(*) INTO v_active_pandits
    FROM public.profiles
    WHERE role = 'pandit'
      AND is_active = true;

  RETURN jsonb_build_object(
    'total_bookings', v_total_bookings,
    'monthly_bookings', v_monthly_bookings,
    'total_consultations', v_total_consultations,
    'monthly_consultations', v_monthly_consultations,
    'monthly_revenue', v_monthly_revenue,
    'total_revenue', v_total_revenue,
    'active_users', v_active_users,
    'total_users', v_total_users,
    'active_pandits', v_active_pandits
  );
END;
$$;

-- -----------------------------------------------------------------------------
-- 7) Consultation session RPC (compatible with user + pandit + admin flows)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.end_consultation_session(
  p_session_id uuid,
  p_reason text DEFAULT 'manual'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text := public.get_my_role();
  v_auth_role text := auth.role();
  v_caller_id uuid := auth.uid();
  v_session public.consultations%ROWTYPE;
  v_new_status text;
  v_elapsed_minutes int;
BEGIN
  IF v_auth_role <> 'service_role' AND v_role NOT IN ('admin', 'pandit', 'user') THEN
    RETURN jsonb_build_object('error', 'Forbidden');
  END IF;

  SELECT *
  INTO v_session
  FROM public.consultations
  WHERE id = p_session_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Session not found');
  END IF;

  IF v_auth_role <> 'service_role' AND v_role = 'pandit' AND v_session.pandit_id <> v_caller_id THEN
    RETURN jsonb_build_object('error', 'Not your session');
  END IF;

  IF v_auth_role <> 'service_role' AND v_role = 'user' AND v_session.user_id <> v_caller_id THEN
    RETURN jsonb_build_object('error', 'Not your session');
  END IF;

  IF p_reason = 'expired' THEN
    v_new_status := 'expired';
  ELSIF p_reason = 'refund' THEN
    v_new_status := 'refunded';
  ELSE
    v_new_status := 'ended';
  END IF;

  v_elapsed_minutes := CEIL(
    EXTRACT(EPOCH FROM (now() - COALESCE(v_session.start_ts, now()))) / 60.0
  )::int;

  UPDATE public.consultations
  SET
    status = v_new_status,
    end_ts = COALESCE(end_ts, now()),
    consumed_minutes = LEAST(
      GREATEST(COALESCE(consumed_minutes, 0), GREATEST(v_elapsed_minutes, 0)),
      GREATEST(COALESCE(duration_minutes, 0), 0)
    )
  WHERE id = p_session_id;

  RETURN jsonb_build_object(
    'success', true,
    'session_id', p_session_id,
    'status', v_new_status,
    'reason', p_reason
  );
END;
$$;

-- -----------------------------------------------------------------------------
-- 8) Booking RPC fix: keep package_id comparison as uuid (no ::text cast)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_booking(
  p_package_id uuid,
  p_special_pooja_id uuid,
  p_package_title text,
  p_category text,
  p_booking_date date,
  p_slot_id text,
  p_slot jsonb,
  p_location jsonb,
  p_pandit_id uuid,
  p_amount numeric,
  p_notes text,
  p_is_auto_assign boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_booking_id uuid;
  v_lock_key bigint;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Not authenticated', 'code', 'UNAUTHENTICATED');
  END IF;

  v_lock_key := ('x' || substr(md5(p_package_id::text || p_booking_date::text || p_slot_id), 1, 15))::bit(60)::bigint;
  PERFORM pg_advisory_xact_lock(v_lock_key);

  IF EXISTS (
    SELECT 1
    FROM public.bookings
    WHERE package_id::text = p_package_id::text
      AND booking_date = p_booking_date
      AND slot_id = p_slot_id
      AND status <> 'cancelled'
  ) THEN
    RETURN jsonb_build_object('error', 'Slot already booked', 'code', 'SLOT_CONFLICT');
  END IF;

  INSERT INTO public.bookings (
    id,
    user_id,
    pandit_id,
    package_id,
    special_pooja_id,
    package_title,
    category,
    booking_date,
    slot_id,
    slot,
    location,
    status,
    amount,
    notes,
    is_auto_assigned
  ) VALUES (
    gen_random_uuid(),
    v_user_id,
    CASE WHEN p_is_auto_assign THEN NULL ELSE p_pandit_id END,
    p_package_id,
    p_special_pooja_id,
    p_package_title,
    p_category,
    p_booking_date,
    p_slot_id,
    p_slot,
    p_location,
    'pending',
    p_amount,
    p_notes,
    p_is_auto_assign
  )
  RETURNING id INTO v_booking_id;

  IF p_package_id IS NOT NULL THEN
    UPDATE public.packages
    SET booking_count = booking_count + 1
    WHERE id::text = p_package_id::text;
  END IF;

  RETURN jsonb_build_object('booking_id', v_booking_id, 'status', 'pending');
END;
$$;

-- Keep get_booked_slots in sync with uuid package_id comparisons.
CREATE OR REPLACE FUNCTION public.get_booked_slots(
  p_package_id uuid,
  p_booking_date date
)
RETURNS text[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(ARRAY_AGG(slot_id), ARRAY[]::text[])
  FROM public.bookings
  WHERE package_id::text = p_package_id::text
    AND booking_date = p_booking_date
    AND status <> 'cancelled';
$$;
