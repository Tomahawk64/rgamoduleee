-- =============================================================================
-- MIGRATION 011 - Consultation scheduling lifecycle + chat image media
-- Run after: 010_create_booking_payment_fields.sql
-- =============================================================================

-- ── 1) Consultation table shape for scheduling lifecycle ────────────────────
ALTER TABLE public.consultations
  ADD COLUMN IF NOT EXISTS proposed_ts    timestamptz,
  ADD COLUMN IF NOT EXISTS customer_note  text,
  ADD COLUMN IF NOT EXISTS pandit_note    text,
  ADD COLUMN IF NOT EXISTS is_paid        boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS payment_id     text;

ALTER TABLE public.consultations DROP CONSTRAINT IF EXISTS consultations_status_check;
ALTER TABLE public.consultations
  ADD CONSTRAINT consultations_status_check
  CHECK (
    status IN (
      'pending',
      'confirmed',
      'reschedule_proposed',
      'rejected',
      'active',
      'ended',
      'expired',
      'refunded'
    )
  );

CREATE INDEX IF NOT EXISTS idx_consultations_user_status
  ON public.consultations(user_id, status);
CREATE INDEX IF NOT EXISTS idx_consultations_pandit_status
  ON public.consultations(pandit_id, status);
CREATE INDEX IF NOT EXISTS idx_consultations_proposed_ts
  ON public.consultations(proposed_ts)
  WHERE proposed_ts IS NOT NULL;

-- ── 2) RPC: request consultation slot (user creates paid scheduled request) ──
CREATE OR REPLACE FUNCTION public.request_consultation_slot(
  p_pandit_id        uuid,
  p_duration_minutes int,
  p_price            numeric,
  p_scheduled_for    timestamptz,
  p_is_paid          boolean DEFAULT true,
  p_payment_id       text DEFAULT NULL,
  p_customer_note    text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_session_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'NOT_AUTHENTICATED');
  END IF;

  IF public.get_my_role() <> 'user' THEN
    RETURN jsonb_build_object('error', 'ONLY_USERS_CAN_REQUEST');
  END IF;

  IF p_scheduled_for <= now() THEN
    RETURN jsonb_build_object('error', 'SCHEDULE_TIME_MUST_BE_FUTURE');
  END IF;

  INSERT INTO public.consultations (
    user_id,
    pandit_id,
    start_ts,
    duration_minutes,
    consumed_minutes,
    price,
    status,
    is_paid,
    payment_id,
    customer_note
  ) VALUES (
    v_user_id,
    p_pandit_id,
    p_scheduled_for,
    p_duration_minutes,
    0,
    p_price,
    'pending',
    COALESCE(p_is_paid, false),
    p_payment_id,
    p_customer_note
  )
  RETURNING id INTO v_session_id;

  RETURN jsonb_build_object('session_id', v_session_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_consultation_slot(
  uuid, int, numeric, timestamptz, boolean, text, text
) TO authenticated;

-- ── 3) RPC: pandit accepts/proposes/rejects request ─────────────────────────
CREATE OR REPLACE FUNCTION public.pandit_respond_consultation_request(
  p_session_id   uuid,
  p_action       text,
  p_proposed_ts  timestamptz DEFAULT NULL,
  p_note         text DEFAULT NULL
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
    RETURN jsonb_build_object('error', 'REQUEST_NOT_FOUND');
  END IF;

  IF v_row.pandit_id <> v_user_id THEN
    RETURN jsonb_build_object('error', 'NOT_REQUEST_PANDIT');
  END IF;

  IF v_row.status NOT IN ('pending', 'reschedule_proposed') THEN
    RETURN jsonb_build_object('error', 'REQUEST_NOT_ACTIONABLE');
  END IF;

  IF p_action = 'accept' THEN
    UPDATE public.consultations
      SET status = 'confirmed',
          proposed_ts = NULL,
          pandit_note = COALESCE(p_note, pandit_note),
          updated_at = now()
    WHERE id = p_session_id;
  ELSIF p_action = 'propose' THEN
    IF p_proposed_ts IS NULL OR p_proposed_ts <= now() THEN
      RETURN jsonb_build_object('error', 'PROPOSED_TIME_INVALID');
    END IF;

    UPDATE public.consultations
      SET status = 'reschedule_proposed',
          proposed_ts = p_proposed_ts,
          pandit_note = COALESCE(p_note, pandit_note),
          updated_at = now()
    WHERE id = p_session_id;
  ELSIF p_action = 'reject' THEN
    UPDATE public.consultations
      SET status = 'rejected',
          pandit_note = COALESCE(p_note, pandit_note),
          updated_at = now()
    WHERE id = p_session_id;
  ELSE
    RETURN jsonb_build_object('error', 'INVALID_ACTION');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.pandit_respond_consultation_request(
  uuid, text, timestamptz, text
) TO authenticated;

-- ── 4) RPC: user accepts/declines proposed schedule ─────────────────────────
CREATE OR REPLACE FUNCTION public.user_respond_consultation_proposal(
  p_session_id uuid,
  p_accept     boolean,
  p_note       text DEFAULT NULL
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
    RETURN jsonb_build_object('error', 'REQUEST_NOT_FOUND');
  END IF;

  IF v_row.user_id <> v_user_id THEN
    RETURN jsonb_build_object('error', 'NOT_REQUEST_USER');
  END IF;

  IF v_row.status <> 'reschedule_proposed' THEN
    RETURN jsonb_build_object('error', 'REQUEST_NOT_IN_PROPOSED_STATE');
  END IF;

  IF p_accept THEN
    UPDATE public.consultations
      SET status = 'confirmed',
          start_ts = COALESCE(v_row.proposed_ts, v_row.start_ts),
          proposed_ts = NULL,
          customer_note = COALESCE(p_note, customer_note),
          updated_at = now()
    WHERE id = p_session_id;
  ELSE
    UPDATE public.consultations
      SET status = 'refunded',
          customer_note = COALESCE(p_note, customer_note),
          updated_at = now()
    WHERE id = p_session_id;
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.user_respond_consultation_proposal(
  uuid, boolean, text
) TO authenticated;

-- ── 5) Chat image support in messages + storage bucket policies ─────────────
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS image_url text;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'consultation-chat-media',
  'consultation-chat-media',
  true,
  6291456,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "consultation_chat_media_read_public" ON storage.objects;
