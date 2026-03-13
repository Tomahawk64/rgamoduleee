-- =============================================================================
-- MIGRATION 002 — Row Level Security Policies
-- All policies use SECURITY DEFINER helper to avoid recursion
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Drop all existing public-schema policies (makes this script safe to re-run)
-- ---------------------------------------------------------------------------
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT policyname, tablename
    FROM pg_policies
    WHERE schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- SECURITY DEFINER helper — avoids recursion when reading profiles inside RLS
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public AS $$
  SELECT role::text FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.get_my_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public AS $$
  SELECT auth.uid();
$$;

-- ---------------------------------------------------------------------------
-- Enable RLS on all tables
-- ---------------------------------------------------------------------------

ALTER TABLE public.profiles           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pandit_details     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.packages           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.special_poojas     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_proofs     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultations      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultation_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.addresses          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.package_reviews    ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- PROFILES
-- ============================================================

-- Any authenticated user can read any profile (needed for pandit cards)
CREATE POLICY "profiles_select_authed"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (true);

-- Users can only update their own profile
CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Admin can update any profile (for approve/disable pandit)
CREATE POLICY "profiles_update_admin"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (public.get_my_role() = 'admin');

-- No DELETE — soft-delete via is_active
-- Insert handled via trigger only

-- ============================================================
-- PANDIT DETAILS
-- ============================================================

CREATE POLICY "pandit_details_select_authed"
  ON public.pandit_details FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "pandit_details_update_own"
  ON public.pandit_details FOR UPDATE
  TO authenticated
  USING (id = auth.uid());

CREATE POLICY "pandit_details_insert_own"
  ON public.pandit_details FOR INSERT
  TO authenticated
  WITH CHECK (id = auth.uid());

CREATE POLICY "pandit_details_admin_all"
  ON public.pandit_details FOR ALL
  TO authenticated
  USING (public.get_my_role() = 'admin');

-- ============================================================
-- PACKAGES
-- ============================================================

-- Anyone (including anon) can read active packages
CREATE POLICY "packages_select_active"
  ON public.packages FOR SELECT
  USING (is_active = true OR public.get_my_role() = 'admin');

-- Admin full control
CREATE POLICY "packages_admin_all"
  ON public.packages FOR ALL
  TO authenticated
  USING (public.get_my_role() = 'admin');

-- ============================================================
-- SPECIAL POOJAS
-- ============================================================

CREATE POLICY "special_poojas_select_active"
  ON public.special_poojas FOR SELECT
  USING (is_active = true OR public.get_my_role() = 'admin');

CREATE POLICY "special_poojas_admin_all"
  ON public.special_poojas FOR ALL
  TO authenticated
  USING (public.get_my_role() = 'admin');

-- ============================================================
-- BOOKINGS
-- ============================================================

-- Users see only their own bookings
CREATE POLICY "bookings_select_own_user"
  ON public.bookings FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Pandits see bookings assigned to them
CREATE POLICY "bookings_select_own_pandit"
  ON public.bookings FOR SELECT
  TO authenticated
  USING (
    pandit_id = auth.uid()
    AND public.get_my_role() = 'pandit'
  );

-- Admin sees all
CREATE POLICY "bookings_select_admin"
  ON public.bookings FOR SELECT
  TO authenticated
  USING (public.get_my_role() = 'admin');

-- Users can INSERT their own booking (but business logic enforced via RPC)
CREATE POLICY "bookings_insert_own"
  ON public.bookings FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Users can only cancel their own booking (status → cancelled)
-- Pandit can update assigned + status (accept/reject/complete)
-- Admin can update any
CREATE POLICY "bookings_update_user"
  ON public.bookings FOR UPDATE
  TO authenticated
  USING (
    user_id = auth.uid()
    AND public.get_my_role() = 'user'
  )
  WITH CHECK (
    user_id = auth.uid()
    AND status = 'cancelled'   -- users can only cancel
  );

CREATE POLICY "bookings_update_pandit"
  ON public.bookings FOR UPDATE
  TO authenticated
  USING (
    pandit_id = auth.uid()
    AND public.get_my_role() = 'pandit'
  )
  WITH CHECK (
    pandit_id = auth.uid()
    -- Pandit cannot change user_id / amount / payment fields
  );

CREATE POLICY "bookings_update_admin"
  ON public.bookings FOR UPDATE
  TO authenticated
  USING (public.get_my_role() = 'admin');

