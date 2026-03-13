-- =============================================================================
-- SEED: Full Client Demo Data
-- Run this in: Supabase Dashboard → SQL Editor  (runs as postgres superuser)
--
-- ⚠  IDEMPOTENT — safe to re-run. Uses ON CONFLICT DO UPDATE throughout.
--
-- Creates:
--   1. demo_user@divinepooja.com   (role = user)
--   2. demo_pandit@divinepooja.com (role = pandit, with pandit_details + rates)
--   3. demo_admin@divinepooja.com  (role = admin)
--   4. 5 Pooja Packages (featured + popular)
--   5. 3 Special Poojas
--   6. 5 Shop Products
--   7. 3 Bookings (confirmed, completed, assigned)
--   8. 1 Booking Proof (for completed booking)
--   9. 2 Consultations (completed + expired)
--  10. 2 Shop Orders (delivered + confirmed)
--  11. 1 User Address
--  12. Consultation messages for the completed session
--  13. Package reviews
--
-- After running, use these credentials in the app:
--   demo_user@divinepooja.com   / Demo@123
--   demo_pandit@divinepooja.com / Demo@123
--   demo_admin@divinepooja.com  / Demo@123
--
-- ⚠  Run on staging/dev project only — NOT production.
-- =============================================================================

DO $$
DECLARE
  -- ── Fixed UUIDs for demo accounts ──────────────────────────────────────────
  v_user_id    CONSTANT uuid := '11111111-1111-4111-8111-111111111111';
  v_pandit_id  CONSTANT uuid := '22222222-2222-4222-8222-222222222222';
  v_admin_id   CONSTANT uuid := '33333333-3333-4333-8333-333333333333';

  -- ── Fixed UUIDs for packages ───────────────────────────────────────────────
  v_pkg_satya  CONSTANT uuid := 'aaaa0001-0001-4001-8001-000000000001';
  v_pkg_grih   CONSTANT uuid := 'aaaa0002-0002-4002-8002-000000000002';
  v_pkg_rudra  CONSTANT uuid := 'aaaa0003-0003-4003-8003-000000000003';
  v_pkg_sundkd CONSTANT uuid := 'aaaa0004-0004-4004-8004-000000000004';
  v_pkg_ganesh CONSTANT uuid := 'aaaa0005-0005-4005-8005-000000000005';

  -- ── Fixed UUIDs for special poojas ─────────────────────────────────────────
  v_sp_kamakhya  CONSTANT uuid := 'bbbb0001-0001-4001-8001-000000000001';
  v_sp_mahamrit  CONSTANT uuid := 'bbbb0002-0002-4002-8002-000000000002';
  v_sp_kalsarpa  CONSTANT uuid := 'bbbb0003-0003-4003-8003-000000000003';

  -- ── Fixed UUIDs for products ───────────────────────────────────────────────
  v_prod_satya   CONSTANT uuid := 'cccc0001-0001-4001-8001-000000000001';
  v_prod_grih    CONSTANT uuid := 'cccc0002-0002-4002-8002-000000000002';
  v_prod_navgraha CONSTANT uuid := 'cccc0003-0003-4003-8003-000000000003';
  v_prod_tulsi   CONSTANT uuid := 'cccc0004-0004-4004-8004-000000000004';
  v_prod_rudra   CONSTANT uuid := 'cccc0005-0005-4005-8005-000000000005';

  -- ── Fixed UUIDs for bookings ───────────────────────────────────────────────
  v_bk_confirmed CONSTANT uuid := 'dddd0001-0001-4001-8001-000000000001';
  v_bk_completed CONSTANT uuid := 'dddd0002-0002-4002-8002-000000000002';
  v_bk_assigned  CONSTANT uuid := 'dddd0003-0003-4003-8003-000000000003';

  -- ── Fixed UUIDs for consultations ──────────────────────────────────────────
  v_consult_done   CONSTANT uuid := 'eeee0001-0001-4001-8001-000000000001';
  v_consult_ended  CONSTANT uuid := 'eeee0002-0002-4002-8002-000000000002';

  -- ── Fixed UUIDs for orders ─────────────────────────────────────────────────
  v_order_done    CONSTANT uuid := 'ffff0001-0001-4001-8001-000000000001';
  v_order_pending CONSTANT uuid := 'ffff0002-0002-4002-8002-000000000002';

  -- ── Fixed UUID for address ─────────────────────────────────────────────────
  v_address_id CONSTANT uuid := 'aaff0001-0001-4001-8001-000000000001';

  -- ── Fixed UUID for booking proof ───────────────────────────────────────────
  v_proof_id CONSTANT uuid := 'aabb0001-0001-4001-8001-000000000001';

