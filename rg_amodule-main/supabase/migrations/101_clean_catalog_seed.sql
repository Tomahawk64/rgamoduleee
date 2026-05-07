-- Initial production catalogue so the app has useful content immediately after
-- the clean schema is applied. Admins can edit/delete/reorder these records.

alter table public.special_poojas add column if not exists required_details text[] not null default '{}';
alter table public.special_poojas add column if not exists sort_order int not null default 0;
alter table public.special_poojas alter column price type int using round(price)::int;

insert into public.categories (id, name, sort_order, is_active) values
  ('11111111-1111-4111-8111-111111111111', 'Home Poojas', 1, true),
  ('22222222-2222-4222-8222-222222222222', 'Festival Poojas', 2, true)
on conflict (name) do update set
  sort_order = excluded.sort_order,
  is_active = excluded.is_active;

insert into public.pooja_packages (
  id, category_id, title, description, included_items, pandit_coverage,
  samigri_included, duration_minutes, price, image_url, sort_order, is_active
) values
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    '11111111-1111-4111-8111-111111111111',
    'Griha Pravesh Pooja',
    'Complete house warming ceremony with sankalp, Ganesh pujan, navgraha shanti, and havan.',
    array['Ganesh pujan','Kalash sthapana','Navgraha shanti','Havan samigri'],
    'One certified pandit',
    true,
    150,
    5100,
    'assets/images/image1.jpg',
    1,
    true
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
    '22222222-2222-4222-8222-222222222222',
    'Satyanarayan Katha',
    'Traditional katha and aarti for family prosperity, gratitude, and auspicious beginnings.',
    array['Katha path','Panchamrit','Aarti','Basic samigri'],
    'One certified pandit',
    true,
    120,
    3100,
    'assets/images/image2.jpg',
    2,
    true
  )
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  included_items = excluded.included_items,
  price = excluded.price,
  image_url = excluded.image_url,
  is_active = excluded.is_active;

insert into public.special_poojas (
  id, title, description, required_details, duration_minutes, price, image_url,
  sort_order, is_active
) values
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
    'Mahamrityunjaya Jaap',
    'Online special pooja performed by allotted pandits with downloadable proof video after completion.',
    array['Name','Gotra','Sankalp','Preferred date'],
    240,
    11000,
    'assets/images/image10.jpg',
    1,
    true
  )
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  required_details = excluded.required_details,
  price = excluded.price,
  image_url = excluded.image_url,
  is_active = excluded.is_active;

insert into public.shop_items (
  id, title, description, included_items, price, stock, image_url, sort_order,
  is_active
) values
  (
    'cccccccc-cccc-4ccc-8ccc-ccccccccccc1',
    'Grah Pravesh Samigri Kit',
    'Curated samigri kit for house warming rituals.',
    array['Havan sticks','Ghee diya','Kalawa','Roli chawal'],
    1499,
    24,
    'assets/images/image11.jpg',
    1,
    true
  ),
  (
    'cccccccc-cccc-4ccc-8ccc-ccccccccccc2',
    'Festival Pooja Thali',
    'Premium pooja thali set for daily and festival worship.',
    array['Brass thali','Diya','Bell','Incense holder'],
    899,
    40,
    'assets/images/image12.jpg',
    2,
    true
  )
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  included_items = excluded.included_items,
  price = excluded.price,
  stock = excluded.stock,
  image_url = excluded.image_url,
  is_active = excluded.is_active;
