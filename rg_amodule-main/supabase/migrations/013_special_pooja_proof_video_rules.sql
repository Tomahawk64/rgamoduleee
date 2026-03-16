-- =============================================================================
-- MIGRATION 013 - Special pooja proof video rules
-- =============================================================================
-- Enforces the product requirements:
-- 1) Only admins can upload proof videos.
-- 2) Proofs are allowed only for completed, paid, online special-pooja bookings.
-- 3) Proof visibility expires after 10 days.
-- 4) Proof video size limit is capped at 200 MB (bucket-level, when bucket exists).

-- Recreate SELECT policy with strict eligibility + 10-day visibility window.
DROP POLICY IF EXISTS "proofs_select" ON public.booking_proofs;
CREATE POLICY "proofs_select"
  ON public.booking_proofs FOR SELECT
  TO authenticated
  USING (
    booking_proofs.uploaded_at >= (now() - interval '10 days')
    AND EXISTS (
      SELECT 1
      FROM public.bookings b
      WHERE b.id = booking_proofs.booking_id
        AND b.special_pooja_id IS NOT NULL
        AND b.status = 'completed'
        AND b.is_paid = true
        AND COALESCE((b.location ->> 'is_online')::boolean, false) = true
    )
    AND (
      booking_proofs.pandit_id = auth.uid()
      OR public.get_my_role() = 'admin'
      OR EXISTS (
        SELECT 1
        FROM public.bookings b2
        WHERE b2.id = booking_proofs.booking_id
          AND b2.user_id = auth.uid()
      )
    )
  );

-- Replace legacy pandit-insert policy with admin-only insert policy.
DROP POLICY IF EXISTS "proofs_insert_pandit" ON public.booking_proofs;
DROP POLICY IF EXISTS "proofs_insert_admin_special_online" ON public.booking_proofs;
CREATE POLICY "proofs_insert_admin_special_online"
  ON public.booking_proofs FOR INSERT
  TO authenticated
  WITH CHECK (
    public.get_my_role() = 'admin'
    AND EXISTS (
      SELECT 1
      FROM public.bookings b
      WHERE b.id = booking_id
        AND b.special_pooja_id IS NOT NULL
        AND b.status = 'completed'
        AND b.is_paid = true
        AND COALESCE((b.location ->> 'is_online')::boolean, false) = true
    )
  );

-- Keep admin updates, but enforce the same booking eligibility rules.
DROP POLICY IF EXISTS "proofs_admin_update" ON public.booking_proofs;
CREATE POLICY "proofs_admin_update"
  ON public.booking_proofs FOR UPDATE
  TO authenticated
  USING (public.get_my_role() = 'admin')
  WITH CHECK (
    public.get_my_role() = 'admin'
    AND EXISTS (
      SELECT 1
      FROM public.bookings b
      WHERE b.id = booking_id
        AND b.special_pooja_id IS NOT NULL
        AND b.status = 'completed'
        AND b.is_paid = true
        AND COALESCE((b.location ->> 'is_online')::boolean, false) = true
    )
  );

-- Set pooja-proofs video size cap to 200 MB when the storage bucket exists.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_tables
    WHERE schemaname = 'storage'
      AND tablename = 'buckets'
  ) THEN
    UPDATE storage.buckets
    SET file_size_limit = 209715200
    WHERE id = 'pooja-proofs';
  END IF;
END;
$$;
