// lib/admin/models/admin_models.dart
//
// Domain models for the Admin Dashboard module.

import 'package:flutter/material.dart';
import '../../booking/models/booking_status.dart';

// ── Pooja / Package ───────────────────────────────────────────────────────────

class AdminPooja {
  const AdminPooja({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    this.imageUrl,
    required this.basePrice,
    required this.durationMinutes,
    required this.isActive,
    required this.isOnlineAvailable,
    required this.tags,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final String? imageUrl;
  final double basePrice;
  final int durationMinutes;
  final bool isActive;
  final bool isOnlineAvailable;
  final List<String> tags;
  final DateTime createdAt;

  String get durationLabel {
    if (durationMinutes < 60) return '$durationMinutes min';
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  AdminPooja copyWith({
    String? title,
    String? category,
    String? description,
    String? imageUrl,
    double? basePrice,
    int? durationMinutes,
    bool? isActive,
    bool? isOnlineAvailable,
    List<String>? tags,
  }) =>
      AdminPooja(
        id: id,
        title: title ?? this.title,
        category: category ?? this.category,
        description: description ?? this.description,
        imageUrl: imageUrl ?? this.imageUrl,
        basePrice: basePrice ?? this.basePrice,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        isActive: isActive ?? this.isActive,
        isOnlineAvailable: isOnlineAvailable ?? this.isOnlineAvailable,
        tags: tags ?? this.tags,
        createdAt: createdAt,
      );
}

// ── Consultation Rate Tier ────────────────────────────────────────────────────

class AdminRate {
  const AdminRate({required this.durationMinutes, required this.pricePaise});

  final int durationMinutes;
  final int pricePaise;

  double get priceRupees => pricePaise / 100;
  String get label => '$durationMinutes min · ₹${priceRupees.toStringAsFixed(0)}';

  AdminRate copyWith({int? durationMinutes, int? pricePaise}) => AdminRate(
        durationMinutes: durationMinutes ?? this.durationMinutes,
        pricePaise: pricePaise ?? this.pricePaise,
      );
}

// ── Pandit ────────────────────────────────────────────────────────────────────

class AdminPandit {
  const AdminPandit({
    required this.id,
    required this.name,
    required this.specialties,
    required this.languages,
    required this.rating,
    required this.totalBookings,
    required this.totalSessions,
    required this.isActive,
    required this.consultationEnabled,
    required this.consultationRates,
    required this.yearsExperience,
    required this.joinedAt,
    this.email,
    this.phone,
  });

  final String id;
  final String name;
  final List<String> specialties;
  final List<String> languages;
  final double rating;
  final int totalBookings;
  final int totalSessions;
  final bool isActive;
  final bool consultationEnabled;
  final List<AdminRate> consultationRates;
  final int yearsExperience;
  final DateTime joinedAt;
  final String? email;
  final String? phone;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, 2).toUpperCase();
  }

  AdminPandit copyWith({
    String? name,
    List<String>? specialties,
    List<String>? languages,
    bool? isActive,
    bool? consultationEnabled,
    List<AdminRate>? consultationRates,
    int? yearsExperience,
    String? email,
    String? phone,
  }) =>
      AdminPandit(
        id: id,
        name: name ?? this.name,
        specialties: specialties ?? this.specialties,
        languages: languages ?? this.languages,
        rating: rating,
        totalBookings: totalBookings,
        totalSessions: totalSessions,
        isActive: isActive ?? this.isActive,
        consultationEnabled: consultationEnabled ?? this.consultationEnabled,
        consultationRates: consultationRates ?? this.consultationRates,
        yearsExperience: yearsExperience ?? this.yearsExperience,
        joinedAt: joinedAt,
        email: email ?? this.email,
        phone: phone ?? this.phone,
      );
}

// ── Booking Row ───────────────────────────────────────────────────────────────

class AdminBookingRow {
  const AdminBookingRow({
    required this.id,
    required this.packageTitle,
    required this.clientName,
    required this.panditName,
    required this.status,
    required this.amount,
    required this.isPaid,
    required this.isOnline,
    required this.scheduledAt,
    this.userId,
    this.panditId,
  });

