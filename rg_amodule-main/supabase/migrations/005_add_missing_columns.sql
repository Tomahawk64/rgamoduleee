-- =============================================================================
-- MIGRATION 005 — Add missing columns for production features
-- Safe to re-run (all ADD COLUMN IF NOT EXISTS)
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- BOOKINGS: pandit_accepted + pandit_name
-- Required by SupabasePanditDashboardRepository for pandit assignment flow.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS pandit_accepted boolean NOT NULL DEFAULT false;

-- pandit_name is a denormalized copy written at assignment time (optional)
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS pandit_name text;

-- ─────────────────────────────────────────────────────────────────────────────
-- ORDERS: payment_method inside shipping_addr (jsonb) — no schema change needed.
-- The orders table from migration 001 already supports the required insert.
-- ─────────────────────────────────────────────────────────────────────────────

-- Ensure orders table exists (idempotent re-statement)
CREATE TABLE IF NOT EXISTS public.orders (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  items          jsonb NOT NULL,
  subtotal_paise int NOT NULL,
  tax_paise      int NOT NULL DEFAULT 0,
  total_paise    int NOT NULL,
  status         text NOT NULL DEFAULT 'pending',
  shipping_addr  jsonb,
  payment_id     text,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

-- RLS (idempotent)
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "orders_own_select"    ON public.orders;
DROP POLICY IF EXISTS "orders_insert_own"    ON public.orders;
DROP POLICY IF EXISTS "orders_update_admin"  ON public.orders;

CREATE POLICY "orders_own_select" ON public.orders
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.get_my_role() = 'admin');

CREATE POLICY "orders_insert_own" ON public.orders
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "orders_update_admin" ON public.orders
  FOR UPDATE TO authenticated
  USING (public.get_my_role() = 'admin');

-- ─────────────────────────────────────────────────────────────────────────────
-- PANDIT_DETAILS: updated_at trigger (may not exist in older deployments)
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.pandit_details
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

DROP TRIGGER IF EXISTS pandit_details_updated_at2 ON public.pandit_details;
CREATE TRIGGER pandit_details_updated_at2
  BEFORE UPDATE ON public.pandit_details
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
