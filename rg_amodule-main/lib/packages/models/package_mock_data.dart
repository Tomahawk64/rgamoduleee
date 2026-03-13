import 'package:flutter/material.dart';

import '../../core/constants/app_images.dart';
import 'package_model.dart';

// ── Reviews ───────────────────────────────────────────────────────────────────
final _r1 = ReviewModel(
  id: 'rv1', userName: 'Priya Sharma', rating: 5.0,
  comment: 'Pandit ji was very knowledgeable and the puja was conducted beautifully. Highly recommend!',
  createdAt: DateTime(2025, 12, 10), userInitials: 'PS', avatarColor: const Color(0xFFFF6B35),
);
final _r2 = ReviewModel(
  id: 'rv2', userName: 'Rohan Verma', rating: 4.5,
  comment: 'Very smooth experience. The pandit arrived on time and explained each step clearly.',
  createdAt: DateTime(2025, 11, 22), userInitials: 'RV', avatarColor: const Color(0xFF2D4A8A),
);
final _r3 = ReviewModel(
  id: 'rv3', userName: 'Sunita Gupta', rating: 4.0,
  comment: 'Good service overall. The samagri quality could be a bit better but the ritual was perfect.',
  createdAt: DateTime(2025, 10, 5), userInitials: 'SG', avatarColor: const Color(0xFF1B5E20),
);
final _r4 = ReviewModel(
  id: 'rv4', userName: 'Anil Tiwari', rating: 5.0,
  comment: 'Excellent online consultation. Pandit Ramesh guided us step by step via video call. Ten on ten.',
  createdAt: DateTime(2026, 1, 15), userInitials: 'AT', avatarColor: const Color(0xFF6A1B9A),
);
final _r5 = ReviewModel(
  id: 'rv5', userName: 'Meena Patel', rating: 4.5,
  comment: 'The Satyanarayan katha was very peaceful. Will book again for Diwali.',
  createdAt: DateTime(2026, 2, 2), userInitials: 'MP', avatarColor: const Color(0xFFBF6000),
);
final _r6 = ReviewModel(
  id: 'rv6', userName: 'Deepak Kumar', rating: 3.5,
  comment: 'Decent experience. Slight delay but pandit was cooperative.',
  createdAt: DateTime(2025, 9, 18), userInitials: 'DK', avatarColor: const Color(0xFF00838F),
);

