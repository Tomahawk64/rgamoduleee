-- ==============================================================================
-- MIGRATION 021 - Live Chat & Online Pandit Notifications
-- Run after: 020_start_scheduled_consultation_rpc.sql
-- ==============================================================================

-- ── 1) Add live chat support to consultations table ──────────────────────────
ALTER TABLE public.consultations
  ADD COLUMN IF NOT EXISTS is_live_chat boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS user_joined_at timestamptz,
  ADD COLUMN IF NOT EXISTS pandit_joined_at timestamptz,
  ADD COLUMN IF NOT EXISTS session_started_at timestamptz;

-- Index for finding pending live chat requests for online pandits
CREATE INDEX IF NOT EXISTS idx_consultations_live_pending
  ON public.consultations(pandit_id, status)
  WHERE is_live_chat = true AND status = 'pending';

-- ── 2) RPC: Request live chat (immediate start, no scheduling) ───────────────
CREATE OR REPLACE FUNCTION public.request_live_chat(
  p_pandit_id        uuid,
  p_duration_minutes int,
  p_price            numeric,
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
  v_pandit_online boolean;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'NOT_AUTHENTICATED');
  END IF;

  IF public.get_my_role() <> 'user' THEN
    RETURN jsonb_build_object('error', 'ONLY_USERS_CAN_REQUEST');
  END IF;

  -- Check if pandit is online
  SELECT is_online INTO v_pandit_online
  FROM public.pandit_details
  WHERE id = p_pandit_id;

  IF v_pandit_online IS NULL THEN
    RETURN jsonb_build_object('error', 'PANDIT_NOT_FOUND');
  END IF;

  IF NOT v_pandit_online THEN
    RETURN jsonb_build_object('error', 'PANDIT_NOT_ONLINE');
  END IF;

  -- Create live chat session
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
    customer_note,
    is_live_chat,
    user_joined_at
  ) VALUES (
    v_user_id,
    p_pandit_id,
    now(), -- Start immediately
    p_duration_minutes,
    0,
    p_price,
    'pending', -- Waiting for pandit to join
    COALESCE(p_is_paid, false),
    p_payment_id,
    p_customer_note,
    true, -- This is a live chat
    now() -- User joins immediately
  )
  RETURNING id INTO v_session_id;

  -- Create notification for pandit
  INSERT INTO public.notifications (
    user_id,
    type,
    title,
    message,
    data,
    is_read
  ) VALUES (
    p_pandit_id,
    'live_chat_request',
    'New Live Chat Request',
    'A user wants to start a live chat session now',
    jsonb_build_object(
      'session_id', v_session_id,
      'user_id', v_user_id
    ),
    false
  );

  RETURN jsonb_build_object('session_id', v_session_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_live_chat(
  uuid, int, numeric, boolean, text, text
) TO authenticated;

-- ── 3) RPC: Join live chat session (user or pandit) ───────────────────────────
CREATE OR REPLACE FUNCTION public.join_live_chat(
  p_session_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_role text;
  v_row public.consultations%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'NOT_AUTHENTICATED');
  END IF;

  v_role := public.get_my_role();

  SELECT * INTO v_row
  FROM public.consultations
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'SESSION_NOT_FOUND');
  END IF;

  IF NOT v_row.is_live_chat THEN
    RETURN jsonb_build_object('error', 'NOT_A_LIVE_CHAT_SESSION');
  END IF;

  IF v_row.status NOT IN ('pending', 'active') THEN
    RETURN jsonb_build_object('error', 'SESSION_NOT_JOINABLE');
  END IF;

  -- Update join time based on role
  IF v_role = 'user' AND v_row.user_id = v_user_id THEN
    UPDATE public.consultations
      SET user_joined_at = COALESCE(user_joined_at, now())
      WHERE id = p_session_id;
  ELSIF v_role = 'pandit' AND v_row.pandit_id = v_user_id THEN
    UPDATE public.consultations
      SET pandit_joined_at = COALESCE(pandit_joined_at, now())
      WHERE id = p_session_id;
  ELSE
    RETURN jsonb_build_object('error', 'NOT_PARTICIPANT');
  END IF;

  -- Check if both parties have joined - start session timer
  SELECT * INTO v_row
  FROM public.consultations
  WHERE id = p_session_id;

  IF v_row.user_joined_at IS NOT NULL AND v_row.pandit_joined_at IS NOT NULL
     AND v_row.session_started_at IS NULL THEN
    -- Both parties present, start the session
    UPDATE public.consultations
      SET status = 'active',
          session_started_at = now(),
          updated_at = now()
      WHERE id = p_session_id;
    
    -- Notify the other party that session has started
    IF v_role = 'user' THEN
      INSERT INTO public.notifications (
        user_id,
        type,
        title,
        message,
        data,
        is_read
      ) VALUES (
        v_row.pandit_id,
        'live_chat_started',
        'Live Chat Started',
        'User has joined the chat session',
        jsonb_build_object('session_id', v_session_id),
        false
      );
    ELSE
      INSERT INTO public.notifications (
        user_id,
        type,
        title,
        message,
        data,
        is_read
      ) VALUES (
        v_row.user_id,
        'live_chat_started',
        'Live Chat Started',
        'Pandit has joined the chat session',
        jsonb_build_object('session_id', v_session_id),
        false
      );
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_live_chat(uuid) TO authenticated;