  final String id;
  final String packageTitle;
  final String clientName;
  final String? panditName;
  final BookingStatus status;
  final double amount;
  final bool isPaid;
  final bool isOnline;
  final DateTime scheduledAt;
  final String? userId;
  final String? panditId;

  String get formattedDate {
    final d = scheduledAt;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  AdminBookingRow copyWith({String? panditName, String? panditId}) =>
      AdminBookingRow(
        id: id,
        packageTitle: packageTitle,
        clientName: clientName,
        panditName: panditName ?? this.panditName,
        status: status,
        amount: amount,
        isPaid: isPaid,
        isOnline: isOnline,
        scheduledAt: scheduledAt,
        userId: userId,
        panditId: panditId ?? this.panditId,
      );
}

// ── Consultation Row ──────────────────────────────────────────────────────────

enum AdminSessionStatus { active, ended, expired, refunded }

extension AdminSessionStatusX on AdminSessionStatus {
  String get label {
    switch (this) {
      case AdminSessionStatus.active:   return 'Active';
      case AdminSessionStatus.ended:    return 'Ended';
      case AdminSessionStatus.expired:  return 'Expired';
      case AdminSessionStatus.refunded: return 'Refunded';
    }
  }

  Color get color {
    switch (this) {
      case AdminSessionStatus.active:   return const Color(0xFF10B981);
      case AdminSessionStatus.ended:    return const Color(0xFF6B7280);
      case AdminSessionStatus.expired:  return const Color(0xFFF59E0B);
      case AdminSessionStatus.refunded: return const Color(0xFF3B82F6);
    }
  }
}

class AdminConsultationRow {
  const AdminConsultationRow({
    required this.id,
    required this.panditName,
    required this.clientName,
    required this.status,
    required this.durationMinutes,
    required this.amountPaise,
    required this.startedAt,
  });

  final String id;
  final String panditName;
  final String clientName;
  final AdminSessionStatus status;
  final int durationMinutes;
  final int amountPaise;
  final DateTime startedAt;

  double get amountRupees => amountPaise / 100;
  String get formattedAmount => '₹${amountRupees.toStringAsFixed(0)}';

  String get formattedDate {
    final d = startedAt;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ── Reports ───────────────────────────────────────────────────────────────────

class TopPandit {
  const TopPandit({
    required this.name,
    required this.bookings,
    required this.revenuePaise,
    required this.rating,
  });

  final String name;
  final int bookings;
  final int revenuePaise;
  final double rating;

  double get revenueRupees => revenuePaise / 100;
  String get formattedRevenue => '₹${revenueRupees.toStringAsFixed(0)}';
}

class MonthlyPoint {
  const MonthlyPoint({
    required this.month,
    required this.revenuePaise,
    required this.bookings,
  });

  final String month;
  final int revenuePaise;
  final int bookings;

  double get revenueRupees => revenuePaise / 100;
}

class AdminReport {
  const AdminReport({
    required this.totalBookings,
    required this.monthlyBookings,
    required this.totalConsultations,
    required this.monthlyConsultations,
    required this.monthlyRevenuePaise,
    required this.totalRevenuePaise,
    required this.activeUsers,
    required this.totalUsers,
    required this.activePandits,
    required this.topPandits,
    required this.revenueHistory,
  });

  final int totalBookings;
  final int monthlyBookings;
  final int totalConsultations;
  final int monthlyConsultations;
  final int monthlyRevenuePaise;
  final int totalRevenuePaise;
  final int activeUsers;
  final int totalUsers;
  final int activePandits;
  final List<TopPandit> topPandits;
  final List<MonthlyPoint> revenueHistory;

  double get monthlyRevenueRupees => monthlyRevenuePaise / 100;
  double get totalRevenueRupees => totalRevenuePaise / 100;

  String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  String get formattedMonthlyRevenue => _fmt(monthlyRevenueRupees);
  String get formattedTotalRevenue => _fmt(totalRevenueRupees);
}

// ── Admin User ────────────────────────────────────────────────────────────────

class AdminUser {
  const AdminUser({
    required this.id,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.phone,
    this.email,
  });

  final String id;
  final String fullName;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final String? phone;
  final String? email;

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (fullName.isEmpty) return '?';
    return fullName.substring(0, fullName.length.clamp(1, 2)).toUpperCase();
  }

  Color get roleColor {
    switch (role) {
      case 'admin':  return const Color(0xFFEF4444);
      case 'pandit': return const Color(0xFF8B5CF6);
      default:       return const Color(0xFF10B981);
    }
  }

  AdminUser copyWith({String? role, bool? isActive}) => AdminUser(
        id: id,
        fullName: fullName,
        role: role ?? this.role,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        phone: phone,
        email: email,
      );
}

// ── Admin Product ─────────────────────────────────────────────────────────────

class AdminProduct {
  const AdminProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.pricePaise,
    required this.category,
    required this.stock,
    required this.isActive,
    required this.isBestSeller,
    required this.createdAt,
    this.imageUrl,
    this.includes = const [],
  });

