-- =============================================================================
-- MIGRATION 025 - Consultation payment unlock + join notifications
-- =============================================================================

-- Marks a consultation as paid after successful client-side Razorpay payment.
CREATE OR REPLACE FUNCTION public.mark_consultation_paid(
  p_session_id uuid,
  p_payment_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.consultations%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('error', 'NOT_AUTHENTICATED');
  END IF;

  IF coalesce(trim(p_payment_id), '') = '' THEN
    RETURN jsonb_build_object('error', 'PAYMENT_ID_REQUIRED');
  END IF;

  SELECT * INTO v_row
  FROM public.consultations
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'SESSION_NOT_FOUND');
  END IF;

  IF v_row.user_id <> v_uid AND public.get_my_role() <> 'admin' THEN
    RETURN jsonb_build_object('error', 'NOT_AUTHORIZED');
  END IF;

  IF v_row.status NOT IN ('confirmed', 'pending', 'reschedule_proposed') THEN
    RETURN jsonb_build_object('error', 'SESSION_NOT_PAYABLE');
  END IF;

  UPDATE public.consultations
  SET is_paid = true,
      payment_id = p_payment_id,
      updated_at = now()
  WHERE id = p_session_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_consultation_paid(uuid, text) TO authenticated;

-- Join consultation room and prompt the counterpart to join.
CREATE OR REPLACE FUNCTION public.join_consultation_chat(
  p_session_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid  uuid := auth.uid();
  v_row  public.consultations%ROWTYPE;
  v_target uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('error', 'NOT_AUTHENTICATED');
  END IF;

  SELECT * INTO v_row
  FROM public.consultations
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'SESSION_NOT_FOUND');
  END IF;

  IF v_row.pandit_id <> v_uid AND v_row.user_id <> v_uid THEN
    RETURN jsonb_build_object('error', 'NOT_AUTHORIZED');
  END IF;

  IF v_uid = v_row.pandit_id AND v_row.pandit_joined_at IS NULL THEN
    UPDATE public.consultations
      SET pandit_joined_at = now(), updated_at = now()
    WHERE id = p_session_id;
    v_row.pandit_joined_at := now();
  ELSIF v_uid = v_row.user_id AND v_row.user_joined_at IS NULL THEN
    UPDATE public.consultations
      SET user_joined_at = now(), updated_at = now()
    WHERE id = p_session_id;
    v_row.user_joined_at := now();
  END IF;

  IF (v_row.pandit_joined_at IS NULL OR v_row.user_joined_at IS NULL) THEN
    v_target := CASE WHEN v_uid = v_row.user_id THEN v_row.pandit_id ELSE v_row.user_id END;

    INSERT INTO public.notifications(
      user_id,
      type,
      title,
      message,
      data,
      is_read
    )
    VALUES (
      v_target,
      'consultation_room_join',
      'Partner joined room',
      'Your consultation room is ready. Tap Chat Now to join.',
      jsonb_build_object('session_id', p_session_id),
      false
    );
  END IF;

  RETURN jsonb_build_object(
    'ok',          true,
    'both_joined', (v_row.pandit_joined_at IS NOT NULL
                    AND v_row.user_joined_at IS NOT NULL)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_consultation_chat(uuid) TO authenticated;

-- Payment gate for starting scheduled consultation chat.
CREATE OR REPLACE FUNCTION public.start_scheduled_consultation(
  p_session_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_row public.consultations%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'NOT_AUTHENTICATED');
  END IF;

  SELECT * INTO v_row
  FROM public.consultations
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'SESSION_NOT_FOUND');
  END IF;

  IF v_row.pandit_id <> v_user_id AND v_row.user_id <> v_user_id THEN
    RETURN jsonb_build_object('error', 'NOT_AUTHORIZED');
  END IF;

  IF v_row.status NOT IN ('confirmed', 'active') THEN
    RETURN jsonb_build_object('error', 'SESSION_NOT_CONFIRMED');
  END IF;

  IF NOT COALESCE(v_row.is_paid, false) THEN
    RETURN jsonb_build_object('error', 'PAYMENT_REQUIRED');
  END IF;

  IF v_row.start_ts IS NOT NULL
     AND v_row.status = 'confirmed'
     AND now() < (v_row.start_ts - interval '5 minutes') THEN
    RETURN jsonb_build_object('error', 'TOO_EARLY',
      'scheduled_for', v_row.start_ts::text);
  END IF;

  IF v_row.status = 'confirmed' THEN
    UPDATE public.consultations
      SET status     = 'active',
          start_ts   = now(),
          updated_at = now()
    WHERE id = p_session_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'session_id', p_session_id,
    'started_at', now()::text
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.start_scheduled_consultation(uuid) TO authenticated;
