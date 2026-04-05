-- =============================================================================
-- MIGRATION 014 - Remove ambiguous create_booking overloads
-- =============================================================================
-- Problem:
--   Migration 008 created create_booking with 12 params (no p_is_paid / p_payment_id).
--   Migration 010 created create_booking with 14 params (p_is_paid / p_payment_id
--   with DEFAULT values). Both functions coexist, causing PostgreSQL to throw
--   "Could not choose the best candidate function" when the Dart client calls
--   with 12 named params (omitting the two defaulted ones).
--
-- Fix:
--   Drop the old 12-param overload so only the 010 version (14 params, 2 defaulted)
--   remains. The 010 version is fully backward-compatible: callers that omit
--   p_is_paid / p_payment_id get the defaults (false / NULL).
-- =============================================================================

-- Drop the 12-param overload from migration 008 (without p_is_paid/p_payment_id).
DROP FUNCTION IF EXISTS public.create_booking(
  uuid,   -- p_package_id
  uuid,   -- p_special_pooja_id
  text,   -- p_package_title
  text,   -- p_category
  date,   -- p_booking_date
  text,   -- p_slot_id
  jsonb,  -- p_slot
  jsonb,  -- p_location
  uuid,   -- p_pandit_id
  numeric,-- p_amount
  text,   -- p_notes
  boolean -- p_is_auto_assign
);

-- Also drop any older 11-param overload (migration 003 / 007) if still present.
DROP FUNCTION IF EXISTS public.create_booking(
  uuid,   -- p_package_id
  uuid,   -- p_special_pooja_id
  text,   -- p_package_title
  text,   -- p_category
  date,   -- p_booking_date
  text,   -- p_slot_id
  jsonb,  -- p_slot
  jsonb,  -- p_location
  uuid,   -- p_pandit_id
  numeric,-- p_amount
  boolean -- p_is_auto_assign
);

-- The 14-param function from migration 010 is now the only create_booking.
-- Verify it exists and re-create in case of any partial state:
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
  p_payment_id       text    DEFAULT NULL
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

  -- Advisory lock to prevent race conditions on the same slot.
  v_lock_key := (
    'x' || substr(
      md5(coalesce(v_target_pandit_id::text, 'auto') || p_booking_date::text || p_slot_id),
      1, 15
    )
  )::bit(60)::bigint;
  PERFORM pg_advisory_xact_lock(v_lock_key);

  IF v_target_pandit_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.bookings
    WHERE pandit_id    = v_target_pandit_id
      AND booking_date = p_booking_date
      AND slot_id      = p_slot_id
      AND status      <> 'cancelled'
  ) THEN
    RETURN jsonb_build_object('error', 'Slot already booked', 'code', 'SLOT_CONFLICT');
  END IF;

  INSERT INTO public.bookings (
    id, user_id, pandit_id,
    package_id, special_pooja_id,
    package_title, category,
    booking_date, slot_id, slot,
    location, status, amount,
    is_paid, payment_id, notes, is_auto_assigned
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
    COALESCE(p_is_paid,    false),
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
