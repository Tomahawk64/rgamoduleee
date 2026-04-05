-- supabase/migrations/016_pandit_accept_and_admin_toggle_fixes.sql
--
-- Fix 1: Pandit accept assignment via SECURITY DEFINER RPC
--   Bypasses any RLS edge-cases; validates the pandit is the assigned one.
--
-- Fix 2: Admin toggle pandit active / consultation via SECURITY DEFINER RPCs
--   Ensures the admin can reliably flip is_active / consultation_enabled.
--
-- Fix 3: is_active check on profiles SELECT helper for the Flutter app.

-- ============================================================
-- 1. accept_booking (pandit only)
-- ============================================================
CREATE OR REPLACE FUNCTION public.accept_booking(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id  uuid := auth.uid();
  v_caller_role text := public.get_my_role();
  v_booking    public.bookings%ROWTYPE;
BEGIN
  IF v_caller_role <> 'pandit' THEN
    RETURN jsonb_build_object('error', 'Only pandits can accept bookings');
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Booking not found');
  END IF;

  IF v_booking.pandit_id IS NULL OR v_booking.pandit_id <> v_caller_id THEN
    RETURN jsonb_build_object('error', 'This booking is not assigned to you');
  END IF;

  IF v_booking.pandit_accepted THEN
    -- Already accepted — idempotent success
    RETURN jsonb_build_object('success', true, 'already_accepted', true);
  END IF;

  UPDATE public.bookings
     SET pandit_accepted = true,
         updated_at      = now()
   WHERE id = p_booking_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.accept_booking(uuid) TO authenticated;

-- ============================================================
-- 2. reject_booking (pandit only)
-- ============================================================
CREATE OR REPLACE FUNCTION public.reject_booking(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id   uuid := auth.uid();
  v_caller_role text := public.get_my_role();
  v_booking     public.bookings%ROWTYPE;
BEGIN
  IF v_caller_role <> 'pandit' THEN
    RETURN jsonb_build_object('error', 'Only pandits can reject bookings');
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Booking not found');
  END IF;

  IF v_booking.pandit_id IS NULL OR v_booking.pandit_id <> v_caller_id THEN
    RETURN jsonb_build_object('error', 'This booking is not assigned to you');
  END IF;

  -- Return booking to pending pool
  UPDATE public.bookings
     SET pandit_id       = NULL,
         pandit_name     = NULL,
         status          = 'pending',
         pandit_accepted = false,
         updated_at      = now()
   WHERE id = p_booking_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.reject_booking(uuid) TO authenticated;

-- ============================================================
-- 3. admin_set_pandit_active (admin only)
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_set_pandit_active(
  p_pandit_id uuid,
  p_is_active boolean
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

  UPDATE public.profiles
     SET is_active  = p_is_active,
         updated_at = now()
   WHERE id = p_pandit_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Pandit profile not found');
  END IF;

  RETURN jsonb_build_object('success', true, 'is_active', p_is_active);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_pandit_active(uuid, boolean) TO authenticated;

-- ============================================================
-- 4. admin_set_consultation (admin only)
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_set_consultation(
  p_pandit_id uuid,
  p_enabled   boolean
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

  -- Upsert so it works even if pandit_details row is missing
  INSERT INTO public.pandit_details (id, consultation_enabled, updated_at)
    VALUES (p_pandit_id, p_enabled, now())
  ON CONFLICT (id) DO UPDATE
    SET consultation_enabled = EXCLUDED.consultation_enabled,
        updated_at           = EXCLUDED.updated_at;

  RETURN jsonb_build_object('success', true, 'enabled', p_enabled);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_consultation(uuid, boolean) TO authenticated;

-- ============================================================
-- 5. admin_set_user_active (admin only) — blocks any user role
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_set_user_active(
  p_user_id   uuid,
  p_is_active boolean
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

  UPDATE public.profiles
     SET is_active  = p_is_active,
         updated_at = now()
   WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'User not found');
  END IF;

  RETURN jsonb_build_object('success', true, 'is_active', p_is_active);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_user_active(uuid, boolean) TO authenticated;
