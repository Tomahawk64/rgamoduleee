-- =============================================================================
-- MIGRATION 009 - Allow special-pooja bookings without package_id
-- =============================================================================
-- Special pooja bookings are stored in the shared `bookings` table using
-- `special_pooja_id`. Those rows do not belong to the regular `packages`
-- catalogue, so `package_id` must be nullable.

ALTER TABLE public.bookings
  ALTER COLUMN package_id DROP NOT NULL;

COMMENT ON COLUMN public.bookings.package_id IS
  'Nullable for special-pooja bookings; regular package bookings still reference public.packages(id).';
