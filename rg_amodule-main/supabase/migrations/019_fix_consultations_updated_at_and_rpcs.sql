-- ══════════════════════════════════════════════════════════════════════════════
-- Migration 019: Fix "updated_at" column missing from consultations table
--                and recreate the scheduling RPCs that reference it.
-- ══════════════════════════════════════════════════════════════════════════════

-- ── 1) Add updated_at column to consultations table ─────────────────────────
ALTER TABLE public.consultations
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- ── 2) Recreate pandit_respond_consultation_request ─────────────────────────
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

-- ── 3) Recreate user_respond_consultation_proposal ──────────────────────────
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
