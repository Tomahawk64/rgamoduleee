// scripts/seed_demo.dart — DivinePooja Client Demo Seeder
//
// Creates 3 demo accounts + populates every module with realistic data.
//
// HOW TO RUN:
//   cd scripts
//   $env:SUPABASE_SERVICE_ROLE_KEY = "eyJ..."
//   dart run seed_demo.dart
//
// Or: dart run seed_demo.dart --service-role-key=eyJ...
//
// IDEMPOTENT — safe to re-run.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const kSupabaseUrl = 'https://esxttdierlivqpblpnyw.supabase.co';
const kAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
    '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVzeHR0ZGllcmxpdnFwYmxwbnl3Iiwicm9s'
    'ZSI6ImFub24iLCJpYXQiOjE3NzE5OTkxMzIsImV4cCI6MjA4NzU3NTEzMn0'
    '.SSzjoRySZX8027i3JFowAP5XPQ8lQ69woMiSqkFYW1k';

// ── Demo account credentials ─────────────────────────────────────────────────
const kDemoUserEmail = 'demo_user@divinepooja.com';
const kDemoPanditEmail = 'demo_pandit@divinepooja.com';
const kDemoAdminEmail = 'demo_admin@divinepooja.com';
const kDemoPassword = 'Demo@123';

// Deterministic UUIDs so the script is idempotent
const kDemoUserId = 'dddddddd-0001-4ddd-8ddd-dddddddddd01';
const kDemoPanditId = 'dddddddd-0002-4ddd-8ddd-dddddddddd02';
const kDemoAdminId = 'dddddddd-0003-4ddd-8ddd-dddddddddd03';

// Package UUIDs
const kPkgSatyanarayanId = 'eeeeeeee-0001-4eee-8eee-eeeeeeeeee01';
const kPkgGrihPraveshId = 'eeeeeeee-0002-4eee-8eee-eeeeeeeeee02';
const kPkgRudrabhishekId = 'eeeeeeee-0003-4eee-8eee-eeeeeeeeee03';
const kPkgNavgrahaId = 'eeeeeeee-0004-4eee-8eee-eeeeeeeeee04';
const kPkgMahamrityunjayaId = 'eeeeeeee-0005-4eee-8eee-eeeeeeeeee05';

// Special Poojas UUIDs
const kSpKamakhyaId = 'ffffffff-0001-4fff-8fff-ffffffffffff';
const kSpMahamrityunjayaId = 'ffffffff-0002-4fff-8fff-ffffffffffff';
const kSpKaalSarpId = 'ffffffff-0003-4fff-8fff-ffffffffffff';

// Product UUIDs
const kProdSatyanarayanKit = 'aaaaaaaa-0001-4aaa-8aaa-aaaaaaaaaaaa';
const kProdGrihPraveshKit = 'aaaaaaaa-0002-4aaa-8aaa-aaaaaaaaaaaa';
const kProdNavgrahaKit = 'aaaaaaaa-0003-4aaa-8aaa-aaaaaaaaaaaa';
const kProdRudrabhishekKit = 'aaaaaaaa-0004-4aaa-8aaa-aaaaaaaaaaaa';
const kProdTulsiMala = 'aaaaaaaa-0005-4aaa-8aaa-aaaaaaaaaaaa';

// Booking UUIDs
const kBookingConfirmed = 'bbbbbb01-0001-4bbb-8bbb-bbbbbbbbbb01';
const kBookingCompleted = 'bbbbbb01-0002-4bbb-8bbb-bbbbbbbbbb02';
const kBookingAssigned = 'bbbbbb01-0003-4bbb-8bbb-bbbbbbbbbb03';

// Consultation UUIDs
const kConsultCompleted = 'cccccc01-0001-4ccc-8ccc-cccccccccc01';
const kConsultActive = 'cccccc01-0002-4ccc-8ccc-cccccccccc02';

// Order UUIDs
const kOrderCompleted = '11111111-0001-4111-8111-111111111101';
const kOrderPending = '11111111-0002-4111-8111-111111111102';

// ─────────────────────────────────────────────────────────────────────────────

