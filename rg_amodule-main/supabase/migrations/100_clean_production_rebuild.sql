-- Saral Pooja clean production schema.
-- Apply after backing up legacy data. It is additive/idempotent and uses RLS for
-- user, pandit, and admin boundaries.

create extension if not exists pgcrypto;

create schema if not exists app_private;
revoke all on schema app_private from public, anon, authenticated;

do $$ begin create type public.app_role as enum ('user','pandit','admin'); exception when duplicate_object then null; end $$;
do $$ begin create type public.booking_type as enum ('offline_pandit','pooja_package','special_pooja','chat'); exception when duplicate_object then null; end $$;
do $$ begin create type public.booking_status as enum ('pending','confirmed','pandit_assigned','in_progress','processing','completed','cancelled','expired'); exception when duplicate_object then null; end $$;
do $$ begin create type public.payment_method as enum ('wallet','razorpay'); exception when duplicate_object then null; end $$;
do $$ begin create type public.ledger_type as enum ('credit','debit'); exception when duplicate_object then null; end $$;

create or replace function app_private.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

create or replace function app_private.is_pandit()
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role = 'pandit');
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text,
  phone text,
  role public.app_role not null default 'user',
  avatar_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  label text not null,
  line1 text not null,
  line2 text,
  city text not null,
  state text not null,
  pincode text not null,
  landmark text,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.pandits (
  id uuid primary key references public.profiles(id) on delete cascade,
  specialties text[] not null default '{}',
  languages text[] not null default '{}',
  bio text,
  experience_years int not null default 0,
  rating numeric(3,2) not null default 0,
  completed_bookings int not null default 0,
  chat_price_per_minute int not null default 20,
  is_online boolean not null default false,
  is_available_offline boolean not null default true,
  rough_location text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  sort_order int not null default 0,
  is_active boolean not null default true
);

