// ── Pandit Model ──────────────────────────────────────────────────────────────
//
// Domain model representing a pandit available for live consultation.
// Designed for Supabase `pandit_profiles` table.
//

/// Consultation rate tiers (price per minute in paise — ₹ × 100).
class ConsultationRate {
  const ConsultationRate({
    required this.duration,
    required this.totalPaise,
  });

  /// Session duration in minutes.
  final int duration;

  /// Total price in paise (divide by 100 for ₹).
  final int totalPaise;

  double get totalRupees => totalPaise / 100;

  String get priceLabel => '₹${totalRupees.toStringAsFixed(0)}';
  String get durationLabel => '$duration min';

  @override
  String toString() => '$durationLabel · $priceLabel';
}

/// Domain model for a pandit available for live consultation.
class PanditModel {
  const PanditModel({
    required this.id,
    required this.name,
    required this.specialty,
    required this.rating,
    required this.totalSessions,
    required this.isOnline,
    required this.rates,
    this.bio,
    this.avatarUrl,
    this.languagesSpoken = const ['Hindi', 'English'],
    this.experienceYears = 0,
  });

  final String id;
  final String name;
  final String specialty;
  final double rating;
  final int totalSessions;
  final bool isOnline;

  /// Pricing tiers the pandit offers (e.g. 10, 15, 20 min).
  final List<ConsultationRate> rates;

  final String? bio;
  final String? avatarUrl;
  final List<String> languagesSpoken;
  final int experienceYears;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  // ── Factory: mock data ───────────────────────────────────────────────────
  factory PanditModel.fromJson(Map<String, dynamic> json) => PanditModel(
        id: json['id'] as String,
        name: json['name'] as String,
        specialty: json['specialty'] as String,
        rating: (json['rating'] as num).toDouble(),
        totalSessions: json['total_sessions'] as int? ?? 0,
        isOnline: json['is_online'] as bool? ?? false,
        bio: json['bio'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        experienceYears: json['experience_years'] as int? ?? 0,
        languagesSpoken: (json['languages'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            ['Hindi'],
        rates: (json['rates'] as List<dynamic>?)
                ?.map((e) => ConsultationRate(
                      duration: e['duration'] as int,
                      totalPaise: e['total_paise'] as int,
                    ))
                .toList() ??
            _defaultRates,
      );

  static const List<ConsultationRate> _defaultRates = [
    ConsultationRate(duration: 10, totalPaise: 9900),  // ₹99
    ConsultationRate(duration: 15, totalPaise: 14900), // ₹149
    ConsultationRate(duration: 20, totalPaise: 19900), // ₹199
  ];
}

// ── Seeded mock pandits ───────────────────────────────────────────────────────

final kMockPandits = [
  const PanditModel(
    id: 'pandit_001',
    name: 'Pandit Ravi Sharma',
    specialty: 'Vastu & Jyotish',
    rating: 4.9,
    totalSessions: 320,
    isOnline: true,
    experienceYears: 12,
    languagesSpoken: ['Hindi', 'English'],
    avatarUrl: 'assets/images/image12.jpg',
    bio:
        'Expert in Vastu Shastra and Vedic astrology with 12+ years of practice. '
        'Specialises in home and office Vastu corrections and birth chart analysis.',
    rates: [
      ConsultationRate(duration: 10, totalPaise: 9900),
      ConsultationRate(duration: 15, totalPaise: 14900),
      ConsultationRate(duration: 20, totalPaise: 19900),
    ],
  ),
  const PanditModel(
    id: 'pandit_002',
    name: 'Pandit Anil Verma',
    specialty: 'Kundali & Numerology',
    rating: 4.7,
    totalSessions: 215,
    isOnline: false,
    experienceYears: 8,
    languagesSpoken: ['Hindi', 'Gujarati'],
    avatarUrl: 'assets/images/image13.jpg',
    bio:
        'Kundali expert and numerologist. Offers insights on marriage compatibility, '
        'career guidance, and lucky number analysis.',
    rates: [
      ConsultationRate(duration: 10, totalPaise: 7900),
      ConsultationRate(duration: 15, totalPaise: 11900),
      ConsultationRate(duration: 20, totalPaise: 15900),
    ],
  ),
  const PanditModel(
    id: 'pandit_003',
    name: 'Acharya Priya Devi',
    specialty: 'Spiritual Guidance',
    rating: 4.8,
    totalSessions: 180,
    isOnline: true,
    experienceYears: 10,
    languagesSpoken: ['Hindi', 'English', 'Sanskrit'],
    avatarUrl: 'assets/images/image14.jpg',
    bio:
        'Spiritual counsellor and meditation guide. Helps with emotional healing, '
        'chakra balancing, and life path clarity.',
    rates: [
      ConsultationRate(duration: 10, totalPaise: 8900),
      ConsultationRate(duration: 15, totalPaise: 12900),
      ConsultationRate(duration: 20, totalPaise: 16900),
    ],
  ),
  const PanditModel(
    id: 'pandit_004',
    name: 'Pt. Suresh Tripathi',
    specialty: 'Puja & Rituals',
    rating: 4.6,
    totalSessions: 95,
    isOnline: true,
    experienceYears: 6,
    languagesSpoken: ['Hindi', 'Sanskrit'],
    avatarUrl: 'assets/images/image12.jpg',
    bio:
        'Expert in Vedic pujas and rituals. Can guide you through sankalp, '
        'havan procedure, and auspicious muhurtas.',
    rates: [
      ConsultationRate(duration: 10, totalPaise: 6900),
      ConsultationRate(duration: 15, totalPaise: 9900),
      ConsultationRate(duration: 20, totalPaise: 12900),
    ],
  ),
];
