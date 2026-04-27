-- =============================================================================
-- MIGRATION 010 - create_booking supports payment fields
-- =============================================================================
-- Purpose:
-- - Keep booking creation fully server-side under SECURITY DEFINER.
-- - Avoid client-side PATCH on bookings (blocked by RLS for normal users).
-- - Allow paid-at-checkout flows (e.g., online special pooja) to persist
--   `is_paid` and `payment_id` atomically at insert time.

DROP FUNCTION IF EXISTS public.create_booking(
  uuid,
  uuid,
  text,
  text,
  date,
  text,
  jsonb,
  jsonb,
  uuid,
  numeric,
  text,
  boolean,
  boolean,
  text
);

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
  p_is_auto_assign   boolean,
  p_is_paid          boolean DEFAULT false,
  p_payment_id       text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id           uuid := auth.uid();
  v_booking_id        uuid;
  v_lock_key          bigint;
  v_target_pandit_id  uuid := CASE WHEN p_is_auto_assign THEN NULL ELSE p_pandit_id END;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Not authenticated', 'code', 'UNAUTHENTICATED');
  END IF;

  -- Lock by (pandit/date/slot). Auto-assign uses a separate namespace.
  v_lock_key := (
    'x' || substr(
      md5(coalesce(v_target_pandit_id::text, 'auto') || p_booking_date::text || p_slot_id),
      1,
      15
    )
  )::bit(60)::bigint;
  PERFORM pg_advisory_xact_lock(v_lock_key);

  IF v_target_pandit_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.bookings
    WHERE pandit_id = v_target_pandit_id
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
    is_paid,
    payment_id,
    notes,
    is_auto_assigned
  ) VALUES (
    gen_random_uuid(),
    v_user_id,
    v_target_pandit_id,
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
    COALESCE(p_is_paid, false),
    p_payment_id,
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