create table if not exists public.pooja_packages (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references public.categories(id),
  title text not null,
  description text not null,
  included_items text[] not null default '{}',
  pandit_coverage text not null default 'One certified pandit',
  samigri_included boolean not null default true,
  duration_minutes int not null,
  price int not null check (price >= 0),
  image_url text,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.special_poojas (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  required_details text[] not null default '{}',
  duration_minutes int not null,
  price int not null check (price >= 0),
  image_url text,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.shop_items (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  included_items text[] not null default '{}',
  price int not null check (price >= 0),
  stock int not null default 0,
  image_url text,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.wallets (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  balance int not null default 0 check (balance >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  ledger_type public.ledger_type not null,
  amount int not null check (amount > 0),
  balance_after int not null check (balance_after >= 0),
  reason text not null,
  reference_id text,
  created_at timestamptz not null default now()
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  amount int not null check (amount > 0),
  method public.payment_method not null,
  status text not null,
  razorpay_order_id text,
  razorpay_payment_id text,
  razorpay_signature text,
  reference_type text,
  reference_id uuid,
  raw_payload jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.payment_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  order_id uuid,
  transaction_type text not null,
  razorpay_order_id text,
  amount_paise int not null check (amount_paise > 0),
  payment_status text not null,
  razorpay_response jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  pandit_id uuid references public.profiles(id) on delete set null,
  booking_type public.booking_type not null,
  catalogue_id uuid,
  title text not null,
  amount int not null check (amount >= 0),
  status public.booking_status not null default 'pending',
  scheduled_at timestamptz not null,
  address_id uuid references public.addresses(id),
  address_snapshot jsonb,
  rough_address text,
  payment_id uuid references public.payments(id),
  user_notes text,
  pandit_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.booking_status_history (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  status public.booking_status not null,
  changed_by uuid references public.profiles(id),
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.chat_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  pandit_id uuid not null references public.profiles(id) on delete restrict,
  booking_id uuid references public.bookings(id) on delete set null,
  started_at timestamptz not null default now(),
  ends_at timestamptz not null,
  status public.booking_status not null default 'in_progress',
  price int not null,
  created_at timestamptz not null default now()
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.chat_sessions(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete restrict,
  body text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.chat_attachments (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.chat_messages(id) on delete cascade,
  storage_key text not null,
  signed_url text,
  content_type text not null,
  size_bytes int not null,
  created_at timestamptz not null default now()
);

create table if not exists public.carts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  updated_at timestamptz not null default now()
);

create table if not exists public.cart_items (
  id uuid primary key default gen_random_uuid(),
  cart_id uuid not null references public.carts(id) on delete cascade,
  item_id uuid not null references public.shop_items(id) on delete restrict,
  quantity int not null check (quantity > 0),
  unique(cart_id, item_id)
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  total int not null,
  status text not null default 'confirmed',
  payment_id uuid references public.payments(id),
  shipping_address jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  item_id uuid references public.shop_items(id),
  title text not null,
  unit_price int not null,
  quantity int not null
);

create table if not exists public.proof_videos (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete restrict,
  uploaded_by uuid not null references public.profiles(id) on delete restrict,
  storage_key text not null,
  signed_url text,
  size_bytes int not null check (size_bytes <= 314572800),
  uploaded_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '7 days')
);

alter table public.bookings add column if not exists booking_type public.booking_type;
alter table public.bookings add column if not exists catalogue_id uuid;
alter table public.bookings add column if not exists title text;
alter table public.bookings add column if not exists scheduled_at timestamptz;
alter table public.bookings add column if not exists address_id uuid references public.addresses(id);
alter table public.bookings add column if not exists address_snapshot jsonb;
alter table public.bookings add column if not exists rough_address text;
alter table public.bookings add column if not exists user_notes text;
alter table public.bookings add column if not exists pandit_notes text;

update public.bookings
set booking_type = coalesce(booking_type, case when special_pooja_id is not null then 'special_pooja'::public.booking_type else 'pooja_package'::public.booking_type end),
    title = coalesce(title, nullif(package_title, ''), nullif(category, ''), 'Pooja booking'),
    scheduled_at = coalesce(scheduled_at, booking_date::timestamptz, created_at, now()),
    rough_address = coalesce(rough_address, location->>'city', location->>'addressLine1', location->>'address_line1'),
    user_notes = coalesce(user_notes, notes)
where booking_type is null
   or title is null
   or scheduled_at is null
   or rough_address is null
   or user_notes is null;

alter table public.bookings alter column booking_type set default 'pooja_package';
alter table public.bookings alter column scheduled_at set default now();
alter table public.bookings alter column title set default 'Pooja booking';
alter table public.bookings alter column amount type int using round(amount)::int;
drop policy if exists bookings_insert_own on public.bookings;
drop policy if exists bookings_select_admin on public.bookings;
drop policy if exists bookings_select_own_pandit on public.bookings;
drop policy if exists bookings_select_own_user on public.bookings;
drop policy if exists bookings_update_admin on public.bookings;
drop policy if exists bookings_update_pandit on public.bookings;
drop policy if exists bookings_update_user on public.bookings;
drop policy if exists proofs_admin_update on public.booking_proofs;
drop policy if exists proofs_insert_admin_special_online on public.booking_proofs;
drop policy if exists proofs_select on public.booking_proofs;
drop policy if exists "Pandits can view their bookings" on public.offline_bookings;
alter table public.bookings drop constraint if exists bookings_status_check;
update public.bookings set status = 'pandit_assigned' where status::text = 'assigned';
alter table public.bookings alter column status set default 'pending';

alter table public.orders add column if not exists total int;
alter table public.orders add column if not exists shipping_address jsonb;
update public.orders set total = coalesce(total, round(total_paise / 100.0)::int, 0) where total is null;
alter table public.orders alter column total set default 0;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  data jsonb not null default '{}',
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.support_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  subject text not null,
  message text not null,
  status text not null default 'open',
  created_at timestamptz not null default now()
);

create index if not exists idx_bookings_user on public.bookings(user_id);
create index if not exists idx_bookings_pandit on public.bookings(pandit_id);
create index if not exists idx_bookings_status on public.bookings(status);
create index if not exists idx_payment_logs_user on public.payment_logs(user_id, created_at desc);
create index if not exists idx_chat_sessions_participants on public.chat_sessions(user_id, pandit_id);
create index if not exists idx_chat_messages_session_time on public.chat_messages(session_id, created_at);
create index if not exists idx_proof_videos_user_expiry on public.proof_videos(user_id, expires_at);

create or replace function public.wallet_apply(
  p_user_id uuid,
  p_type public.ledger_type,
  p_amount int,
  p_reason text,
  p_reference_id text default null
) returns int language plpgsql security definer set search_path = public as $$
declare
  v_balance int;
begin
  if p_user_id <> auth.uid() and not app_private.is_admin() then
    raise exception 'wallet_access_denied';
  end if;
  if p_type = 'credit' and not app_private.is_admin() then
    raise exception 'wallet_credit_denied';
  end if;

  insert into public.wallets(user_id, balance) values (p_user_id, 0)
  on conflict (user_id) do nothing;

  select balance into v_balance from public.wallets where user_id = p_user_id for update;
  if p_type = 'debit' and v_balance < p_amount then
    raise exception 'insufficient_wallet_balance';
  end if;

  v_balance := case when p_type = 'credit' then v_balance + p_amount else v_balance - p_amount end;
  update public.wallets set balance = v_balance, updated_at = now() where user_id = p_user_id;
  insert into public.wallet_ledger(user_id, ledger_type, amount, balance_after, reason, reference_id)
  values (p_user_id, p_type, p_amount, v_balance, p_reason, p_reference_id);
  return v_balance;
end;
$$;

create or replace function public.credit_paid_wallet_topup(
  p_payment_id uuid
) returns int language plpgsql security definer set search_path = public as $$
declare
  v_payment public.payments%rowtype;
  v_balance int;
begin
  select * into v_payment
  from public.payments
  where id = p_payment_id
    and user_id = auth.uid()
    and method = 'razorpay'
    and status = 'captured'
    and reference_type = 'wallet_topup';

  if not found then
    raise exception 'captured_wallet_topup_not_found';
  end if;

  if exists(
    select 1 from public.wallet_ledger
    where user_id = v_payment.user_id
      and ledger_type = 'credit'
      and reference_id = p_payment_id::text
  ) then
    select balance into v_balance from public.wallets where user_id = v_payment.user_id;
    return coalesce(v_balance, 0);
  end if;

  insert into public.wallets(user_id, balance) values (v_payment.user_id, 0)
  on conflict (user_id) do nothing;

  select balance into v_balance from public.wallets where user_id = v_payment.user_id for update;
  v_balance := v_balance + v_payment.amount;
  update public.wallets set balance = v_balance, updated_at = now() where user_id = v_payment.user_id;
  insert into public.wallet_ledger(user_id, ledger_type, amount, balance_after, reason, reference_id)
  values (v_payment.user_id, 'credit', v_payment.amount, v_balance, 'Wallet top-up', p_payment_id::text);
  return v_balance;
end;
$$;

create or replace function public.expire_old_chat_sessions()
returns void language sql security definer set search_path = public as $$
  update public.chat_sessions set status = 'expired'
  where status = 'in_progress' and ends_at <= now();
$$;

create or replace view public.pandit_booking_assignments
with (security_invoker = true) as
select
  id,
  pandit_id,
  booking_type,
  title,
  status,
  scheduled_at,
  rough_address,
  pandit_notes,
  created_at
from public.bookings
where pandit_id = auth.uid() or app_private.is_admin();

create or replace function public.complete_assigned_booking(
  p_booking_id uuid,
  p_status public.booking_status,
  p_note text default ''
)
returns table (
  id uuid,
  pandit_id uuid,
  booking_type public.booking_type,
  title text,
  status text,
  scheduled_at timestamptz,
  rough_address text,
  pandit_notes text,
  created_at timestamptz
)
language plpgsql
security invoker
set search_path = public
as $$
begin
  if p_status not in ('in_progress', 'completed') then
    raise exception 'Pandits can only start or complete assigned bookings.';
  end if;

  update public.bookings b
  set status = p_status,
      pandit_notes = nullif(p_note, ''),
      updated_at = now()
  where b.id = p_booking_id and b.pandit_id = auth.uid();

  if not found then
    raise exception 'Assigned booking not found.';
  end if;

  insert into public.booking_status_history(booking_id, status, changed_by, note)
  values (p_booking_id, p_status, auth.uid(), p_note);

  return query
  select
    b.id,
    b.pandit_id,
    b.booking_type,
    b.title,
    b.status::text,
    b.scheduled_at,
    b.rough_address,
    b.pandit_notes,
    b.created_at
  from public.bookings b
  where b.id = p_booking_id and b.pandit_id = auth.uid();
end;
$$;

alter table public.profiles enable row level security;
alter table public.addresses enable row level security;
alter table public.pandits enable row level security;
alter table public.categories enable row level security;
alter table public.pooja_packages enable row level security;
alter table public.special_poojas enable row level security;
alter table public.shop_items enable row level security;
alter table public.wallets enable row level security;
alter table public.wallet_ledger enable row level security;
alter table public.payments enable row level security;
alter table public.payment_logs enable row level security;
alter table public.bookings enable row level security;
alter table public.booking_status_history enable row level security;
alter table public.chat_sessions enable row level security;
alter table public.chat_messages enable row level security;
alter table public.chat_attachments enable row level security;
alter table public.carts enable row level security;
alter table public.cart_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.proof_videos enable row level security;
alter table public.notifications enable row level security;
alter table public.support_logs enable row level security;

drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select using (
  id = auth.uid()
  or app_private.is_admin()
  or exists(select 1 from public.pandits p where p.id = profiles.id)
);
drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_insert_self on public.profiles for insert with check (id = auth.uid() and role = 'user');
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles for update using (id = auth.uid() or app_private.is_admin()) with check (id = auth.uid() or app_private.is_admin());

drop policy if exists addresses_owner_admin on public.addresses;
create policy addresses_owner_admin on public.addresses for all using (user_id = auth.uid() or app_private.is_admin()) with check (user_id = auth.uid() or app_private.is_admin());

drop policy if exists public_catalog_read_packages on public.pooja_packages;
create policy public_catalog_read_packages on public.pooja_packages for select using (is_active or app_private.is_admin());
drop policy if exists admin_catalog_packages on public.pooja_packages;
create policy admin_catalog_packages on public.pooja_packages for all using (app_private.is_admin()) with check (app_private.is_admin());
drop policy if exists public_catalog_read_special on public.special_poojas;
create policy public_catalog_read_special on public.special_poojas for select using (is_active or app_private.is_admin());
drop policy if exists admin_catalog_special on public.special_poojas;
create policy admin_catalog_special on public.special_poojas for all using (app_private.is_admin()) with check (app_private.is_admin());
drop policy if exists public_catalog_read_shop on public.shop_items;
create policy public_catalog_read_shop on public.shop_items for select using (is_active or app_private.is_admin());
drop policy if exists admin_catalog_shop on public.shop_items;
create policy admin_catalog_shop on public.shop_items for all using (app_private.is_admin()) with check (app_private.is_admin());

drop policy if exists pandits_public_admin on public.pandits;
create policy pandits_public_admin on public.pandits for select using (true);
drop policy if exists pandits_admin_write on public.pandits;
create policy pandits_admin_write on public.pandits for all using (app_private.is_admin()) with check (app_private.is_admin());

drop policy if exists wallet_owner_admin on public.wallets;
create policy wallet_owner_admin on public.wallets for select using (user_id = auth.uid() or app_private.is_admin());
drop policy if exists ledger_owner_admin on public.wallet_ledger;
create policy ledger_owner_admin on public.wallet_ledger for select using (user_id = auth.uid() or app_private.is_admin());

drop policy if exists payments_owner_admin on public.payments;
create policy payments_owner_admin on public.payments for select using (user_id = auth.uid() or app_private.is_admin());
drop policy if exists payments_user_insert on public.payments;
create policy payments_user_insert on public.payments for insert with check (user_id = auth.uid());
drop policy if exists payment_logs_admin_read on public.payment_logs;
create policy payment_logs_admin_read on public.payment_logs for select using (app_private.is_admin());

drop policy if exists bookings_visibility on public.bookings;
create policy bookings_visibility on public.bookings for select using (user_id = auth.uid() or app_private.is_admin());
drop policy if exists bookings_user_insert on public.bookings;
create policy bookings_user_insert on public.bookings for insert with check (user_id = auth.uid());
drop policy if exists bookings_admin_update on public.bookings;
create policy bookings_admin_update on public.bookings for update using (app_private.is_admin()) with check (app_private.is_admin());
drop policy if exists bookings_pandit_update_assigned on public.bookings;
create policy bookings_pandit_update_assigned on public.bookings for update using (
  pandit_id = auth.uid()
) with check (
  pandit_id = auth.uid()
  and status in ('in_progress', 'completed')
);

drop policy if exists booking_status_history_visibility on public.booking_status_history;
create policy booking_status_history_visibility on public.booking_status_history for select using (
  exists(select 1 from public.bookings b where b.id = booking_id and (b.user_id = auth.uid() or b.pandit_id = auth.uid()))
  or app_private.is_admin()
);
drop policy if exists booking_status_history_insert on public.booking_status_history;
create policy booking_status_history_insert on public.booking_status_history for insert with check (
  changed_by = auth.uid()
  and (
    exists(select 1 from public.bookings b where b.id = booking_id and (b.user_id = auth.uid() or b.pandit_id = auth.uid()))
    or app_private.is_admin()
  )
);

drop policy if exists chat_session_participants on public.chat_sessions;
create policy chat_session_participants on public.chat_sessions for select using (user_id = auth.uid() or pandit_id = auth.uid() or app_private.is_admin());
drop policy if exists chat_session_user_insert on public.chat_sessions;
create policy chat_session_user_insert on public.chat_sessions for insert with check (user_id = auth.uid());
drop policy if exists chat_messages_participants on public.chat_messages;
create policy chat_messages_participants on public.chat_messages for select using (
  exists(select 1 from public.chat_sessions s where s.id = session_id and (s.user_id = auth.uid() or s.pandit_id = auth.uid()))
  or app_private.is_admin()
);
drop policy if exists chat_messages_insert_participants on public.chat_messages;
create policy chat_messages_insert_participants on public.chat_messages for insert with check (
  sender_id = auth.uid()
  and exists(select 1 from public.chat_sessions s where s.id = session_id and (s.user_id = auth.uid() or s.pandit_id = auth.uid()) and s.ends_at > now())
);
drop policy if exists chat_attachments_participants on public.chat_attachments;
create policy chat_attachments_participants on public.chat_attachments for select using (
  exists(
    select 1 from public.chat_messages m
    join public.chat_sessions s on s.id = m.session_id
    where m.id = message_id and (s.user_id = auth.uid() or s.pandit_id = auth.uid())
  )
  or app_private.is_admin()
);
drop policy if exists chat_attachments_insert_sender on public.chat_attachments;
create policy chat_attachments_insert_sender on public.chat_attachments for insert with check (
  exists(
    select 1 from public.chat_messages m
    join public.chat_sessions s on s.id = m.session_id
    where m.id = message_id and m.sender_id = auth.uid() and (s.user_id = auth.uid() or s.pandit_id = auth.uid())
  )
);

drop policy if exists cart_owner on public.carts;
create policy cart_owner on public.carts for all using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists cart_items_owner on public.cart_items;
create policy cart_items_owner on public.cart_items for all using (exists(select 1 from public.carts c where c.id = cart_id and c.user_id = auth.uid()));

drop policy if exists orders_owner_admin on public.orders;
create policy orders_owner_admin on public.orders for select using (user_id = auth.uid() or app_private.is_admin());
drop policy if exists orders_user_insert on public.orders;
create policy orders_user_insert on public.orders for insert with check (user_id = auth.uid());
drop policy if exists order_items_owner_admin on public.order_items;
create policy order_items_owner_admin on public.order_items for select using (exists(select 1 from public.orders o where o.id = order_id and (o.user_id = auth.uid() or app_private.is_admin())));
drop policy if exists order_items_user_insert on public.order_items;
create policy order_items_user_insert on public.order_items for insert with check (exists(select 1 from public.orders o where o.id = order_id and o.user_id = auth.uid()));
drop policy if exists proof_owner_admin on public.proof_videos;
create policy proof_owner_admin on public.proof_videos for select using ((user_id = auth.uid() and expires_at > now()) or app_private.is_admin());
drop policy if exists proof_admin_write on public.proof_videos;
create policy proof_admin_write on public.proof_videos for all using (app_private.is_admin()) with check (app_private.is_admin());

drop policy if exists notifications_owner_admin on public.notifications;
create policy notifications_owner_admin on public.notifications for all using (user_id = auth.uid() or app_private.is_admin()) with check (user_id = auth.uid() or app_private.is_admin());
drop policy if exists support_owner_admin on public.support_logs;
create policy support_owner_admin on public.support_logs for all using (user_id = auth.uid() or app_private.is_admin()) with check (user_id = auth.uid() or app_private.is_admin());

revoke all on all tables in schema public from anon, authenticated;
revoke all on all functions in schema public from anon, authenticated;
grant usage on schema public to anon, authenticated;
grant select on public.categories, public.pooja_packages, public.special_poojas, public.shop_items, public.pandits to authenticated;
grant select, insert, update on public.profiles, public.addresses, public.carts, public.cart_items, public.notifications, public.support_logs to authenticated;
grant select on public.wallets, public.wallet_ledger, public.payment_logs to authenticated;
grant select, insert on public.payments, public.bookings, public.booking_status_history, public.chat_sessions, public.chat_messages, public.chat_attachments, public.orders, public.order_items to authenticated;
grant select, insert, update on public.proof_videos to authenticated;
grant select on public.pandit_booking_assignments to authenticated;
grant execute on function public.wallet_apply(uuid, public.ledger_type, int, text, text) to authenticated;
grant execute on function public.credit_paid_wallet_topup(uuid) to authenticated;
grant execute on function public.complete_assigned_booking(uuid, public.booking_status, text) to authenticated;
grant execute on function public.expire_old_chat_sessions() to service_role;
