-- =============================================================================
-- MIGRATION 003 â€” RPC Functions + Indexes + Storage Buckets
-- =============================================================================

-- ============================================================
-- FUNCTION: create_booking
-- Atomic slot-safe booking creation with transaction + unique index
-- Prevents race conditions via advisory lock on slot key
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_booking(
  p_package_id       uuid,
  p_special_pooja_id uuid,
  p_package_title    text,
  p_category         text,
  p_booking_date     date,
  p_slot_id          text,
  p_slot             jsonb,
  p_location         jsonb,
  p_pandit_id        uuid,
  p_amount           numeric,
  p_notes            text,
  p_is_auto_assign   boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id      uuid := auth.uid();
  v_booking_id   uuid;
  v_lock_key     bigint;
  v_result       jsonb;
BEGIN
  -- Reject unauthenticated
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Not authenticated', 'code', 'UNAUTHENTICATED');
  END IF;

  -- Advisory lock on slot to prevent race condition
  -- Use hash of (package_id, booking_date, slot_id) as lock key
  v_lock_key := ('x' || substr(md5(p_package_id::text || p_booking_date::text || p_slot_id), 1, 15))::bit(60)::bigint;
  PERFORM pg_advisory_xact_lock(v_lock_key);

  -- Check slot availability (respects partial unique index)
  IF EXISTS (
    SELECT 1 FROM public.bookings
    WHERE package_id   = p_package_id::text
      AND booking_date = p_booking_date
      AND slot_id      = p_slot_id
      AND status       <> 'cancelled'
  ) THEN
    RETURN jsonb_build_object('error', 'Slot already booked', 'code', 'SLOT_CONFLICT');
  END IF;

  -- Insert booking
  INSERT INTO public.bookings (
    id, user_id, pandit_id, package_id, special_pooja_id,
    package_title, category, booking_date, slot_id, slot,
    location, status, amount, notes, is_auto_assigned
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

  -- Increment package booking_count
  IF p_package_id IS NOT NULL THEN
    UPDATE public.packages SET booking_count = booking_count + 1 WHERE id = p_package_id;
  END IF;

  RETURN jsonb_build_object('booking_id', v_booking_id, 'status', 'pending');
END;
$$;

-- ============================================================
-- FUNCTION: get_booked_slots
-- Returns booked slot_ids for a package+date (for UI calendar)
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_booked_slots(
  p_package_id   uuid,
  p_booking_date date
)
RETURNS text[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT ARRAY_AGG(slot_id)
  FROM public.bookings
  WHERE package_id   = p_package_id::text
    AND booking_date = p_booking_date
    AND status       <> 'cancelled';
$$;

-- ============================================================
-- FUNCTION: update_booking_status
-- Server-authoritative status transitions
-- Prevents unauthorized state jumps
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_booking_status(
  p_booking_id uuid,
  p_new_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking      public.bookings%ROWTYPE;
  v_caller_role  text := public.get_my_role();
  v_caller_id    uuid := auth.uid();
BEGIN
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Booking not found');
  END IF;

  -- Validate transitions
  CASE v_caller_role
    WHEN 'user' THEN
      -- Users can only cancel their own pending booking
      IF v_booking.user_id::text <> v_caller_id::text THEN
        RETURN jsonb_build_object('error', 'Forbidden');
      END IF;
      IF p_new_status <> 'cancelled' THEN
        RETURN jsonb_build_object('error', 'Users may only cancel');
      END IF;
      IF v_booking.status NOT IN ('pending') THEN
        RETURN jsonb_build_object('error', 'Cannot cancel â€” booking is ' || v_booking.status);
      END IF;

    WHEN 'pandit' THEN
      -- Pandits can: pendingâ†’confirmed, assignedâ†’completed
      IF v_booking.pandit_id::text <> v_caller_id::text THEN
        RETURN jsonb_build_object('error', 'Forbidden â€” not your booking');
      END IF;
      IF NOT (
        (v_booking.status = 'pending'   AND p_new_status = 'confirmed') OR
        (v_booking.status = 'assigned'  AND p_new_status = 'completed') OR
        (v_booking.status = 'confirmed' AND p_new_status = 'assigned')
      ) THEN
        RETURN jsonb_build_object('error', 'Invalid transition for pandit');
      END IF;

    WHEN 'admin' THEN
      -- Admin can do any valid transition
      NULL;

    ELSE
      RETURN jsonb_build_object('error', 'Unauthorized role');
  END CASE;

  UPDATE public.bookings
    SET status = p_new_status, updated_at = now()
    WHERE id = p_booking_id;

  RETURN jsonb_build_object('success', true, 'status', p_new_status);
END;
$$;

-- ============================================================
-- FUNCTION: assign_pandit_to_booking
-- Admin assigns pandit (also used by auto-assign logic)
-- ============================================================

CREATE OR REPLACE FUNCTION public.assign_pandit_to_booking(
  p_booking_id uuid,
  p_pandit_id  uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text := public.get_my_role();
BEGIN
  IF v_role <> 'admin' THEN
    RETURN jsonb_build_object('error', 'Admin only');
  END IF;

  UPDATE public.bookings
    SET pandit_id  = p_pandit_id,
        status     = 'assigned',
        updated_at = now()
    WHERE id = p_booking_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================
-- FUNCTION: start_consultation_session
-- Creates consultation + marks pandit online
-- Timer management handled by Edge Function + Redis
-- ============================================================

CREATE OR REPLACE FUNCTION public.start_consultation_session(
  p_pandit_id       uuid,
  p_duration_minutes int,
  p_price            numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id       uuid := auth.uid();
  v_session_id    uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Not authenticated');
  END IF;

  -- Check pandit is online + consultation enabled
  IF NOT EXISTS (
    SELECT 1 FROM public.pandit_details
    WHERE id = p_pandit_id
      AND is_online = true
      AND consultation_enabled = true
  ) THEN
    RETURN jsonb_build_object('error', 'Pandit not available');
  END IF;

  -- Check no active session already exists for this user
  IF EXISTS (
    SELECT 1 FROM public.consultations
    WHERE user_id = v_user_id AND status = 'active'
  ) THEN
    RETURN jsonb_build_object('error', 'You already have an active session');
  END IF;

  INSERT INTO public.consultations (
    id, user_id, pandit_id, duration_minutes, price, status, start_ts
  ) VALUES (
    gen_random_uuid(), v_user_id, p_pandit_id,
    p_duration_minutes, p_price, 'active', now()
  )
  RETURNING id INTO v_session_id;

  RETURN jsonb_build_object('session_id', v_session_id, 'started_at', now());
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('error', 'You already have an active session');
END;
$$;

-- ============================================================
-- FUNCTION: end_consultation_session
-- Server-authoritative session end â€” called by Edge Function timer
-- ============================================================

CREATE OR REPLACE FUNCTION public.end_consultation_session(
  p_session_id      uuid,
  p_reason          text DEFAULT 'expired'   -- expired / manual / admin
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session   public.consultations%ROWTYPE;
  v_secs      int;
BEGIN
  SELECT * INTO v_session FROM public.consultations WHERE id = p_session_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Session not found');
  END IF;

  v_secs := EXTRACT(EPOCH FROM (now() - v_session.start_ts))::int;

  UPDATE public.consultations
    SET status           = CASE p_reason WHEN 'expired' THEN 'expired' ELSE 'ended' END,
        end_ts           = now(),
        consumed_minutes = LEAST(CEIL(v_secs / 60.0)::int, v_session.duration_minutes)
    WHERE id = p_session_id;

  RETURN jsonb_build_object('success', true, 'consumed_seconds', v_secs);
END;
$$;

-- ============================================================
-- FUNCTION: get_admin_stats
-- Returns aggregate stats for admin dashboard
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_admin_stats()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF public.get_my_role() <> 'admin' THEN
    RETURN jsonb_build_object('error', 'Admin only');
  END IF;

  SELECT jsonb_build_object(
    'total_bookings',       (SELECT COUNT(*) FROM public.bookings),
    'monthly_bookings',     (SELECT COUNT(*) FROM public.bookings WHERE created_at >= date_trunc('month', now())),
    'total_consultations',  (SELECT COUNT(*) FROM public.consultations),
    'monthly_consultations',(SELECT COUNT(*) FROM public.consultations WHERE created_at >= date_trunc('month', now())),
    'total_revenue',        (SELECT COALESCE(SUM(amount), 0) FROM public.bookings WHERE is_paid = true),
    'monthly_revenue',      (SELECT COALESCE(SUM(amount), 0) FROM public.bookings WHERE is_paid = true AND created_at >= date_trunc('month', now())),
    'active_users',         (SELECT COUNT(DISTINCT user_id) FROM public.bookings WHERE created_at >= now() - interval '30 days'),
    'total_users',          (SELECT COUNT(*) FROM public.profiles WHERE role = 'user'),
    'active_pandits',       (SELECT COUNT(*) FROM public.pandit_details WHERE is_online = true)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ============================================================
-- FUNCTION: get_pandit_earnings
-- Calculates earnings for a specific pandit
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_pandit_earnings(p_pandit_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_role text := public.get_my_role();
  v_caller_id   uuid := auth.uid();
BEGIN
  IF v_caller_role NOT IN ('admin') AND v_caller_id <> p_pandit_id THEN
    RETURN jsonb_build_object('error', 'Forbidden');
  END IF;

  RETURN (
    SELECT jsonb_build_object(
      'total_earned',         COALESCE(SUM(CASE WHEN status = 'completed' THEN amount ELSE 0 END) * 0.8, 0),
      'this_month_earned',    COALESCE(SUM(CASE WHEN status = 'completed' AND created_at >= date_trunc('month', now()) THEN amount ELSE 0 END) * 0.8, 0),
      'pending_payout',       COALESCE(SUM(CASE WHEN status IN ('assigned', 'confirmed') THEN amount ELSE 0 END) * 0.8, 0),
      'completed_count',      COUNT(CASE WHEN status = 'completed' THEN 1 END),
      'this_month_count',     COUNT(CASE WHEN status = 'completed' AND created_at >= date_trunc('month', now()) THEN 1 END)
    )
    FROM public.bookings
    WHERE pandit_id::text = p_pandit_id::text
  );
END;
$$;

-- ============================================================
-- STORAGE BUCKETS
-- Run via Supabase Dashboard or REST API after migration
-- ============================================================

-- NOTE: Storage buckets cannot be created via SQL migrations in self-hosted.
-- Run these in Supabase Dashboard > Storage or via management API:
--
--  INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
--  VALUES
--    ('pooja-proofs', 'pooja-proofs', false, 314572800, -- 300MB
--      ARRAY['video/mp4','video/quicktime','video/webm','image/jpeg','image/png','image/webp']),
--    ('avatars', 'avatars', true, 5242880,              -- 5MB
--      ARRAY['image/jpeg','image/png','image/webp']);
--
-- Storage RLS (in storage schema):
--
-- For pooja-proofs bucket â€” only pandit (owner) + booking user + admin:
--  CREATE POLICY "proofs_upload_pandit" ON storage.objects FOR INSERT TO authenticated
--    WITH CHECK (bucket_id = 'pooja-proofs' AND auth.uid()::text = (storage.foldername(name))[1]);
--
--  CREATE POLICY "proofs_read_authorized" ON storage.objects FOR SELECT TO authenticated
--    USING (
--      bucket_id = 'pooja-proofs'
--      AND (
--        auth.uid()::text = (storage.foldername(name))[1]   -- pandit owns it
--        OR public.get_my_role() = 'admin'
--        OR EXISTS (
--          SELECT 1 FROM public.bookings b
--          JOIN public.booking_proofs bp ON bp.booking_id = b.id
--          WHERE b.user_id = auth.uid()
--            AND (storage.foldername(name))[2] = b.id::text
--        )
--      )
--    );
--
-- For avatars bucket â€” public read, own write:
--  CREATE POLICY "avatars_read" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
--  CREATE POLICY "avatars_write" ON storage.objects FOR INSERT TO authenticated
--    WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- ============================================================
-- SEED DATA â€” Static consultation rates (run after pandits exist)
-- ============================================================

-- Default global rates reference (admin can override per pandit)
COMMENT ON TABLE public.consultation_rates IS
  'Per-pandit consultation pricing. Admin sets via admin_pandits_screen.';

-- ============================================================
-- ADDITIONAL INDEXES for performance at scale
-- ============================================================

-- Partial index on active sessions (small set, hot path)
CREATE INDEX IF NOT EXISTS idx_consultations_active
  ON public.consultations(pandit_id, user_id)
  WHERE status = 'active';

-- Partial index for pandit's assigned bookings
CREATE INDEX IF NOT EXISTS idx_bookings_pandit_active
  ON public.bookings(pandit_id, status)
  WHERE status IN ('assigned', 'confirmed', 'pending');

-- Full-text search on packages
CREATE INDEX IF NOT EXISTS idx_packages_fts
  ON public.packages USING gin(to_tsvector('english', title || ' ' || description));

-- Full-text search on products
CREATE INDEX IF NOT EXISTS idx_products_fts
  ON public.products USING gin(to_tsvector('english', name || ' ' || description));

-- Enforce one active consultation per user at DB level (prevents race in start_consultation_session)
CREATE UNIQUE INDEX IF NOT EXISTS idx_one_active_session_per_user
  ON public.consultations(user_id)
  WHERE status = 'active';
