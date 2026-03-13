-- =============================================================================
-- MIGRATION 004 — Atomic session-duration increment RPC
-- Run after: 003_rpc_functions.sql
-- =============================================================================

-- ============================================================
-- FUNCTION: increment_session_duration
-- Atomically increments duration_minutes on an active session.
-- Single UPDATE — no read-modify-write race.
-- Called by extendSession() in WsSessionRepository instead of
-- the old client-side read + write pattern.
-- ============================================================

CREATE OR REPLACE FUNCTION public.increment_session_duration(
  p_session_id  uuid,
  p_add_minutes int
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
BEGIN
  -- Only the session owner (user) or an admin may extend.
  IF NOT EXISTS (
    SELECT 1 FROM public.consultations
    WHERE id      = p_session_id
      AND user_id = v_caller_id
      AND status  = 'active'
  ) AND public.get_my_role() <> 'admin' THEN
    RAISE EXCEPTION 'Forbidden or session not active';
  END IF;

  -- Atomic increment — no read required on the client side.
  UPDATE public.consultations
    SET duration_minutes = duration_minutes + p_add_minutes
    WHERE id = p_session_id
      AND status = 'active';
END;
$$;

-- Grant execution to authenticated users (matches SECURITY DEFINER pattern).
GRANT EXECUTE ON FUNCTION public.increment_session_duration(uuid, int)
  TO authenticated;
