-- =============================================================================
-- MIGRATION 015 - Definitive create_booking overload fix
-- =============================================================================
-- Problem:
--   Multiple create_booking overloads coexist (created by migrations 003, 007,
--   008, and 010). When the Dart client calls with NULL params that get stripped
--   by the Supabase client, PostgreSQL finds multiple candidate functions and
--   throws "Could not choose the best candidate function".
--
-- Fix:
--   Drop ALL existing create_booking overloads dynamically (regardless of
--   their exact signature), then create a single canonical 14-param function
--   where p_notes has DEFAULT NULL (making notes truly optional and preventing
--   future ambiguity even if the client strips null params).
--
-- Safe to re-run: DROP is dynamic (finds whatever exists), CREATE OR REPLACE
--   is idempotent for a new signature.
-- =============================================================================

-- Step 1: Dynamically drop ALL create_booking overloads in the public schema.
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT oid::regprocedure::text AS sig
    FROM pg_proc
    WHERE proname = 'create_booking'
      AND pronamespace = (
        SELECT oid FROM pg_namespace WHERE nspname = 'public'
      )
  LOOP
    EXECUTE format('DROP FUNCTION %s', r.sig);
  END LOOP;
END;
$$;

-- Step 2: Create the single canonical create_booking function.
--   All optional params (p_notes, p_is_paid, p_payment_id) have DEFAULT values
--   so callers may omit them without causing overload resolution ambiguity.
CREATE FUNCTION public.create_booking(
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
  p_notes            text    DEFAULT NULL,
  p_is_auto_assign   boolean DEFAULT false,
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

  -- Check for slot conflict only when booking a specific pandit.
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
    COALESCE(p_is_paid,    false),
    p_payment_id,
    p_notes,
    p_is_auto_assign
  )
  RETURNING id INTO v_booking_id;

  -- Increment package booking counter for regular poojas.
  IF p_package_id IS NOT NULL THEN
    UPDATE public.packages
    SET booking_count = booking_count + 1
    WHERE id = p_package_id;
  END IF;

  RETURN jsonb_build_object('booking_id', v_booking_id, 'status', 'pending');
END;
$$;