Future<void> main(List<String> args) async {
  final serviceKey = _resolveServiceKey(args);
  if (serviceKey == null) {
    stderr.writeln('''
ERROR: service_role key not provided.

  \$env:SUPABASE_SERVICE_ROLE_KEY = "eyJ..."
  dart run seed_demo.dart

Or: dart run seed_demo.dart --service-role-key=eyJ...
''');
    exit(1);
  }

  _banner('DivinePooja Demo Seeder', DateTime.now().toString());

  final svc = _svcHeaders(serviceKey);

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 1: Create demo auth users
  // ═══════════════════════════════════════════════════════════════════════════

  await _step('Creating demo USER account', () async {
    await _createAuthUser(svc,
        id: kDemoUserId,
        email: kDemoUserEmail,
        password: kDemoPassword,
        role: 'user',
        fullName: 'Priya Sharma');
  });

  await _step('Creating demo PANDIT account', () async {
    await _createAuthUser(svc,
        id: kDemoPanditId,
        email: kDemoPanditEmail,
        password: kDemoPassword,
        role: 'pandit',
        fullName: 'Pt. Mahesh Tiwari');
  });

  await _step('Creating demo ADMIN account', () async {
    await _createAuthUser(svc,
        id: kDemoAdminId,
        email: kDemoAdminEmail,
        password: kDemoPassword,
        role: 'admin',
        fullName: 'Admin DivinePooja');
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 2: Ensure profiles exist with correct roles
  // ═══════════════════════════════════════════════════════════════════════════

  await _step('Upserting profiles', () async {
    await _upsert(svc, 'profiles', [
      {
        'id': kDemoUserId,
        'full_name': 'Priya Sharma',
        'phone': '+91-9876543210',
        'role': 'user',
        'is_active': true,
        'rating': 0.0,
      },
      {
        'id': kDemoPanditId,
        'full_name': 'Pt. Mahesh Tiwari',
        'phone': '+91-9876543211',
        'role': 'pandit',
        'is_active': true,
        'rating': 4.85,
      },
      {
        'id': kDemoAdminId,
        'full_name': 'Admin DivinePooja',
        'phone': '+91-9876543212',
        'role': 'admin',
        'is_active': true,
        'rating': 0.0,
      },
    ]);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 3: Pandit details
  // ═══════════════════════════════════════════════════════════════════════════

  await _step('Upserting pandit_details', () async {
    await _upsert(svc, 'pandit_details', [
      {
        'id': kDemoPanditId,
        'specialties': ['Vedic Astrology', 'Grih Pravesh', 'Rudrabhishek'],
        'languages': ['Hindi', 'English', 'Sanskrit'],
        'experience_years': 15,
        'bio':
            'Pt. Mahesh Tiwari is a renowned Vedic scholar with 15+ years of experience in all major puja ceremonies and astrological consultations.',
        'is_online': true,
        'consultation_enabled': true,
        'location': 'Varanasi, Uttar Pradesh',
      },
    ]);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 4: Consultation rates
  // ═══════════════════════════════════════════════════════════════════════════

  await _step('Upserting consultation_rates', () async {
    await _upsert(svc, 'consultation_rates', [
      {
        'pandit_id': kDemoPanditId,
        'duration_minutes': 10,
        'price': 199.00,
        'is_active': true,
      },
      {
        'pandit_id': kDemoPanditId,
        'duration_minutes': 20,
        'price': 349.00,
        'is_active': true,
      },
      {
        'pandit_id': kDemoPanditId,
        'duration_minutes': 30,
        'price': 499.00,
        'is_active': true,
      },
    ]);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 5: Packages
  // ═══════════════════════════════════════════════════════════════════════════

  await _step('Upserting packages', () async {
    await _upsert(svc, 'packages', [
      {
        'id': kPkgSatyanarayanId,
        'title': 'Satyanarayan Katha',
        'description':
            'A sacred Vedic ceremony invoking Lord Vishnu for prosperity, peace, and divine blessings. Includes complete puja samagri and pandit services.',
        'price': 2100.00,
        'duration_minutes': 120,
        'is_online': true,
        'is_active': true,
        'is_offline': true,
        'category': 'puja',
        'includes': [
          'Pandit Ji',
          'Puja Samagri',
          'Prasad',
          'Katha Book',
          'Flower Decoration'
        ],
        'image_url': 'https://picsum.photos/seed/satyanarayan/600/400',
        'is_featured': true,
        'is_popular': true,
        'booking_count': 156,
        'rating': 4.90,
        'review_count': 89,
      },
      {
        'id': kPkgGrihPraveshId,
        'title': 'Grih Pravesh Pooja',
        'description':
            'Auspicious housewarming ceremony to purify your new home with Vedic mantras and rituals. Complete with havan, puja, and vastu shanti.',
        'price': 5100.00,
        'duration_minutes': 180,
        'is_online': false,
        'is_active': true,
        'is_offline': true,
        'category': 'puja',
        'includes': [
          'Senior Pandit Ji',
          'Complete Samagri',
          'Havan Kund',
          'Coconut & Flowers',
          'Vastu Dosh Nivaran'
        ],
        'image_url': 'https://picsum.photos/seed/grihpravesh/600/400',
        'is_featured': true,
        'is_popular': true,
        'booking_count': 203,
        'rating': 4.80,
        'review_count': 112,
      },
      {
        'id': kPkgRudrabhishekId,
        'title': 'Rudrabhishek',
        'description':
            'Powerful Shiva puja with abhishek of the holy Shiva Lingam using milk, honey, and sacred waters. Removes obstacles and brings peace.',
        'price': 3500.00,
        'duration_minutes': 150,
        'is_online': true,
        'is_active': true,
        'is_offline': true,
        'category': 'puja',
        'includes': [
          'Pandit Ji',
          'Abhishek Samagri',
          'Belpatra',
          'Rudri Path',
          'Prasad Kit'
        ],
        'image_url': 'https://picsum.photos/seed/rudrabhishek/600/400',
        'is_featured': true,
        'is_popular': false,
        'booking_count': 98,
        'rating': 4.95,
        'review_count': 67,
      },
      {
        'id': kPkgNavgrahaId,
        'title': 'Navgraha Shanti Puja',
        'description':
            'Appease all nine planetary deities for astrological balance, career growth, and removal of dosha effects.',
        'price': 4500.00,
        'duration_minutes': 180,
        'is_online': true,
        'is_active': true,
        'is_offline': true,
        'category': 'astrology',
        'includes': [
          'Expert Astrologer',
          'Navgraha Yantra',
          'Havan Samagri',
          'Personalized Kundli',
          'Remedial Mantras'
        ],
        'image_url': 'https://picsum.photos/seed/navgraha/600/400',
        'is_featured': false,
        'is_popular': true,
        'booking_count': 134,
        'rating': 4.70,
        'review_count': 78,
      },
      {
        'id': kPkgMahamrityunjayaId,
        'title': 'Mahamrityunjaya Jaap',
        'description':
            '1,25,000 repetitions of the Mahamrityunjaya Mantra for health, longevity, and protection from untimely death.',
        'price': 7500.00,
        'duration_minutes': 240,
        'is_online': true,
        'is_active': true,
        'is_offline': true,
        'category': 'puja',
        'includes': [
          'Team of 5 Pandits',
          'Havan',
          'Rudraksha Mala',
          'Prasad',
          'Certificate'
        ],
        'image_url': 'https://picsum.photos/seed/mahamrityunjaya/600/400',
        'is_featured': true,
        'is_popular': true,
        'booking_count': 76,
        'rating': 4.98,
        'review_count': 45,
      },
    ]);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 6: Special Poojas
  // ═══════════════════════════════════════════════════════════════════════════

  await _step('Upserting special_poojas', () async {
    await _upsert(svc, 'special_poojas', [
      {
        'id': kSpKamakhyaId,
        'title': 'Kamakhya Devi Pooja',
        'description':
            'Sacred offering at the Kamakhya Temple in Guwahati. This divine puja invokes the blessings '
                'of Goddess Kamakhya for fulfilment of desires and removal of negativity.',
        'significance':
            'Kamakhya Temple is one of the 51 Shakti Peethas. The puja performed here carries '
                'immense spiritual significance for devotees seeking fertility, love, and protection.',
        'temple_name': 'Kamakhya Temple',
        'location': jsonEncode({
          'city': 'Guwahati',
          'state': 'Assam',
          'lat': 26.1664,
          'lng': 91.7058,
        }),
        'price': 11000.00,
        'duration_minutes': 120,
        'image_url': 'https://picsum.photos/seed/kamakhya/600/400',
        'is_active': true,
        'available_from': '2026-01-01',
        'available_until': '2026-12-31',
      },
      {
        'id': kSpMahamrityunjayaId,
        'title': 'Mahamrityunjaya Jaap at Trimbakeshwar',
        'description':
            'Powerful 1,25,000 chant jaap performed at the sacred Trimbakeshwar Jyotirlinga temple '
                'for health, longevity, and divine protection.',
        'significance':
            'Trimbakeshwar is one of the twelve Jyotirlingas of Lord Shiva. The Mahamrityunjaya '
                'Jaap performed here is considered extremely potent for overcoming serious ailments.',
        'temple_name': 'Trimbakeshwar Temple',
        'location': jsonEncode({
          'city': 'Nashik',
          'state': 'Maharashtra',
          'lat': 19.9426,
          'lng': 73.5313,
        }),
        'price': 15000.00,
        'duration_minutes': 240,
        'image_url': 'https://picsum.photos/seed/trimbak/600/400',
        'is_active': true,
        'available_from': '2026-01-01',
        'available_until': '2026-12-31',
      },
      {
        'id': kSpKaalSarpId,
        'title': 'Kaal Sarp Dosh Nivaran Puja',
        'description':
            'Specialized puja at Mahakaleshwar Ujjain to neutralize the ill effects of Kaal Sarp Dosh '
                'in the horoscope. Performed with Nag Bali and Tripindi Shradh.',
        'significance':
            'Kaal Sarp Dosh is one of the most feared astrological doshas. This puja at Mahakaleshwar '
                'Temple is considered the ultimate remedy by Vedic astrologers.',
        'temple_name': 'Mahakaleshwar Temple',
        'location': jsonEncode({
          'city': 'Ujjain',
          'state': 'Madhya Pradesh',
          'lat': 23.1827,
          'lng': 75.7681,
        }),
        'price': 9500.00,
        'duration_minutes': 180,
        'image_url': 'https://picsum.photos/seed/kaalsarp/600/400',
        'is_active': true,
        'available_from': '2026-02-01',
        'available_until': '2026-11-30',
      },
    ]);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 7: Shop products
  // ═══════════════════════════════════════════════════════════════════════════

  await _step('Upserting products', () async {
    await _upsert(svc, 'products', [
      {
        'id': kProdSatyanarayanKit,
        'name': 'Satyanarayan Puja Kit',
        'description':
            'Complete kit for Satyanarayan Katha — includes mango leaves, supari, banana, '
                'roli, rice, incense, diya, and all essential puja samagri items.',
        'price_paise': 79900,
        'category': 'puja_kit',
        'image_url': 'https://picsum.photos/seed/satkit/400/400',
        'stock': 50,
        'includes': [
          'Puja Thali',
          'Kalash',
          'Mango Leaves',
          'Supari',
          'Roli & Rice'
        ],
        'is_active': true,
        'is_best_seller': true,
        'rating': 4.70,
        'review_count': 234,
      },
      {
        'id': kProdGrihPraveshKit,
        'name': 'Grih Pravesh Puja Kit',
        'description':
            'Premium housewarming puja set — havan kund, samagri, coconut, mango leaves, '
                'red cloth, turmeric block, and all Vedic puja essentials.',
        'price_paise': 149900,
        'category': 'puja_kit',
        'image_url': 'https://picsum.photos/seed/gpkit/400/400',
        'stock': 30,
        'includes': [
          'Havan Kund (Copper)',
          'Havan Samagri 500g',
          'Coconut & Flowers',
          'Red Cloth',
          'Complete Puja Items'
        ],
        'is_active': true,
        'is_best_seller': true,
        'rating': 4.80,
        'review_count': 187,
      },
      {
        'id': kProdNavgrahaKit,
        'name': 'Navgraha Shanti Kit',
        'description':
            'Nine-planet appeasement kit — includes 9 coloured cloth pieces, 9 types of grains, '
                'Navgraha yantra, incense, and detailed puja vidhi booklet.',
        'price_paise': 119900,
        'category': 'puja_kit',
        'image_url': 'https://picsum.photos/seed/ngkit/400/400',
        'stock': 40,
        'includes': [
          '9 Colour Cloths',
          '9 Grain Types',
          'Navgraha Yantra',
          'Incense Set',
          'Puja Vidhi Booklet'
        ],
        'is_active': true,
        'is_best_seller': false,
        'rating': 4.50,
        'review_count': 98,
      },
      {
        'id': kProdRudrabhishekKit,
        'name': 'Rudrabhishek Puja Kit',
        'description':
            'All-in-one abhishek set for Shiva puja — milk, honey, ghee, curd, sugarcane juice, '
                'belpatra, bilva wood, rudraksha mala, and sacred ash.',
        'price_paise': 99900,
        'category': 'puja_kit',
        'image_url': 'https://picsum.photos/seed/rdkit/400/400',
        'stock': 35,
        'includes': [
          'Panchamrit Set',
          'Belpatra (108)',
          'Rudraksha Mala',
          'Bilva Wood',
          'Sacred Ash'
        ],
        'is_active': true,
        'is_best_seller': false,
        'rating': 4.60,
        'review_count': 76,
      },
      {
        'id': kProdTulsiMala,
        'name': 'Tulsi Mala (Premium)',
        'description':
            'Handcrafted 108-bead Tulsi mala, ideal for daily japa and meditation. '
                'Grown from sacred Vrindavan Tulsi plants, naturally dried.',
        'price_paise': 29900,
        'category': 'spiritual',
        'image_url': 'https://picsum.photos/seed/tulsi/400/400',
        'stock': 100,
        'includes': ['108 Beads', 'Cotton Thread', 'Velvet Pouch'],
        'is_active': true,
        'is_best_seller': true,
        'rating': 4.90,
        'review_count': 312,
      },
    ]);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 8: Demo addresses for demo_user
  // ═══════════════════════════════════════════════════════════════════════════

  await _step('Upserting demo addresses', () async {
    await _upsert(svc, 'addresses', [
      {
        'id': 'addr0001-0001-4aaa-8aaa-aaaaaaaaaaaa',
        'user_id': kDemoUserId,
        'label': 'Home',
        'address_line': '42, Shanti Nagar, MG Road',
        'city': 'Mumbai',
        'state': 'Maharashtra',
        'pincode': '400001',
        'is_default': true,
      },
      {
        'id': 'addr0002-0002-4aaa-8aaa-aaaaaaaaaaaa',
        'user_id': kDemoUserId,
        'label': 'Office',
        'address_line': '7th Floor, Millennium Tower, BKC',
        'city': 'Mumbai',
        'state': 'Maharashtra',
        'pincode': '400051',
        'is_default': false,
      },
    ]);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 9: Demo bookings
  // ═══════════════════════════════════════════════════════════════════════════

  await _step('Upserting demo bookings', () async {
    await _upsert(svc, 'bookings', [
      // Booking 1: CONFIRMED for demo_user
      {
        'id': kBookingConfirmed,
        'user_id': kDemoUserId,
        'pandit_id': kDemoPanditId,
        'package_id': kPkgSatyanarayanId,
        'package_title': 'Satyanarayan Katha',
        'category': 'puja',
        'booking_date': '2026-03-15',
        'slot_id': 'morning_0900',
        'slot': jsonEncode({
          'label': '9:00 AM - 11:00 AM',
          'start': '09:00',
          'end': '11:00',
        }),
        'location': jsonEncode({
          'address': '42, Shanti Nagar, MG Road, Mumbai',
          'city': 'Mumbai',
          'type': 'home',
        }),
        'status': 'confirmed',
        'amount': 2100.00,
        'is_paid': true,
        'payment_id': 'demo_pay_confirmed_001',
        'notes': 'Please bring extra flowers for decoration.',
        'is_auto_assigned': false,
      },
      // Booking 2: COMPLETED for demo_user
      {
        'id': kBookingCompleted,
        'user_id': kDemoUserId,
        'pandit_id': kDemoPanditId,
        'package_id': kPkgGrihPraveshId,
        'package_title': 'Grih Pravesh Pooja',
        'category': 'puja',
        'booking_date': '2026-02-20',
        'slot_id': 'morning_1000',
        'slot': jsonEncode({
          'label': '10:00 AM - 1:00 PM',
          'start': '10:00',
          'end': '13:00',
        }),
        'location': jsonEncode({
          'address': '7th Floor, Millennium Tower, BKC, Mumbai',
          'city': 'Mumbai',
          'type': 'office',
        }),
        'status': 'completed',
        'amount': 5100.00,
        'is_paid': true,
        'payment_id': 'demo_pay_completed_002',
        'notes': null,
        'is_auto_assigned': false,
      },
      // Booking 3: ASSIGNED to demo_pandit
      {
        'id': kBookingAssigned,
        'user_id': kDemoUserId,
        'pandit_id': kDemoPanditId,
        'package_id': kPkgRudrabhishekId,
        'package_title': 'Rudrabhishek',
        'category': 'puja',
        'booking_date': '2026-03-25',
        'slot_id': 'evening_1700',
        'slot': jsonEncode({
          'label': '5:00 PM - 7:30 PM',
          'start': '17:00',
          'end': '19:30',
        }),
        'location': jsonEncode({
          'address': '42, Shanti Nagar, MG Road, Mumbai',
          'city': 'Mumbai',
          'type': 'home',
        }),
        'status': 'assigned',
        'amount': 3500.00,
        'is_paid': true,
        'payment_id': 'demo_pay_assigned_003',
        'notes': 'Evening slot preferred, have a small mandir at home.',
        'is_auto_assigned': false,
      },
    ]);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 10: Demo consultations
  // ═══════════════════════════════════════════════════════════════════════════

  await _step('Upserting demo consultations', () async {
    await _upsert(svc, 'consultations', [
      // Completed consultation
      {
        'id': kConsultCompleted,
        'user_id': kDemoUserId,
        'pandit_id': kDemoPanditId,
        'start_ts': '2026-02-25T10:00:00+05:30',
        'end_ts': '2026-02-25T10:20:00+05:30',
        'duration_minutes': 20,
        'consumed_minutes': 18,
        'status': 'ended',
        'price': 349.00,
        'is_paid': true,
        'payment_id': 'demo_consult_pay_001',
      },
    ]);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 11: Demo messages for completed consultation
  // ═══════════════════════════════════════════════════════════════════════════

  await _step('Upserting demo chat messages', () async {
    await _upsert(svc, 'messages', [
      {
        'id': 'msg00001-0001-4msg-8msg-msgmsgmsg001',
        'consultation_id': kConsultCompleted,
        'sender_id': kDemoUserId,
        'content': 'Namaste Pandit Ji, I wanted to ask about my career prospects for 2026.',
      },
      {
        'id': 'msg00001-0002-4msg-8msg-msgmsgmsg002',
        'consultation_id': kConsultCompleted,
        'sender_id': kDemoPanditId,
        'content':
            'Namaste! Based on your nakshatra, Jupiter is transiting your 10th house this year. This is very auspicious for career growth.',
      },
      {
        'id': 'msg00001-0003-4msg-8msg-msgmsgmsg003',
        'consultation_id': kConsultCompleted,
        'sender_id': kDemoUserId,
        'content': 'That is wonderful to hear! Should I perform any specific puja?',
      },
      {
        'id': 'msg00001-0004-4msg-8msg-msgmsgmsg004',
        'consultation_id': kConsultCompleted,
        'sender_id': kDemoPanditId,
        'content':
            'I would recommend Satyanarayan Katha on the next Purnima. Also, chanting the Gayatri Mantra 108 times daily will amplify the positive effects.',
      },
      {
        'id': 'msg00001-0005-4msg-8msg-msgmsgmsg005',
        'consultation_id': kConsultCompleted,
        'sender_id': kDemoUserId,
        'content': 'Thank you so much Pandit Ji! I will book the Satyanarayan Katha right away. 🙏',
      },
    ]);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 12: Demo transactions
  // ═══════════════════════════════════════════════════════════════════════════

  await _step('Upserting demo transactions', () async {
    await _upsert(svc, 'transactions', [
      {
        'id': 'txn00001-0001-4txn-8txn-txntxntxn001',
        'user_id': kDemoUserId,
        'booking_id': kBookingConfirmed,
        'payment_provider': 'mock',
        'amount': 2100.00,
        'status': 'success',
      },
      {
        'id': 'txn00001-0002-4txn-8txn-txntxntxn002',
        'user_id': kDemoUserId,
        'booking_id': kBookingCompleted,
        'payment_provider': 'mock',
        'amount': 5100.00,
        'status': 'success',
      },
      {
        'id': 'txn00001-0003-4txn-8txn-txntxntxn003',
        'user_id': kDemoUserId,
        'booking_id': kBookingAssigned,
        'payment_provider': 'mock',
        'amount': 3500.00,
        'status': 'success',
      },
      {
        'id': 'txn00001-0004-4txn-8txn-txntxntxn004',
        'user_id': kDemoUserId,
        'consultation_id': kConsultCompleted,
        'payment_provider': 'mock',
        'amount': 349.00,
        'status': 'success',
      },
    ]);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 13: Demo shop orders
  // ═══════════════════════════════════════════════════════════════════════════

  await _step('Upserting demo orders', () async {
    await _upsert(svc, 'orders', [
      // Completed order
      {
        'id': kOrderCompleted,
        'user_id': kDemoUserId,
        'items': jsonEncode([
          {
            'product_id': kProdSatyanarayanKit,
            'name': 'Satyanarayan Puja Kit',
            'qty': 1,
            'price_paise': 79900,
          },
          {
            'product_id': kProdTulsiMala,
            'name': 'Tulsi Mala (Premium)',
            'qty': 2,
            'price_paise': 29900,
          },
        ]),
        'subtotal_paise': 139700,
        'tax_paise': 25146,
        'total_paise': 164846,
        'status': 'delivered',
        'shipping_addr': jsonEncode({
          'label': 'Home',
          'address': '42, Shanti Nagar, MG Road, Mumbai 400001',
        }),
        'payment_id': 'demo_order_pay_001',
      },
      // Pending order
      {
        'id': kOrderPending,
        'user_id': kDemoUserId,
        'items': jsonEncode([
          {
            'product_id': kProdGrihPraveshKit,
            'name': 'Grih Pravesh Puja Kit',
            'qty': 1,
            'price_paise': 149900,
          },
        ]),
        'subtotal_paise': 149900,
        'tax_paise': 26982,
        'total_paise': 176882,
        'status': 'pending',
        'shipping_addr': jsonEncode({
          'label': 'Office',
          'address': '7th Floor, Millennium Tower, BKC, Mumbai 400051',
        }),
        'payment_id': 'demo_order_pay_002',
      },
    ]);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 14: Package reviews
  // ═══════════════════════════════════════════════════════════════════════════

  await _step('Upserting package_reviews', () async {
    await _upsert(svc, 'package_reviews', [
      {
        'id': 'rev00001-0001-4rev-8rev-revrevrev001',
        'package_id': kPkgSatyanarayanId,
        'user_id': kDemoUserId,
        'rating': 5,
        'comment':
            'Pt. Mahesh Tiwari conducted the katha beautifully. Very professional and knowledgeable. Highly recommended!',
      },
      {
        'id': 'rev00001-0002-4rev-8rev-revrevrev002',
        'package_id': kPkgGrihPraveshId,
        'user_id': kDemoUserId,
        'rating': 5,
        'comment':
            'Excellent Grih Pravesh ceremony. Everything was well organized and the pandit ji explained every ritual in detail.',
      },
    ]);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // DONE
  // ═══════════════════════════════════════════════════════════════════════════

  print('');
  print('═' * 60);
  print(' ✅ DEMO DATA SEEDED SUCCESSFULLY');
  print('═' * 60);
  print('');
  print(' Demo accounts:');
  print('   USER:   $kDemoUserEmail   / $kDemoPassword');
  print('   PANDIT: $kDemoPanditEmail / $kDemoPassword');
  print('   ADMIN:  $kDemoAdminEmail  / $kDemoPassword');
  print('');
  print(' Data summary:');
  print('   • 5 packages (3 featured, 4 popular)');
  print('   • 3 special poojas');
  print('   • 5 shop products');
  print('   • 3 bookings (confirmed, completed, assigned)');
  print('   • 1 consultation (completed with 5 messages)');
  print('   • 2 shop orders (delivered + pending)');
  print('   • 2 reviews');
  print('   • 3 consultation rates');
  print('   • 2 addresses');
  print('');
}

// ═════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═════════════════════════════════════════════════════════════════════════════

/// Create an auth user via admin API; skip if already exists.
Future<void> _createAuthUser(
  Map<String, String> svc, {
  required String id,
  required String email,
  required String password,
  required String role,
  required String fullName,
}) async {
  final res = await http.post(
    Uri.parse('$kSupabaseUrl/auth/v1/admin/users'),
    headers: svc,
    body: jsonEncode({
      'id': id,
      'email': email,
      'password': password,
      'email_confirm': true,
      'user_metadata': {'role': role, 'full_name': fullName},
    }),
  );

  if (res.statusCode == 200 || res.statusCode == 201) {
    print('  -> Created: $email ($role)');
  } else if (res.statusCode == 422 && res.body.contains('already')) {
    print('  -> Already exists: $email');
    // Update password + metadata in case they changed
    await http.put(
      Uri.parse('$kSupabaseUrl/auth/v1/admin/users/$id'),
      headers: svc,
      body: jsonEncode({
        'email': email,
        'password': password,
        'email_confirm': true,
        'user_metadata': {'role': role, 'full_name': fullName},
      }),
    );
  } else {
    stderr.writeln('  WARN: HTTP ${res.statusCode} for $email: ${res.body}');
  }
}

/// Upsert rows into a table. Uses Prefer: resolution=merge-duplicates.
Future<void> _upsert(
    Map<String, String> svc, String table, List<Map<String, dynamic>> rows) async {
  final res = await http.post(
    Uri.parse('$kSupabaseUrl/rest/v1/$table'),
    headers: {
      ...svc,
      'Prefer': 'resolution=merge-duplicates,return=minimal',
    },
    body: jsonEncode(rows),
  );
  if (res.statusCode == 200 ||
      res.statusCode == 201 ||
      res.statusCode == 204) {
    print('  -> $table: ${rows.length} rows upserted.');
  } else {
    stderr.writeln('  ERROR [$table]: HTTP ${res.statusCode}: ${res.body}');
  }
}

Map<String, String> _svcHeaders(String serviceKey) => {
      'apikey': serviceKey,
      'Authorization': 'Bearer $serviceKey',
      'Content-Type': 'application/json',
    };

String? _resolveServiceKey(List<String> args) {
  // 1. Check --service-role-key=... flag
  for (final arg in args) {
    if (arg.startsWith('--service-role-key=')) {
      return arg.substring('--service-role-key='.length);
    }
  }
  // 2. Check environment
  return Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
}

void _banner(String title, String sub) {
  print('');
  print('═' * 60);
  print(' $title');
  print(' $sub');
  print('═' * 60);
  print('');
}

Future<T> _step<T>(String label, Future<T> Function() fn) async {
  print('▸ $label...');
  try {
    return await fn();
  } catch (e, st) {
    stderr.writeln('  FAILED: $e');
    stderr.writeln(st);
    rethrow;
  }
}