// ── Mock Packages ─────────────────────────────────────────────────────────────
final List<PackageModel> kMockPackageList = [
  PackageModel(
    id: 'pkg001',
    title: 'Satyanarayan Puja',
    description:
        'A complete Satyanarayan Katha puja performed by an experienced Vaishnav pandit. Includes recitation of the five chapters of Satyanarayan Katha, Aarti, and prasad distribution.',
    price: 1999,
    discountPrice: 1499,
    durationMinutes: 90,
    mode: PackageMode.both,
    category: PackageCategory.puja,
    panditName: 'Pt. Ramesh Sharma',
    rating: 4.9, reviewCount: 312, bookingCount: 1240,
    isPopular: true, isFeatured: true,
    includes: [
      'Experienced Vaishnav pandit',
      'All puja samagri included',
      'Satyanarayan Katha recitation (5 chapters)',
      'Aarti & prasad',
      'Online or home visit',
      'Post-puja blessings & guidance',
    ],
    reviews: [_r1, _r2, _r5],
  ),
  PackageModel(
    id: 'pkg002',
    title: 'Kundali / Birth Chart Analysis',
    description:
        'A detailed 60-minute birth chart analysis by a certified Jyotish Acharya. Covers all 12 houses, planetary positions, dasha periods, and personalised remedies.',
    price: 999,
    discountPrice: 799,
    durationMinutes: 60,
    mode: PackageMode.online,
    category: PackageCategory.astrology,
    panditName: 'Acharya Sunil Joshi',
    rating: 4.7, reviewCount: 185, bookingCount: 870,
    isPopular: true,
    imageUrl: AppImages.consultation,
    includes: [
      'Video call with certified Jyotish Acharya',
      'Complete birth chart (Kundali) analysis',
      'Dasha & antardasha predictions',
      'Personalised gemstone & mantra remedies',
      'PDF report shared post-session',
    ],
    reviews: [_r4, _r2],
  ),
  PackageModel(
    id: 'pkg003',
    title: 'Griha Pravesh Ceremony',
    description:
        'Full griha pravesh havan and puja for your new home. Includes Vastu shanti, Navgraha puja, Ganapati sthapana, and havan. A 3-hour comprehensive ceremony.',
    price: 3999,
    durationMinutes: 180,
    mode: PackageMode.offline,
    category: PackageCategory.puja,
    panditName: 'Pt. Kavita Mishra',
    rating: 4.8, reviewCount: 240, bookingCount: 650,
    isFeatured: true,
    imageUrl: AppImages.poojaGanpati,
    includes: [
      'Two pandits for 3 hours',
      'Full havan samagri (kund, ghee, herbs)',
      'Vastu shanti puja',
      'Navgraha puja',
      'Ganapati sthapana',
      'Nariyal & red cloth for kalash',
      'Prasad & aarti',
    ],
    reviews: [_r3, _r5, _r1],
  ),
  PackageModel(
    id: 'pkg004',
    title: 'Navgraha Shanti Havan',
    description:
        'Appease all nine planets with this powerful Navgraha Shanti Havan. Performed with 9-kund fire ritual, specific mantras for each planet, and special herbs.',
    price: 4999,
    discountPrice: 3499,
    durationMinutes: 180,
    mode: PackageMode.both,
    category: PackageCategory.havan,
    panditName: 'Swami Prakash Das',
    rating: 5.0, reviewCount: 98, bookingCount: 310,
    isPopular: true, isFeatured: true,
    imageUrl: AppImages.poojaNavgraha,
    includes: [
      'Expert pandit with 20+ years experience',
      '9-kund havan setup',
      'Planet-specific samidha and herbs',
      'Navgraha yantra energisation',
      'Prasad delivery (if home visit)',
      'Post-havan mantra chanting kit',
    ],
    reviews: [_r4, _r1, _r2],
  ),
  PackageModel(
    id: 'pkg005',
    title: 'Vastu Home Inspection',
    description:
        'On-site vastu inspection for residential properties (2–3 BHK). Includes directional analysis, energy mapping, and a comprehensive digital report with easy-to-follow remedies.',
    price: 2999,
    discountPrice: 2499,
    durationMinutes: 120,
    mode: PackageMode.offline,
    category: PackageCategory.vastu,
    panditName: 'Acharya Sunil Joshi',
    rating: 4.6, reviewCount: 152, bookingCount: 420,
    imageUrl: AppImages.poojaLakshmi,
    includes: [
      'On-site visit (upto 3 BHK)',
      'Directional & 16-zone analysis',
      'Energy flow mapping',
      'Comprehensive digital report (PDF)',
      'Low-cost remedy suggestions',
      '15-min follow-up call',
    ],
    reviews: [_r6, _r3],
  ),
  PackageModel(
    id: 'pkg006',
    title: 'Sunderkand Path',
    description:
        'Complete recitation of Sunderkand from Ramacharitmanas. A deeply devotional 2-hour session bringing peace, positive energy, and removal of obstacles.',
    price: 1199,
    durationMinutes: 120,
    mode: PackageMode.both,
    category: PackageCategory.katha,
    panditName: 'Pt. Ashok Trivedi',
    rating: 4.8, reviewCount: 410, bookingCount: 1850,
    isPopular: true,
    imageUrl: AppImages.poojaSatyanarayan,
    includes: [
      'Full Sunderkand recitation (Hindi + Sanskrit)',
      'Hanuman ji puja & aarti',
      'Can be done online or at home',
      'Group or individual session available',
      'Prasad (for home visit)',
    ],
    reviews: [_r5, _r1, _r2],
  ),
  PackageModel(
    id: 'pkg007',
    title: 'Mangal Dosh Remedies',
    description:
        'Targeted remedies and puja for Mangal (Kuja) Dosha. Includes Mangal yantra sthapana, dedicated mantra japa, and a personalised remedy report.',
    price: 1499,
    durationMinutes: 75,
    mode: PackageMode.online,
    category: PackageCategory.remedies,
    panditName: 'Pt. Ramesh Sharma',
    rating: 4.5, reviewCount: 88, bookingCount: 260,
    imageUrl: AppImages.poojaGanpati,
    includes: [
      'Kundali-based Mangal Dosha assessment',
      'Mangal yantra energisation (dispatched)',
      'Mangal mantra japa (1,008 times)',
      'Red coral gemstone consultation',
      'Do\'s and Don\'ts guidance PDF',
    ],
    reviews: [_r4, _r6],
  ),
  PackageModel(
    id: 'pkg008',
    title: 'Daily Jyotish Chat Pack',
    description:
        'Weekly 30-minute video consultation + daily written horoscope predictions for 1 month. Best for guidance on career, love, and health decisions.',
    price: 499,
    discountPrice: 299,
    durationMinutes: 30,
    mode: PackageMode.online,
    category: PackageCategory.astrology,
    panditName: 'Pt. Ashok Trivedi',
    rating: 4.3, reviewCount: 520, bookingCount: 2100,
    isPopular: true,
    imageUrl: AppImages.consultation,
    includes: [
      '4 weekly 30-min video calls (1 month)',
      'Daily written predictions (WhatsApp/email)',
      'Lucky colour, number & direction each week',
      'Monthly summary report',
    ],
    reviews: [_r2, _r3, _r6],
  ),
];
