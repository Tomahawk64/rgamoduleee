import 'package:flutter/material.dart';

// ── Hero Slide ─────────────────────────────────────────────────────────────────
class HeroSlide {
  const HeroSlide({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
    this.imagePath,
    this.actionLabel,
    this.actionRoute,
  });

  final String title;
  final String subtitle;
  final List<Color> gradient;
  final IconData icon;
  /// Local asset path, e.g. 'assets/images/image1.jpg'
  final String? imagePath;
  final String? actionLabel;
  final String? actionRoute;
}

// ── Category Item ──────────────────────────────────────────────────────────────
class CategoryItem {
  const CategoryItem({
    required this.label,
    required this.icon,
    required this.color,
    this.route,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String? route;
}

// ── Pandit Model (mock) ────────────────────────────────────────────────────────
class MockPandit {
  const MockPandit({
    required this.id,
    required this.name,
    required this.speciality,
    required this.rating,
    required this.reviewCount,
    required this.experience,
    required this.isOnline,
    this.avatarInitials,
    this.avatarColor,
    this.imagePath,
  });

  final String id;
  final String name;
  final String speciality;
  final double rating;
  final int reviewCount;
  final int experience; // years
  final bool isOnline;
  final String? avatarInitials;
  final Color? avatarColor;
  /// Optional local asset image path, e.g. 'assets/images/image12.jpg'
  final String? imagePath;
}

// ── Package Model (mock) ───────────────────────────────────────────────────────
class MockPackage {
  const MockPackage({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.durationMinutes,
    required this.isOnline,
    required this.categoryIcon,
    required this.badgeLabel,
    this.badgeColor,
    this.isPopular = false,
  });

  final String id;
  final String title;
  final String description;
  final double price;
  final int durationMinutes;
  final bool isOnline;
  final IconData categoryIcon;
  final String badgeLabel;
  final Color? badgeColor;
  final bool isPopular;
}
