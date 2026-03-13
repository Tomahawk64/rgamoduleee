// lib/special_poojas/models/special_pooja_model.dart

import 'package:equatable/equatable.dart';

// ─────────────────────────── Availability slot ───────────────────────────────

class AvailabilitySlot extends Equatable {
  const AvailabilitySlot({
    required this.date,
    required this.totalSlots,
    required this.bookedSlots,
  });

  final DateTime date;
  final int totalSlots;
  final int bookedSlots;

  bool get isAvailable => bookedSlots < totalSlots;
  int get remainingSlots => totalSlots - bookedSlots;

  @override
  List<Object?> get props => [date, totalSlots, bookedSlots];
}

// ─────────────────────────── Location info ───────────────────────────────────

class TempleLocation extends Equatable {
  const TempleLocation({
    required this.address,
    required this.city,
    required this.state,
    this.pincode,
    this.latitude,
    this.longitude,
    this.mapUrl,
  });

  final String address;
  final String city;
  final String state;
  final String? pincode;
  final double? latitude;
  final double? longitude;
  final String? mapUrl;

  String get shortAddress => '$city, $state';
  String get fullAddress => '$address, $city, $state${pincode != null ? ' - $pincode' : ''}';

  factory TempleLocation.fromJson(Map<String, dynamic> json) => TempleLocation(
        address: json['address'] as String? ?? '',
        city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? '',
        pincode: json['pincode'] as String?,
        latitude: (json['lat'] as num?)?.toDouble(),
        longitude: (json['lng'] as num?)?.toDouble(),
        mapUrl: json['mapUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'address': address,
        'city': city,
        'state': state,
        if (pincode != null) 'pincode': pincode,
        if (latitude != null) 'lat': latitude,
        if (longitude != null) 'lng': longitude,
        if (mapUrl != null) 'mapUrl': mapUrl,
      };

  @override
  List<Object?> get props => [address, city, state];
}

// ─────────────────────────── Special Pooja model ─────────────────────────────

class SpecialPoojaModel extends Equatable {
  const SpecialPoojaModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.durationMinutes,
    required this.isActive,
    this.significance,
    this.templeName,
    this.location,
    this.imageUrl,
    this.availableFrom,
    this.availableUntil,
    this.availabilitySlots = const [],
    this.includes = const [],
    this.highlights = const [],
  });

  final String id;
  final String title;
  final String description;
  final double price;
  final int durationMinutes;
  final bool isActive;
  final String? significance;
  final String? templeName;
  final TempleLocation? location;
  final String? imageUrl;
  final DateTime? availableFrom;
  final DateTime? availableUntil;
  final List<AvailabilitySlot> availabilitySlots;
  final List<String> includes;
  final List<String> highlights;

  String get durationLabel {
    if (durationMinutes < 60) return '$durationMinutes min';
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  String get priceLabel => '₹${price.toStringAsFixed(0)}';

  bool get hasLocation => location != null;

  factory SpecialPoojaModel.fromJson(Map<String, dynamic> json) =>
      SpecialPoojaModel(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        price: (json['price'] as num).toDouble(),
        durationMinutes: json['duration_minutes'] as int? ?? 60,
        isActive: json['is_active'] as bool? ?? true,
        significance: json['significance'] as String?,
        templeName: json['temple_name'] as String?,
        location: json['location'] != null
            ? TempleLocation.fromJson(json['location'] as Map<String, dynamic>)
            : null,
        imageUrl: json['image_url'] as String?,
        availableFrom: json['available_from'] != null
            ? DateTime.tryParse(json['available_from'] as String)
            : null,
        availableUntil: json['available_until'] != null
            ? DateTime.tryParse(json['available_until'] as String)
            : null,
      );

  @override
  List<Object?> get props => [id, title, price, isActive];
}

// ─────────────────────────── Mock seed data ──────────────────────────────────

const _img = 'assets/images';

