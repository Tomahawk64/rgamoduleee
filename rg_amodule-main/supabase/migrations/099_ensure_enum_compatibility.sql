-- Preflight for projects that already have an older booking_status enum.
-- New enum values must be committed before later migrations can use them.

do $$
begin
  create type public.booking_status as enum (
    'pending',
    'confirmed',
    'pandit_assigned',
    'in_progress',
    'processing',
    'completed',
    'cancelled',
    'expired'
  );
exception when duplicate_object then null;
end $$;

alter type public.booking_status add value if not exists 'pandit_assigned';
alter type public.booking_status add value if not exists 'in_progress';
alter type public.booking_status add value if not exists 'processing';
alter type public.booking_status add value if not exists 'expired';