-- ── 4) Trigger: Auto-notify pandit when live chat is requested ───────────────
-- This is handled within the request_live_chat RPC function above

-- ── 5) Add notification types for tracking ───────────────────────────────────
-- The notifications table already exists from migration 012
-- Just ensuring the type column can handle our new notification types

-- ── 6) RPC: Get pending live chat requests for online pandit ────────────────
CREATE OR REPLACE FUNCTION public.get_pending_live_chats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pandit_id uuid := auth.uid();
  v_requests jsonb;
BEGIN
  IF v_pandit_id IS NULL THEN
    RETURN jsonb_build_object('error', 'NOT_AUTHENTICATED');
  END IF;

  IF public.get_my_role() <> 'pandit' THEN
    RETURN jsonb_build_object('error', 'ONLY_PANDITS');
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'session_id', c.id,
      'user_id', c.user_id,
      'user_name', COALESCE(p.full_name, 'User'),
      'duration_minutes', c.duration_minutes,
      'price', c.price,
      'customer_note', c.customer_note,
      'requested_at', c.created_at,
      'user_joined_at', c.user_joined_at
    )
  ) INTO v_requests
  FROM public.consultations c
  LEFT JOIN public.profiles p ON p.id = c.user_id
  WHERE c.pandit_id = v_pandit_id
    AND c.is_live_chat = true
    AND c.status = 'pending';

  RETURN jsonb_build_object('requests', COALESCE(v_requests, '[]'::jsonb));
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_pending_live_chats() TO authenticated;

-- ── 7) RPC: Pandit accepts/rejects live chat request ─────────────────────────
CREATE OR REPLACE FUNCTION public.respond_live_chat_request(
  p_session_id uuid,
  p_action text -- 'accept' or 'reject'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pandit_id uuid := auth.uid();
  v_row public.consultations%ROWTYPE;
BEGIN
  IF v_pandit_id IS NULL THEN
    RETURN jsonb_build_object('error', 'NOT_AUTHENTICATED');
  END IF;

  IF public.get_my_role() <> 'pandit' THEN
    RETURN jsonb_build_object('error', 'ONLY_PANDITS');
  END IF;

  SELECT * INTO v_row
  FROM public.consultations
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'SESSION_NOT_FOUND');
  END IF;

  IF v_row.pandit_id <> v_pandit_id THEN
    RETURN jsonb_build_object('error', 'NOT_YOUR_SESSION');
  END IF;

  IF NOT v_row.is_live_chat THEN
    RETURN jsonb_build_object('error', 'NOT_A_LIVE_CHAT');
  END IF;

  IF v_row.status <> 'pending' THEN
    RETURN jsonb_build_object('error', 'SESSION_NOT_PENDING');
  END IF;

  IF p_action = 'accept' THEN
    UPDATE public.consultations
      SET status = 'active',
          pandit_joined_at = now(),
          session_started_at = now(),
          updated_at = now()
      WHERE id = p_session_id;

    -- Notify user that pandit accepted
    INSERT INTO public.notifications (
      user_id,
      type,
      title,
      message,
      data,
      is_read
    ) VALUES (
      v_row.user_id,
      'live_chat_accepted',
      'Pandit Accepted Your Request',
      'The pandit has joined the chat session',
      jsonb_build_object('session_id', p_session_id),
      false
    );

    RETURN jsonb_build_object('success', true, 'session_id', p_session_id);
  ELSIF p_action = 'reject' THEN
    UPDATE public.consultations
      SET status = 'rejected',
          updated_at = now()
      WHERE id = p_session_id;

    -- Notify user that pandit rejected
    INSERT INTO public.notifications (
      user_id,
      type,
      title,
      message,
      data,
      is_read
    ) VALUES (
      v_row.user_id,
      'live_chat_rejected',
      'Pandit Unable to Join',
      'The pandit is currently unavailable',
      jsonb_build_object('session_id', p_session_id),
      false
    );

    RETURN jsonb_build_object('success', true);
  ELSE
    RETURN jsonb_build_object('error', 'INVALID_ACTION');
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.respond_live_chat_request(uuid, text) TO authenticated;
