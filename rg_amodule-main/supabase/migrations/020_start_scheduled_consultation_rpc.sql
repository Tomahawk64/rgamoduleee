-- ══════════════════════════════════════════════════════════════════════════════
-- Migration 020: Scheduled consultation start + join tracking
--
-- 1. Add pandit_joined_at / user_joined_at columns for "both must join"
-- 2. start_scheduled_consultation  — transitions confirmed → active
--    (enforces scheduled_for - 5 min server-side)
-- 3. join_consultation_chat — marks the caller as joined; returns both_joined
-- ══════════════════════════════════════════════════════════════════════════════

-- ── 1. Join-tracking columns ────────────────────────────────────────────────

ALTER TABLE public.consultations
  ADD COLUMN IF NOT EXISTS pandit_joined_at timestamptz,
  ADD COLUMN IF NOT EXISTS user_joined_at   timestamptz;

-- ── 2. start_scheduled_consultation ─────────────────────────────────────────

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

  -- Only confirmed (or already-active) consultations
  IF v_row.status NOT IN ('confirmed', 'active') THEN
    RETURN jsonb_build_object('error', 'SESSION_NOT_CONFIRMED');
  END IF;

  -- Server-side schedule gate: allow 5 min early
  IF v_row.start_ts IS NOT NULL
     AND v_row.status = 'confirmed'
     AND now() < (v_row.start_ts - interval '5 minutes') THEN
    RETURN jsonb_build_object('error', 'TOO_EARLY',
      'scheduled_for', v_row.start_ts::text);
  END IF;

  -- Transition to active only if still confirmed
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

-- ── 3. join_consultation_chat ───────────────────────────────────────────────
--
-- Called when a participant opens the chat screen (connect).
-- Atomically stamps their joined_at column and returns whether both have now
-- joined so the client knows when to start the timer.

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

  -- Stamp the caller's join time (idempotent — keeps first value)
  IF v_uid = v_row.pandit_id AND v_row.pandit_joined_at IS NULL THEN
    UPDATE public.consultations
      SET pandit_joined_at = now(), updated_at = now()
    WHERE id = p_session_id;
    -- Re-read for the return value
    v_row.pandit_joined_at := now();
  ELSIF v_uid = v_row.user_id AND v_row.user_joined_at IS NULL THEN
    UPDATE public.consultations
      SET user_joined_at = now(), updated_at = now()
    WHERE id = p_session_id;
    v_row.user_joined_at := now();
  END IF;

  RETURN jsonb_build_object(
    'ok',          true,
    'both_joined', (v_row.pandit_joined_at IS NOT NULL
                    AND v_row.user_joined_at IS NOT NULL)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_consultation_chat(uuid) TO authenticated;
