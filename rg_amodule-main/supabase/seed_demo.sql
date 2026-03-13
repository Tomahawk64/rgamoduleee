-- =============================================================================
-- SEED: Demo / Load-Test Data
-- Run this in: Supabase Dashboard → SQL Editor
-- (Requires service-role; the SQL editor always runs as postgres superuser.)
--
-- What this creates
-- ─────────────────
--   1. A pandit user in auth.users + profiles + pandit_details + rates
--   2. A test package in packages
--   3. The test@test.com regular user profile (if not already created by Auth
--      signup trigger — idempotent via ON CONFLICT DO NOTHING)
--
-- After running, update these constants in scripts/load_test.dart:
--   kPanditId  = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
--   kPackageId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
--
-- ⚠  Run on staging/dev project only — NOT production.
-- =============================================================================

-- ── Fixed UUIDs (hard-coded so load_test.dart constants never need updating) ──
DO $$
DECLARE
  v_pandit_id  CONSTANT uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  v_package_id CONSTANT uuid := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
BEGIN

  -- ══════════════════════════════════════════════════════════════════════════
  -- 1. TEST PANDIT — auth.users entry
  -- ══════════════════════════════════════════════════════════════════════════
  INSERT INTO auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
  ) VALUES (
    v_pandit_id,
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'pandit_test@loadtest.local',
    crypt('LtPandit@123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"Load Test Pandit","role":"pandit"}'::jsonb,
    now(),
    now()
  )
  ON CONFLICT (id) DO NOTHING;

  -- ── profiles ──────────────────────────────────────────────────────────────
  INSERT INTO public.profiles (id, full_name, phone, role, is_active, rating)
  VALUES (v_pandit_id, 'Load Test Pandit', '+919999900001', 'pandit', true, 4.8)
  ON CONFLICT (id) DO UPDATE
    SET full_name  = EXCLUDED.full_name,
        role       = 'pandit',
        is_active  = true;

  -- ── pandit_details ────────────────────────────────────────────────────────
  INSERT INTO public.pandit_details (
    id,
    specialties,
    languages,
    experience_years,
    bio,
    is_online,
    consultation_enabled,
    location
  ) VALUES (
    v_pandit_id,
    ARRAY['Vedic Rituals', 'Astrology', 'Vastu'],
    ARRAY['Hindi', 'Sanskrit', 'English'],
    10,
    'Experienced Vedic pandit available for online consultations. (Load-test seed)',
    true,   -- is_online = TRUE so start_consultation_session passes the guard
    true,   -- consultation_enabled = TRUE
    'Varanasi, UP'
  )
  ON CONFLICT (id) DO UPDATE
    SET is_online            = true,
        consultation_enabled = true;

  -- ── consultation_rates ────────────────────────────────────────────────────
  INSERT INTO public.consultation_rates (pandit_id, duration_minutes, price, is_active)
  VALUES
    (v_pandit_id, 10, 99.00,  true),
    (v_pandit_id, 15, 149.00, true),
    (v_pandit_id, 30, 249.00, true),
    (v_pandit_id, 60, 449.00, true)
  ON CONFLICT (pandit_id, duration_minutes) DO UPDATE
    SET price     = EXCLUDED.price,
        is_active = true;

  -- ══════════════════════════════════════════════════════════════════════════
  -- 2. TEST PACKAGE
  -- ══════════════════════════════════════════════════════════════════════════
  INSERT INTO public.packages (
    id,
    title,
    description,
    price,
    discount_price,
    duration_minutes,
    is_online,
    is_offline,
    category,
    includes,
    is_active,
    is_featured
  ) VALUES (
    v_package_id,
    'Load Test Satyanarayan Puja',
    'Seed package used exclusively for automated load-testing. Do not book.',
    999.00,
    799.00,
    90,
    true,
    true,
    'puja',
    ARRAY['Pandit', 'Samagri Kit', 'Online Streaming'],
    true,
    false
  )
  ON CONFLICT (id) DO UPDATE
    SET title     = EXCLUDED.title,
        is_active = true;

  -- ══════════════════════════════════════════════════════════════════════════
  -- 3. TEST REGULAR USER (test@test.com)
  -- Ensure the profile row exists even if Auth trigger already fired.
  -- The user MUST be created via Supabase Auth Dashboard / signUp API first.
  -- The profile here is a safety net.
  -- ══════════════════════════════════════════════════════════════════════════
  -- If the auth.users row for test@test.com already exists, get its id:
  DECLARE
    v_test_user_id uuid;
  BEGIN
    SELECT id INTO v_test_user_id
    FROM auth.users
    WHERE email = 'test@test.com'
    LIMIT 1;

    IF v_test_user_id IS NOT NULL THEN
      INSERT INTO public.profiles (id, full_name, role, is_active)
      VALUES (v_test_user_id, 'Load Test User', 'user', true)
      ON CONFLICT (id) DO NOTHING;
    END IF;
  END;

  RAISE NOTICE '───────────────────────────────────────────────────────────';
  RAISE NOTICE 'Seed complete. Use these constants in load_test.dart:';
  RAISE NOTICE '  kPanditId  = ''aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa''';
  RAISE NOTICE '  kPackageId = ''bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb''';
  RAISE NOTICE '───────────────────────────────────────────────────────────';

END $$;


-- =============================================================================
-- CLEANUP helper (run manually if you want to reset between test runs)
-- =============================================================================
-- Uncomment and run when you need a clean slate:

-- DELETE FROM public.bookings
--   WHERE package_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

-- DELETE FROM public.consultations
--   WHERE pandit_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

-- DELETE FROM public.messages
--   WHERE consultation_id IN (
--     SELECT id FROM public.consultations
--     WHERE pandit_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
--   );