final kMockSpecialPoojas = [
  SpecialPoojaModel(
    id: 'sp001',
    title: 'Rudrabhishek Mahapuja',
    description:
        'A grand Rudrabhishek ceremony performed with 11 pandits chanting '
        'Shri Rudram. Includes panchamrit abhishek with milk, honey, curd, '
        'ghee and sugarcane juice. This ritual is known to remove obstacles, '
        'bring prosperity and grant moksha.',
    significance:
        'Rudrabhishek is one of the most powerful Shiva rituals. It directly '
        'invokes Lord Shiva in his Rudra form. Performing this puja is '
        'believed to cleanse sins, bring rainfall, cure diseases and '
        'fulfil desires.',
    templeName: 'Shri Kashi Vishwanath Temple',
    location: TempleLocation(
      address: 'Vishwanath Gali, Varanasi',
      city: 'Varanasi',
      state: 'Uttar Pradesh',
      pincode: '221001',
    ),
    price: 5100,
    durationMinutes: 180,
    isActive: true,
    imageUrl: '$_img/image5.jpg',
    includes: [
      '11 qualified Vedic pandits',
      'All puja samagri included',
      'Panchamrit abhishek',
      'Prasad distribution',
      'Live video streaming link',
      'Certificate of completion',
    ],
    highlights: ['Lord Shiva', 'Obstacle removal', 'Prosperity', 'Moksha'],
    availableFrom: DateTime(2026, 1, 1),
    availableUntil: DateTime(2026, 12, 31),
  ),
  SpecialPoojaModel(
    id: 'sp002',
    title: 'Navgraha Shanti Puja',
    description:
        'A comprehensive Navgraha puja performed to appease all nine planetary '
        'deities. Includes 9 separate kunds (fire pits) with specific mantras '
        'for each graha. Highly recommended before marriage, new ventures '
        'or when experiencing planetary doshas.',
    significance:
        'The nine planets (Navagrahas) exert tremendous influence on our lives. '
        'This puja balances planetary energies, removes doshas like Shani Sade '
        'Sati, Rahu-Ketu, and brings harmony in career, relationships and health.',
    templeName: 'Sri Navgraha Mandir',
    location: TempleLocation(
      address: 'Ujjain Road, Gurudwara Area',
      city: 'Ujjain',
      state: 'Madhya Pradesh',
      pincode: '456001',
    ),
    price: 3600,
    durationMinutes: 120,
    isActive: true,
    imageUrl: '$_img/image6.jpg',
    includes: [
      '9 separate yagya kunds',
      'All navgraha samagri',
      'Jyotishi consultation pre-puja',
      'Prasad + navgraha yantra',
      'Detailed puja report',
    ],
    highlights: ['All 9 planets', 'Dosha removal', 'Career & health', 'Harmony'],
    availableFrom: DateTime(2026, 1, 1),
    availableUntil: DateTime(2026, 12, 31),
  ),
  SpecialPoojaModel(
    id: 'sp003',
    title: 'Maha Ganapati Homam',
    description:
        'The Maha Ganapati Homam is performed with 11,000 Ganapati mantra '
        'chants and 1,008 ahutis into the sacred fire. This is the premier '
        'ritual for removing all obstacles before starting new endeavours.',
    significance:
        'Lord Ganesha is the remover of obstacles (Vighnaharta). This grand '
        'homam invokes his blessings for success in new business, education, '
        'marriage or any significant life event.',
    templeName: 'Shri Siddhivinayak Mandir',
    location: TempleLocation(
      address: 'Prabhadevi, S.K. Bole Marg',
      city: 'Mumbai',
      state: 'Maharashtra',
      pincode: '400028',
    ),
    price: 7500,
    durationMinutes: 240,
    isActive: true,
    imageUrl: '$_img/image7.jpg',
    includes: [
      '11,000 mantra chants',
      '1,008 ahutis',
      'Modak prasad distribution',
      'Yantra consecration',
      'Video recording',
      'Dakshina included',
    ],
    highlights: ['Obstacle removal', 'New beginnings', 'Success', 'Blessings'],
    availableFrom: DateTime(2026, 1, 1),
    availableUntil: DateTime(2026, 12, 31),
  ),
  SpecialPoojaModel(
    id: 'sp004',
    title: 'Lakshmi Kubera Puja',
    description:
        'The Lakshmi Kubera Puja combines the energies of Goddess Lakshmi '
        '(wealth and prosperity) with Lord Kubera (treasury of the gods). '
        'This powerful ritual attracts abundance, clears financial difficulties '
        'and opens new avenues of income.',
    significance:
        'Performed especially on Fridays and Dhanteras, this puja is the '
        'most effective ritual for financial prosperity. Ideal for business '
        'owners, investors and those seeking financial stability.',
    templeName: 'Shri Mahalakshmi Mandir',
    location: TempleLocation(
      address: 'Bhulabhai Desai Road, Breachcandy',
      city: 'Mumbai',
      state: 'Maharashtra',
      pincode: '400026',
    ),
    price: 4500,
    durationMinutes: 150,
    isActive: true,
    imageUrl: '$_img/image8.jpg',
    includes: [
      'Lakshmi yantra puja',
      'Kubera stotram chanting',
      'Saffron & lotus puja',
      'Kumkum archana',
      'Prasad: modak + coconut',
      'Financial guidance session',
    ],
    highlights: ['Wealth', 'Financial stability', 'Abundance', 'Business growth'],
    availableFrom: DateTime(2026, 1, 1),
    availableUntil: DateTime(2026, 12, 31),
  ),
  SpecialPoojaModel(
    id: 'sp005',
    title: 'Satyanarayan Katha (Grand)',
    description:
        'The grand Satyanarayan Katha with all 5 chapters narrated by '
        'experienced kathavachaks. Includes complete puja, havan, prasad '
        'and aarti. Perfect for housewarmings, anniversaries and family '
        'celebrations involving the whole community.',
    significance:
        'Satyanarayan Katha is Lord Vishnu\'s divine narrative that fulfils '
        'wishes, brings family happiness, removes sins and blesses the home '
        'with peace and abundance.',
    price: 2100,
    durationMinutes: 180,
    isActive: true,
    imageUrl: '$_img/image5.jpg',
    includes: [
      'All 5 chapters narration',
      'Panchamrit panchopa­char puja',
      'Complete havan with 108 ahutis',
      'Panchkheer prasad',
      'Pandit + 2 accompanists',
      'All samagri included',
    ],
    highlights: ['Lord Vishnu', 'Family blessings', 'Wish fulfilment', 'Home harmony'],
    availableFrom: DateTime(2026, 1, 1),
    availableUntil: DateTime(2026, 12, 31),
  ),
];