-- ============================================================
-- BOOKING PROOFS
-- ============================================================

-- Booking owner and admin can SELECT
CREATE POLICY "proofs_select"
  ON public.booking_proofs FOR SELECT
  TO authenticated
  USING (
    pandit_id = auth.uid()
    OR public.get_my_role() = 'admin'
    OR EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = booking_proofs.booking_id
        AND b.user_id = auth.uid()
    )
  );

-- Only the assigned pandit can INSERT proof
CREATE POLICY "proofs_insert_pandit"
  ON public.booking_proofs FOR INSERT
  TO authenticated
  WITH CHECK (
    pandit_id = auth.uid()
    AND public.get_my_role() = 'pandit'
    AND EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = booking_id
        AND b.pandit_id = auth.uid()
        AND b.status = 'completed'
    )
  );

-- Admin can update/verify
CREATE POLICY "proofs_admin_update"
  ON public.booking_proofs FOR UPDATE
  TO authenticated
  USING (public.get_my_role() = 'admin');

-- ============================================================
-- CONSULTATIONS
-- ============================================================

CREATE POLICY "consultations_select_participant"
  ON public.consultations FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR pandit_id = auth.uid()
    OR public.get_my_role() = 'admin'
  );

CREATE POLICY "consultations_insert_user"
  ON public.consultations FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Only server / admin can update timers (status, consumed_minutes, end_ts)
-- Prevent client-side time tampering
CREATE POLICY "consultations_update_admin"
  ON public.consultations FOR UPDATE
  TO authenticated
  USING (public.get_my_role() = 'admin');

-- Edge Function uses service_role — bypasses RLS for timer updates

-- ============================================================
-- MESSAGES
-- ============================================================

-- Only session participants can read messages
CREATE POLICY "messages_select_participant"
  ON public.messages FOR SELECT
  TO authenticated
  USING (
    sender_id = auth.uid()
    OR public.get_my_role() = 'admin'
    OR EXISTS (
      SELECT 1 FROM public.consultations c
      WHERE c.id = messages.consultation_id
        AND (c.user_id = auth.uid() OR c.pandit_id = auth.uid())
    )
  );

-- Session participants can send messages (session must be active)
CREATE POLICY "messages_insert_participant"
  ON public.messages FOR INSERT
  TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.consultations c
      WHERE c.id = consultation_id
        AND c.status = 'active'
        AND (c.user_id = auth.uid() OR c.pandit_id = auth.uid())
    )
  );

-- ============================================================
-- CONSULTATION RATES
-- ============================================================

CREATE POLICY "rates_select_authed"
  ON public.consultation_rates FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "rates_admin_all"
  ON public.consultation_rates FOR ALL
  TO authenticated
  USING (public.get_my_role() = 'admin');

-- ============================================================
-- TRANSACTIONS
-- ============================================================

CREATE POLICY "transactions_select_own"
  ON public.transactions FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.get_my_role() = 'admin'
  );

-- Only system (service_role) can insert transactions
-- No client INSERT policy intentionally

-- ============================================================
-- ADDRESSES
-- ============================================================

CREATE POLICY "addresses_own"
  ON public.addresses FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "addresses_admin_select"
  ON public.addresses FOR SELECT
  TO authenticated
  USING (public.get_my_role() = 'admin');

-- ============================================================
-- PRODUCTS
-- ============================================================

CREATE POLICY "products_select_active"
  ON public.products FOR SELECT
  USING (is_active = true OR public.get_my_role() = 'admin');

CREATE POLICY "products_admin_all"
  ON public.products FOR ALL
  TO authenticated
  USING (public.get_my_role() = 'admin');

-- ============================================================
-- ORDERS
-- ============================================================

CREATE POLICY "orders_own"
  ON public.orders FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.get_my_role() = 'admin'
  );

CREATE POLICY "orders_insert_own"
  ON public.orders FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "orders_update_admin"
  ON public.orders FOR UPDATE
  TO authenticated
  USING (public.get_my_role() = 'admin');

-- ============================================================
-- PACKAGE REVIEWS
-- ============================================================

CREATE POLICY "reviews_select_all"
  ON public.package_reviews FOR SELECT
  USING (true);

CREATE POLICY "reviews_insert_own"
  ON public.package_reviews FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "reviews_update_own"
  ON public.package_reviews FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "reviews_delete_own"
  ON public.package_reviews FOR DELETE
  TO authenticated
  USING (user_id = auth.uid() OR public.get_my_role() = 'admin');