CREATE POLICY "consultation_chat_media_read_public"
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'consultation-chat-media');

DROP POLICY IF EXISTS "consultation_chat_media_insert_participants" ON storage.objects;
CREATE POLICY "consultation_chat_media_insert_participants"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'consultation-chat-media'
    AND EXISTS (
      SELECT 1
      FROM public.consultations c
      WHERE c.id::text = split_part(name, '/', 1)
        AND auth.uid() IN (c.user_id, c.pandit_id)
    )
  );

DROP POLICY IF EXISTS "consultation_chat_media_update_participants" ON storage.objects;
CREATE POLICY "consultation_chat_media_update_participants"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'consultation-chat-media'
    AND EXISTS (
      SELECT 1
      FROM public.consultations c
      WHERE c.id::text = split_part(name, '/', 1)
        AND auth.uid() IN (c.user_id, c.pandit_id)
    )
  )
  WITH CHECK (
    bucket_id = 'consultation-chat-media'
    AND EXISTS (
      SELECT 1
      FROM public.consultations c
      WHERE c.id::text = split_part(name, '/', 1)
        AND auth.uid() IN (c.user_id, c.pandit_id)
    )
  );

DROP POLICY IF EXISTS "consultation_chat_media_delete_participants" ON storage.objects;
CREATE POLICY "consultation_chat_media_delete_participants"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'consultation-chat-media'
    AND EXISTS (
      SELECT 1
      FROM public.consultations c
      WHERE c.id::text = split_part(name, '/', 1)
        AND auth.uid() IN (c.user_id, c.pandit_id)
    )
  );
