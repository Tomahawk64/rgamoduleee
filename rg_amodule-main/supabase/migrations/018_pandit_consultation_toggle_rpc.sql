-- Migration 018: Pandit self-service consultation toggle
-- SECURITY DEFINER so it bypasses RLS and upsert always works,
-- even if a pandit_details row doesn't exist yet.

CREATE OR REPLACE FUNCTION public.pandit_set_consultation_enabled(p_enabled boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.pandit_details (id, consultation_enabled)
  VALUES (auth.uid(), p_enabled)
  ON CONFLICT (id) DO UPDATE
    SET consultation_enabled = p_enabled,
        updated_at           = now();
END;
$$;

GRANT EXECUTE ON FUNCTION public.pandit_set_consultation_enabled(boolean) TO authenticated;
