-- =============================================================================
-- MIGRATION 008 - Pandit-specific slot conflict handling
-- =============================================================================
-- Goal:
-- 1) Allow same package/date/slot for different pandits.
-- 2) Prevent double-booking of the same pandit for same date/slot.
-- 3) Keep auto-assign (pandit_id NULL) bookings unblocked at slot step.

-- Replace old package-level unique slot index.
DROP INDEX IF EXISTS idx_unique_slot_per_package;

CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_slot_per_pandit
  ON public.bookings(pandit_id, booking_date, slot_id)
  WHERE status <> 'cancelled' AND pandit_id IS NOT NULL;

-- ----------------------------------------------------------------------------
-- RPC: create_booking
-- Conflict is checked only when booking is for a specific pandit.
-- ----------------------------------------------------------------------------
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
  v_target_pandit_id uuid := CASE WHEN p_is_auto_assign THEN NULL ELSE p_pandit_id END;
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

-- ----------------------------------------------------------------------------
-- RPC: get_booked_slots
-- Returns slots for selected pandit only. For auto-assign (NULL pandit),
-- return empty set so users can proceed and assignment can happen later.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_booked_slots(
  p_package_id uuid,
  p_booking_date date,
  p_pandit_id uuid DEFAULT NULL
)
RETURNS text[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_pandit_id IS NULL THEN ARRAY[]::text[]
    ELSE (
      SELECT COALESCE(ARRAY_AGG(slot_id), ARRAY[]::text[])
      FROM public.bookings
      WHERE pandit_id = p_pandit_id
        AND booking_date = p_booking_date
        AND status <> 'cancelled'
    )
  END;
$$;