  final String id;
  final String name;
  final String description;
  final int pricePaise;
  final String category;
  final int stock;
  final bool isActive;
  final bool isBestSeller;
  final DateTime createdAt;
  final String? imageUrl;
  final List<String> includes;

  double get priceRupees => pricePaise / 100;
  String get formattedPrice => '₹${priceRupees.toStringAsFixed(0)}';

  AdminProduct copyWith({
    String? name,
    String? description,
    int? pricePaise,
    String? category,
    int? stock,
    bool? isActive,
    bool? isBestSeller,
    String? imageUrl,
    List<String>? includes,
  }) =>
      AdminProduct(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        pricePaise: pricePaise ?? this.pricePaise,
        category: category ?? this.category,
        stock: stock ?? this.stock,
        isActive: isActive ?? this.isActive,
        isBestSeller: isBestSeller ?? this.isBestSeller,
        createdAt: createdAt,
        imageUrl: imageUrl ?? this.imageUrl,
        includes: includes ?? this.includes,
      );
}

// ── Admin State ───────────────────────────────────────────────────────────────

enum AdminSection { poojas, pandits, bookings, consultations, reports, users, products }

class AdminState {
  const AdminState({
    this.poojas = const [],
    this.pandits = const [],
    this.bookings = const [],
    this.consultations = const [],
    this.users = const [],
    this.products = const [],
    this.report,
    this.loading = false,
    this.error,
    this.sectionLoading = const {},
  });

  final List<AdminPooja> poojas;
  final List<AdminPandit> pandits;
  final List<AdminBookingRow> bookings;
  final List<AdminConsultationRow> consultations;
  final List<AdminUser> users;
  final List<AdminProduct> products;
  final AdminReport? report;
  final bool loading;
  final String? error;
  final Map<AdminSection, bool> sectionLoading;

  bool isSectionLoading(AdminSection s) => sectionLoading[s] ?? false;

  AdminState copyWith({
    List<AdminPooja>? poojas,
    List<AdminPandit>? pandits,
    List<AdminBookingRow>? bookings,
    List<AdminConsultationRow>? consultations,
    List<AdminUser>? users,
    List<AdminProduct>? products,
    AdminReport? report,
    bool? loading,
    String? error,
    Map<AdminSection, bool>? sectionLoading,
  }) =>
      AdminState(
        poojas: poojas ?? this.poojas,
        pandits: pandits ?? this.pandits,
        bookings: bookings ?? this.bookings,
        consultations: consultations ?? this.consultations,
        users: users ?? this.users,
        products: products ?? this.products,
        report: report ?? this.report,
        loading: loading ?? this.loading,
        error: error,
        sectionLoading: sectionLoading ?? this.sectionLoading,
      );
}
