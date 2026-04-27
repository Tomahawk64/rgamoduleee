-- =============================================================================
-- MIGRATION 026 - Support tickets (user/pandit -> admin)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.support_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  requester_role text NOT NULL CHECK (requester_role IN ('user', 'pandit')),
  requester_name text,
  phone text NOT NULL CHECK (char_length(trim(phone)) BETWEEN 7 AND 20),
  problem text NOT NULL CHECK (char_length(trim(problem)) BETWEEN 10 AND 2000),
  status text NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted', 'processing', 'completed', 'rejected')),
  admin_note text,
  handled_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_support_tickets_requester
  ON public.support_tickets(requester_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status
  ON public.support_tickets(status, created_at DESC);

DROP TRIGGER IF EXISTS support_tickets_updated_at ON public.support_tickets;
CREATE TRIGGER support_tickets_updated_at
  BEFORE UPDATE ON public.support_tickets
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS support_tickets_select_own_or_admin ON public.support_tickets;
CREATE POLICY support_tickets_select_own_or_admin
  ON public.support_tickets FOR SELECT
  TO authenticated
  USING (
    requester_id = auth.uid() OR public.get_my_role() = 'admin'
  );

DROP POLICY IF EXISTS support_tickets_insert_own ON public.support_tickets;
CREATE POLICY support_tickets_insert_own
  ON public.support_tickets FOR INSERT
  TO authenticated
  WITH CHECK (
    requester_id = auth.uid()
    AND requester_role IN ('user', 'pandit')
    AND requester_role = public.get_my_role()
  );

DROP POLICY IF EXISTS support_tickets_update_admin ON public.support_tickets;
CREATE POLICY support_tickets_update_admin
  ON public.support_tickets FOR UPDATE
  TO authenticated
  USING (public.get_my_role() = 'admin')
  WITH CHECK (public.get_my_role() = 'admin');

CREATE OR REPLACE FUNCTION public.admin_update_support_ticket_status(
  p_ticket_id uuid,
  p_status text,
  p_admin_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
BEGIN
  IF v_admin_id IS NULL THEN
    RETURN jsonb_build_object('error', 'NOT_AUTHENTICATED');
  END IF;

  IF public.get_my_role() <> 'admin' THEN
    RETURN jsonb_build_object('error', 'ONLY_ADMIN');
  END IF;

  IF p_status NOT IN ('submitted', 'processing', 'completed', 'rejected') THEN
    RETURN jsonb_build_object('error', 'INVALID_STATUS');
  END IF;

  UPDATE public.support_tickets
  SET status = p_status,
      admin_note = CASE
        WHEN p_admin_note IS NULL THEN admin_note
        ELSE nullif(trim(p_admin_note), '')
      END,
      handled_by = v_admin_id,
      resolved_at = CASE
        WHEN p_status IN ('completed', 'rejected') THEN now()
        ELSE NULL
      END,
      updated_at = now()
  WHERE id = p_ticket_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'TICKET_NOT_FOUND');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_update_support_ticket_status(uuid, text, text)
  TO authenticated;