BEGIN

  -- ══════════════════════════════════════════════════════════════════════════
  -- 1. DEMO USER
  -- ══════════════════════════════════════════════════════════════════════════
  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at, confirmation_token, recovery_token
  ) VALUES (
    v_user_id,
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'demo_user@divinepooja.com',
    crypt('Demo@123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"Rajesh Kumar","role":"user"}'::jsonb,
    now() - interval '30 days', now(), '', ''
  )
  ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        encrypted_password = EXCLUDED.encrypted_password,
        raw_user_meta_data = EXCLUDED.raw_user_meta_data,
        email_confirmed_at = EXCLUDED.email_confirmed_at;

  INSERT INTO auth.identities (
    id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  ) VALUES (
    v_user_id, v_user_id, v_user_id::text,
    jsonb_build_object('sub', v_user_id::text, 'email', 'demo_user@divinepooja.com'),
    'email', now(), now() - interval '30 days', now()
  )
  ON CONFLICT (provider, provider_id) DO NOTHING;

  INSERT INTO public.profiles (id, full_name, phone, role, is_active, rating)
  VALUES (v_user_id, 'Rajesh Kumar', '+919876543210', 'user', true, 0.0)
  ON CONFLICT (id) DO UPDATE
    SET full_name = EXCLUDED.full_name, phone = EXCLUDED.phone,
        role = 'user', is_active = true;

  -- ══════════════════════════════════════════════════════════════════════════
  -- 2. DEMO PANDIT
  -- ══════════════════════════════════════════════════════════════════════════
  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at, confirmation_token, recovery_token
  ) VALUES (
    v_pandit_id,
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'demo_pandit@divinepooja.com',
    crypt('Demo@123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"Pandit Shivendra Shastri","role":"pandit"}'::jsonb,
    now() - interval '60 days', now(), '', ''
  )
  ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        encrypted_password = EXCLUDED.encrypted_password,
        raw_user_meta_data = EXCLUDED.raw_user_meta_data,
        email_confirmed_at = EXCLUDED.email_confirmed_at;

  INSERT INTO auth.identities (
    id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  ) VALUES (
    v_pandit_id, v_pandit_id, v_pandit_id::text,
    jsonb_build_object('sub', v_pandit_id::text, 'email', 'demo_pandit@divinepooja.com'),
    'email', now(), now() - interval '60 days', now()
  )
  ON CONFLICT (provider, provider_id) DO NOTHING;

  INSERT INTO public.profiles (id, full_name, phone, role, is_active, rating)
  VALUES (v_pandit_id, 'Pandit Shivendra Shastri', '+919988776655', 'pandit', true, 4.8)
  ON CONFLICT (id) DO UPDATE
    SET full_name = EXCLUDED.full_name, phone = EXCLUDED.phone,
        role = 'pandit', is_active = true, rating = 4.8;

  INSERT INTO public.pandit_details (
    id, specialties, languages, experience_years, bio,
    is_online, consultation_enabled, location
  ) VALUES (
    v_pandit_id,
    ARRAY['Vedic Rituals', 'Astrology', 'Vastu', 'Navagraha Shanti'],
    ARRAY['Hindi', 'Sanskrit', 'English'],
    15,
    'Senior Vedic scholar from Varanasi with 15+ years of experience in performing rituals, astrology consultations, and Vastu guidance. Specializes in Satyanarayan Katha, Grih Pravesh, and Navagraha Shanti.',
    true, true, 'Varanasi, Uttar Pradesh'
  )
  ON CONFLICT (id) DO UPDATE
    SET specialties = EXCLUDED.specialties, languages = EXCLUDED.languages,
        experience_years = EXCLUDED.experience_years, bio = EXCLUDED.bio,
        is_online = true, consultation_enabled = true, location = EXCLUDED.location;

  INSERT INTO public.consultation_rates (pandit_id, duration_minutes, price, is_active)
  VALUES
    (v_pandit_id, 10,  99.00, true),
    (v_pandit_id, 15, 149.00, true),
    (v_pandit_id, 30, 249.00, true),
    (v_pandit_id, 60, 449.00, true)
  ON CONFLICT (pandit_id, duration_minutes) DO UPDATE
    SET price = EXCLUDED.price, is_active = true;

  -- ══════════════════════════════════════════════════════════════════════════
  -- 3. DEMO ADMIN
  -- ══════════════════════════════════════════════════════════════════════════
  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at, confirmation_token, recovery_token
  ) VALUES (
    v_admin_id,
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'demo_admin@divinepooja.com',
    crypt('Demo@123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"Admin DivinePooja","role":"admin"}'::jsonb,
    now() - interval '90 days', now(), '', ''
  )
  ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        encrypted_password = EXCLUDED.encrypted_password,
        raw_user_meta_data = EXCLUDED.raw_user_meta_data,
        email_confirmed_at = EXCLUDED.email_confirmed_at;

  INSERT INTO auth.identities (
    id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  ) VALUES (
    v_admin_id, v_admin_id, v_admin_id::text,
    jsonb_build_object('sub', v_admin_id::text, 'email', 'demo_admin@divinepooja.com'),
    'email', now(), now() - interval '90 days', now()
  )
  ON CONFLICT (provider, provider_id) DO NOTHING;

  INSERT INTO public.profiles (id, full_name, phone, role, is_active, rating)
  VALUES (v_admin_id, 'Admin DivinePooja', '+919111222333', 'admin', true, 0.0)
  ON CONFLICT (id) DO UPDATE
    SET full_name = EXCLUDED.full_name, phone = EXCLUDED.phone,
        role = 'admin', is_active = true;

  -- ══════════════════════════════════════════════════════════════════════════
  -- 4. POOJA PACKAGES (5)
  -- ══════════════════════════════════════════════════════════════════════════
  INSERT INTO public.packages (
    id, title, description, price, discount_price, duration_minutes,
    is_online, is_offline, category, includes, image_url,
    is_active, is_featured, is_popular, booking_count, rating, review_count
  ) VALUES
  (
    v_pkg_satya, 'Satyanarayan Katha',
    'Complete Satyanarayan Puja performed by experienced Vedic pandits. Includes all 5 chapters of the Katha with proper rituals, mantras, and prasad distribution.',
    2499.00, 1999.00, 120, true, true, 'puja',
    ARRAY['Experienced Pandit','Complete Samagri Kit','Online Streaming','Prasad Distribution','Personalised Sankalp'],
    'https://images.unsplash.com/photo-1604608672516-f1b9b1d37076?w=600',
    true, true, true, 156, 4.80, 42
  ),
  (
    v_pkg_grih, 'Grih Pravesh Pooja',
    'Traditional Grih Pravesh ceremony with Vastu Shanti, Ganesh Puja, Navagraha Puja, and Havan. Brings positive energy and blessings to your new home.',
    3999.00, 3499.00, 180, false, true, 'puja',
    ARRAY['Senior Pandit','Full Samagri','Vastu Shanti','Navagraha Puja','Ganesh Puja','Havan'],
    'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=600',
    true, true, true, 89, 4.90, 28
  ),
  (
    v_pkg_rudra, 'Rudrabhishek',
    'Sacred Rudrabhishek performed with Vedic mantras for Lord Shiva. Includes Abhishek with milk, honey, curd, ghee, and holy water.',
    1999.00, 1499.00, 90, true, true, 'puja',
    ARRAY['Vedic Pandit','Abhishek Samagri','Online Streaming','Bilva Patra','Rudri Path'],
    'https://images.unsplash.com/photo-1609710228159-0fa9bd7c0827?w=600',
    true, true, false, 234, 4.70, 67
  ),
  (
    v_pkg_sundkd, 'Sunderkand Path',
    'Complete recitation of Sunderkand from Ramcharitmanas. Invokes blessings of Lord Hanuman for courage, strength, and protection.',
    999.00, 799.00, 60, true, true, 'path',
    ARRAY['Pandit Ji','Online Streaming','Hanuman Chalisa','Prasad'],
    'https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=600',
    true, false, true, 312, 4.60, 91
  ),
  (
    v_pkg_ganesh, 'Ganesh Chaturthi Puja',
    'Special Ganesh Chaturthi celebration with Sthapana, 21 Modak offering, Atharvashirsha recitation, and Visarjan guidance.',
    1499.00, NULL, 90, true, true, 'puja',
    ARRAY['Pandit','Ganesh Murti','Modak Samagri','Flowers & Decorations','Online Streaming'],
    'https://images.unsplash.com/photo-1567591414240-e9c1e838f2b4?w=600',
    true, true, false, 78, 4.85, 19
  )
  ON CONFLICT (id) DO UPDATE
    SET title = EXCLUDED.title, description = EXCLUDED.description,
        price = EXCLUDED.price, discount_price = EXCLUDED.discount_price,
        duration_minutes = EXCLUDED.duration_minutes,
        is_online = EXCLUDED.is_online, is_offline = EXCLUDED.is_offline,
        category = EXCLUDED.category, includes = EXCLUDED.includes,
        image_url = EXCLUDED.image_url, is_active = true,
        is_featured = EXCLUDED.is_featured, is_popular = EXCLUDED.is_popular,
        booking_count = EXCLUDED.booking_count,
        rating = EXCLUDED.rating, review_count = EXCLUDED.review_count;

  -- ══════════════════════════════════════════════════════════════════════════
  -- 5. SPECIAL POOJAS (3)
  -- ══════════════════════════════════════════════════════════════════════════
  INSERT INTO public.special_poojas (
    id, title, description, significance, temple_name,
    location, price, duration_minutes, image_url,
    is_active, available_from, available_until
  ) VALUES
  (
    v_sp_kamakhya, 'Kamakhya Devi Pooja',
    'Sacred Kamakhya Devi Pooja performed at the Kamakhya Temple premises by authorized temple priests.',
    'Kamakhya Devi is one of the most powerful Shakti Peethas. Especially beneficial for fertility, marriage, and removal of negative energies.',
    'Kamakhya Temple',
    '{"city":"Guwahati","state":"Assam","lat":26.1664,"lng":91.7058}'::jsonb,
    5999.00, 120,
    'https://images.unsplash.com/photo-1561361513-2d000a50f0dc?w=600',
    true, CURRENT_DATE, CURRENT_DATE + interval '180 days'
  ),
  (
    v_sp_mahamrit, 'Mahamrityunjaya Jaap',
    '1,25,000 Mahamrityunjaya mantra jaap performed by 5 Vedic Brahmins over 3 days. Includes Havan and Tarpan.',
    'The Mahamrityunjaya Mantra removes fear of death, cures chronic diseases, and protects from accidents.',
    'Kashi Vishwanath Temple',
    '{"city":"Varanasi","state":"Uttar Pradesh","lat":25.3109,"lng":83.0107}'::jsonb,
    11999.00, 240,
    'https://images.unsplash.com/photo-1609710228159-0fa9bd7c0827?w=600',
    true, CURRENT_DATE, CURRENT_DATE + interval '365 days'
  ),
  (
    v_sp_kalsarpa, 'Kaal Sarp Dosh Nivaran',
    'Complete Kaal Sarp Dosh Nivaran Puja at Trimbakeshwar Jyotirlinga. Includes Nag Bali, Narayan Bali, and Tripindi Shradh.',
    'Neutralizes negative effects of Kaal Sarp Dosh and brings stability in career, relationships, and health.',
    'Trimbakeshwar Temple',
    '{"city":"Nashik","state":"Maharashtra","lat":19.9422,"lng":73.5310}'::jsonb,
    8999.00, 180,
    'https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=600',
    true, CURRENT_DATE, CURRENT_DATE + interval '365 days'
  )
  ON CONFLICT (id) DO UPDATE
    SET title = EXCLUDED.title, description = EXCLUDED.description,
        significance = EXCLUDED.significance, temple_name = EXCLUDED.temple_name,
        location = EXCLUDED.location, price = EXCLUDED.price,
        duration_minutes = EXCLUDED.duration_minutes, image_url = EXCLUDED.image_url,
        is_active = true, available_from = EXCLUDED.available_from,
        available_until = EXCLUDED.available_until;

  -- ══════════════════════════════════════════════════════════════════════════
  -- 6. SHOP PRODUCTS (5)
  -- ══════════════════════════════════════════════════════════════════════════
  INSERT INTO public.products (
    id, name, description, price_paise, category, image_url,
    stock, includes, is_active, is_best_seller, rating, review_count
  ) VALUES
  (
    v_prod_satya, 'Satyanarayan Puja Kit',
    'Complete puja samagri kit for Satyanarayan Katha. Contains all essential items including roli, moli, agarbatti, ghee, camphor, and step-by-step guide.',
    149900, 'puja-kit',
    'https://images.unsplash.com/photo-1604608672516-f1b9b1d37076?w=400',
    50, ARRAY['Roli & Moli','Agarbatti Set','Camphor','Ghee Diya','Coconut','Betel Leaves','Puja Guide Book'],
    true, true, 4.70, 34
  ),
  (
    v_prod_grih, 'Grih Pravesh Kit',
    'Premium housewarming puja kit with Vastu essentials. Includes Kalash, mango leaves, red cloth, and everything for a complete ceremony.',
    249900, 'puja-kit',
    'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=400',
    30, ARRAY['Brass Kalash','Mango Leaves','Red Cloth Set','Swastik Stickers','Sacred Thread','Havan Samagri','Vastu Guide'],
    true, true, 4.90, 22
  ),
  (
    v_prod_navgraha, 'Navgraha Shanti Kit',
    'Complete Navgraha Shanti Puja kit with 9 types of grains, 9 colored cloths, and all required items.',
    199900, 'puja-kit',
    'https://images.unsplash.com/photo-1609710228159-0fa9bd7c0827?w=400',
    40, ARRAY['9 Types of Grains','9 Colored Cloths','Navgraha Yantra','Havan Samagri','Instruction Booklet'],
    true, false, 4.50, 18
  ),
  (
    v_prod_tulsi, 'Premium Tulsi Mala',
    'Hand-crafted 108-bead Tulsi mala for daily japa and meditation. Made from genuine Vrindavan Tulsi wood.',
    79900, 'accessories',
    'https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=400',
    100, ARRAY['108 Tulsi Beads','Gaumukhi Bag','Velvet Pouch','Authenticity Certificate'],
    true, false, 4.80, 56
  ),
  (
    v_prod_rudra, 'Rudraksha Bracelet (5 Mukhi)',
    'Authentic 5-Mukhi Rudraksha bracelet with silver caps. Energised and blessed. Lab-certified genuine Rudraksha.',
    129900, 'accessories',
    'https://images.unsplash.com/photo-1567591414240-e9c1e838f2b4?w=400',
    60, ARRAY['5-Mukhi Rudraksha Beads','Silver Caps','Certificate of Authenticity','Blessing Card'],
    true, true, 4.85, 41
  )
  ON CONFLICT (id) DO UPDATE
    SET name = EXCLUDED.name, description = EXCLUDED.description,
        price_paise = EXCLUDED.price_paise, category = EXCLUDED.category,
        image_url = EXCLUDED.image_url, stock = EXCLUDED.stock,
        includes = EXCLUDED.includes, is_active = true,
        is_best_seller = EXCLUDED.is_best_seller,
        rating = EXCLUDED.rating, review_count = EXCLUDED.review_count;

  -- ══════════════════════════════════════════════════════════════════════════
  -- 7. DEMO USER ADDRESS
  -- ══════════════════════════════════════════════════════════════════════════
  INSERT INTO public.addresses (id, user_id, label, address_line, city, state, pincode, is_default)
  VALUES (v_address_id, v_user_id, 'Home', '42, Shanti Nagar, MG Road', 'Mumbai', 'Maharashtra', '400001', true)
  ON CONFLICT (id) DO UPDATE
    SET address_line = EXCLUDED.address_line, city = EXCLUDED.city;

  -- ══════════════════════════════════════════════════════════════════════════
  -- 8. BOOKINGS (3)
  -- ══════════════════════════════════════════════════════════════════════════

  -- 8a. CONFIRMED booking (upcoming)
  INSERT INTO public.bookings (
    id, user_id, pandit_id, package_id, package_title, category,
    booking_date, slot_id, slot, location,
    status, amount, is_paid, is_auto_assigned, notes
  ) VALUES (
    v_bk_confirmed, v_user_id, v_pandit_id, v_pkg_satya,
    'Satyanarayan Katha', 'puja',
    CURRENT_DATE + interval '7 days', 'slot_0900',
    '{"id":"slot_0900","label":"09:00 AM - 11:00 AM","startTime":"09:00","endTime":"11:00"}'::jsonb,
    '{"isOnline":false,"city":"Mumbai","state":"Maharashtra","address":"42, Shanti Nagar, MG Road","pincode":"400001"}'::jsonb,
    'confirmed', 1999.00, true, false,
    'Please bring extra flowers for the ritual.'
  )
  ON CONFLICT (id) DO UPDATE
    SET status = 'confirmed', booking_date = CURRENT_DATE + interval '7 days', is_paid = true;

  -- 8b. COMPLETED booking (past)
  INSERT INTO public.bookings (
    id, user_id, pandit_id, package_id, package_title, category,
    booking_date, slot_id, slot, location,
    status, amount, is_paid, is_auto_assigned, notes
  ) VALUES (
    v_bk_completed, v_user_id, v_pandit_id, v_pkg_rudra,
    'Rudrabhishek', 'puja',
    CURRENT_DATE - interval '5 days', 'slot_1100',
    '{"id":"slot_1100","label":"11:00 AM - 12:30 PM","startTime":"11:00","endTime":"12:30"}'::jsonb,
    '{"isOnline":true}'::jsonb,
    'completed', 1499.00, true, false,
    'Online session was wonderful. Thank you!'
  )
  ON CONFLICT (id) DO UPDATE
    SET status = 'completed', booking_date = CURRENT_DATE - interval '5 days', is_paid = true;

  -- 8c. ASSIGNED booking (pandit view, upcoming)
  INSERT INTO public.bookings (
    id, user_id, pandit_id, package_id, package_title, category,
    booking_date, slot_id, slot, location,
    status, amount, is_paid, is_auto_assigned, notes
  ) VALUES (
    v_bk_assigned, v_user_id, v_pandit_id, v_pkg_grih,
    'Grih Pravesh Pooja', 'puja',
    CURRENT_DATE + interval '3 days', 'slot_1400',
    '{"id":"slot_1400","label":"02:00 PM - 05:00 PM","startTime":"14:00","endTime":"17:00"}'::jsonb,
    '{"isOnline":false,"city":"Mumbai","state":"Maharashtra","address":"15, Green Park, Andheri West","pincode":"400053"}'::jsonb,
    'assigned', 3499.00, true, false,
    'New apartment on 7th floor. Parking available.'
  )
  ON CONFLICT (id) DO UPDATE
    SET status = 'assigned', booking_date = CURRENT_DATE + interval '3 days', is_paid = true;

  -- ══════════════════════════════════════════════════════════════════════════
  -- 9. BOOKING PROOF (for completed booking)
  -- ══════════════════════════════════════════════════════════════════════════
  INSERT INTO public.booking_proofs (
    id, booking_id, pandit_id,
    video_storage_path, video_duration_secs,
    image_storage_paths, uploaded_at, is_verified, verifier_note
  ) VALUES (
    v_proof_id, v_bk_completed, v_pandit_id,
    NULL, 0, ARRAY[]::text[],
    now() - interval '4 days', true,
    'Verified by admin. Puja performed correctly.'
  )
  ON CONFLICT ON CONSTRAINT unique_proof_per_booking DO UPDATE
    SET is_verified = true, verifier_note = EXCLUDED.verifier_note;

  -- ══════════════════════════════════════════════════════════════════════════
  -- 10. CONSULTATIONS (2)
  -- ══════════════════════════════════════════════════════════════════════════

  -- Clean up first (unique index on active user)
  DELETE FROM public.messages WHERE consultation_id IN (v_consult_done, v_consult_ended);
  DELETE FROM public.consultations WHERE id IN (v_consult_done, v_consult_ended);

  -- 10a. Ended consultation
  INSERT INTO public.consultations (
    id, user_id, pandit_id, start_ts, end_ts,
    duration_minutes, consumed_minutes, status, price, is_paid
  ) VALUES (
    v_consult_done, v_user_id, v_pandit_id,
    now() - interval '10 days',
    now() - interval '10 days' + interval '28 minutes',
    30, 28, 'ended', 249.00, true
  );

  -- 10b. Expired consultation
  INSERT INTO public.consultations (
    id, user_id, pandit_id, start_ts, end_ts,
    duration_minutes, consumed_minutes, status, price, is_paid
  ) VALUES (
    v_consult_ended, v_user_id, v_pandit_id,
    now() - interval '3 days',
    now() - interval '3 days' + interval '15 minutes',
    15, 15, 'expired', 149.00, true
  );

  -- ══════════════════════════════════════════════════════════════════════════
  -- 11. CONSULTATION MESSAGES
  -- ══════════════════════════════════════════════════════════════════════════
  INSERT INTO public.messages (consultation_id, sender_id, content, created_at)
  VALUES
    (v_consult_done, v_user_id,   'Namaste Pandit ji, I need guidance about my upcoming Grih Pravesh ceremony.',
     now() - interval '10 days' + interval '1 minute'),
    (v_consult_done, v_pandit_id, 'Namaste! Congratulations on your new home. I would be happy to guide you. When is the planned date?',
     now() - interval '10 days' + interval '2 minutes'),
    (v_consult_done, v_user_id,   'We are planning for next month. What is the best muhurat?',
     now() - interval '10 days' + interval '4 minutes'),
    (v_consult_done, v_pandit_id, 'Let me check the panchang. The 15th or 22nd would be most auspicious. Avoid Tuesdays and Saturdays.',
     now() - interval '10 days' + interval '6 minutes'),
    (v_consult_done, v_user_id,   'The 22nd works perfectly! What items do we need?',
     now() - interval '10 days' + interval '8 minutes'),
    (v_consult_done, v_pandit_id, 'You will need a Kalash, mango leaves, red cloth, havan samagri. I recommend our Grih Pravesh Kit from the shop.',
     now() - interval '10 days' + interval '10 minutes'),
    (v_consult_done, v_user_id,   'That is very helpful. Thank you so much, Pandit ji!',
     now() - interval '10 days' + interval '12 minutes'),
    (v_consult_done, v_pandit_id, 'You are welcome! May Lord Ganesh bless your new home. Feel free to book me for the ceremony.',
     now() - interval '10 days' + interval '14 minutes');

  -- ══════════════════════════════════════════════════════════════════════════
  -- 12. SHOP ORDERS (2)
  -- ══════════════════════════════════════════════════════════════════════════

  -- 12a. Delivered order
  INSERT INTO public.orders (
    id, user_id, items, subtotal_paise, tax_paise, total_paise,
    status, shipping_addr, payment_id
  ) VALUES (
    v_order_done, v_user_id,
    ('[{"product_id":"' || v_prod_satya || '","name":"Satyanarayan Puja Kit","qty":1,"price_paise":149900,"image_url":"https://images.unsplash.com/photo-1604608672516-f1b9b1d37076?w=400"},{"product_id":"' || v_prod_tulsi || '","name":"Premium Tulsi Mala","qty":1,"price_paise":79900,"image_url":"https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=400"}]')::jsonb,
    229800, 11490, 241290,
    'delivered',
    '{"name":"Rajesh Kumar","address":"42, Shanti Nagar, MG Road","city":"Mumbai","pincode":"400001","phone":"+919876543210"}'::jsonb,
    'mock_pay_demo_001'
  )
  ON CONFLICT (id) DO UPDATE
    SET status = 'delivered', items = EXCLUDED.items;

  -- 12b. Confirmed order (pending shipment)
  INSERT INTO public.orders (
    id, user_id, items, subtotal_paise, tax_paise, total_paise,
    status, shipping_addr, payment_id
  ) VALUES (
    v_order_pending, v_user_id,
    ('[{"product_id":"' || v_prod_grih || '","name":"Grih Pravesh Kit","qty":1,"price_paise":249900,"image_url":"https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=400"}]')::jsonb,
    249900, 12495, 262395,
    'confirmed',
    '{"name":"Rajesh Kumar","address":"42, Shanti Nagar, MG Road","city":"Mumbai","pincode":"400001","phone":"+919876543210"}'::jsonb,
    'mock_pay_demo_002'
  )
  ON CONFLICT (id) DO UPDATE
    SET status = 'confirmed', items = EXCLUDED.items;

  -- ══════════════════════════════════════════════════════════════════════════
  -- 13. PACKAGE REVIEWS
  -- ══════════════════════════════════════════════════════════════════════════
  INSERT INTO public.package_reviews (package_id, user_id, rating, comment)
  VALUES
    (v_pkg_satya, v_user_id, 5, 'Wonderful experience! Pandit ji was very knowledgeable and performed the puja with great devotion.'),
    (v_pkg_rudra, v_user_id, 5, 'The online Rudrabhishek was beautifully done. Very satisfied with the service.')
  ON CONFLICT (package_id, user_id) DO UPDATE
    SET rating = EXCLUDED.rating, comment = EXCLUDED.comment;

  RAISE NOTICE '═══════════════════════════════════════════════════════════════';
  RAISE NOTICE 'Demo seed complete!';
  RAISE NOTICE '  User  : demo_user@divinepooja.com   / Demo@123';
  RAISE NOTICE '  Pandit: demo_pandit@divinepooja.com / Demo@123';
  RAISE NOTICE '  Admin : demo_admin@divinepooja.com  / Demo@123';
  RAISE NOTICE '═══════════════════════════════════════════════════════════════';

END $$;
