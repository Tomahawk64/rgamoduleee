import 'package:flutter/material.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────
enum PackageMode { online, offline, both }

enum PackageCategory {
  puja,
  astrology,
  vastu,
  havan,
  katha,
  remedies,
  other,
}

extension PackageCategoryX on PackageCategory {
  String get label {
    switch (this) {
      case PackageCategory.puja:       return 'Puja';
      case PackageCategory.astrology:  return 'Astrology';
      case PackageCategory.vastu:      return 'Vastu';
      case PackageCategory.havan:      return 'Havan';
      case PackageCategory.katha:      return 'Katha';
      case PackageCategory.remedies:   return 'Remedies';
      case PackageCategory.other:      return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case PackageCategory.puja:       return Icons.auto_awesome;
      case PackageCategory.astrology:  return Icons.stars_rounded;
      case PackageCategory.vastu:      return Icons.home_work_rounded;
      case PackageCategory.havan:      return Icons.brightness_5_rounded;
      case PackageCategory.katha:      return Icons.menu_book_rounded;
      case PackageCategory.remedies:   return Icons.healing_rounded;
      case PackageCategory.other:      return Icons.category_rounded;
    }
  }
}

// ── Review Model ───────────────────────────────────────────────────────────────
class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.userInitials,
    this.avatarColor,
  });

  final String id;
  final String userName;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final String? userInitials;
  final Color? avatarColor;

  /// Map to/from Supabase JSON (ready for real integration)
  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
        id:          json['id'] as String,
        userName:    json['user_name'] as String? ?? 'Anonymous',
        rating:      (json['rating'] as num).toDouble(),
        comment:     json['comment'] as String? ?? '',
        createdAt:   DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id':         id,
        'user_name':  userName,
        'rating':     rating,
        'comment':    comment,
        'created_at': createdAt.toIso8601String(),
      };
}

// ── Package Model ──────────────────────────────────────────────────────────────
class PackageModel {
  const PackageModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.durationMinutes,
    required this.mode,
    required this.category,
    required this.includes,
    required this.reviews,
    required this.rating,
    required this.reviewCount,
    required this.bookingCount,
    this.discountPrice,
    this.isActive = true,
    this.isPopular = false,
    this.isFeatured = false,
    this.panditName,
    this.imageUrl,
    this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final double price;
  final double? discountPrice;
  final int durationMinutes;
  final PackageMode mode;
  final PackageCategory category;
  final List<String> includes;       // what's included bullet list
  final List<ReviewModel> reviews;
  final double rating;
  final int reviewCount;
  final int bookingCount;
  final bool isActive;
  final bool isPopular;
  final bool isFeatured;
  final String? panditName;
  final String? imageUrl;
  final DateTime? createdAt;

  double get effectivePrice => discountPrice ?? price;
  bool get hasDiscount => discountPrice != null && discountPrice! < price;
  int get discountPercent =>
      hasDiscount ? (((price - discountPrice!) / price) * 100).round() : 0;

  String get durationLabel {
    if (durationMinutes < 60) return '${durationMinutes}m';
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String get modeLabel {
    switch (mode) {
      case PackageMode.online:  return 'Online';
      case PackageMode.offline: return 'On-site';
      case PackageMode.both:    return 'Online / On-site';
    }
  }

  /// Supabase-ready deserialization (reviews fetched separately)
  factory PackageModel.fromJson(
    Map<String, dynamic> json, {
    List<ReviewModel> reviews = const [],
  }) =>
      PackageModel(
        id:              json['id'] as String,
        title:           json['title'] as String,
        description:     json['description'] as String? ?? '',
        price:           (json['price'] as num).toDouble(),
        discountPrice:   json['discount_price'] != null
            ? (json['discount_price'] as num).toDouble()
            : null,
        durationMinutes: json['duration_minutes'] as int,
        mode: PackageMode.values.firstWhere(
          (m) => m.name == (json['mode'] as String?),
          orElse: () => PackageMode.both,
        ),
        category: PackageCategory.values.firstWhere(
          (c) => c.name == (json['category'] as String?),
          orElse: () => PackageCategory.other,
        ),
        includes:     (json['includes'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        reviews:      reviews,
        rating:       (json['rating'] as num?)?.toDouble() ?? 0,
        reviewCount:  json['review_count'] as int? ?? 0,
        bookingCount: json['booking_count'] as int? ?? 0,
        isActive:     json['is_active'] as bool? ?? true,
        isPopular:    json['is_popular'] as bool? ?? false,
        isFeatured:   json['is_featured'] as bool? ?? false,
        panditName:   json['pandit_name'] as String?,
        imageUrl:     json['image_url'] as String?,
        createdAt:    json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );
}
