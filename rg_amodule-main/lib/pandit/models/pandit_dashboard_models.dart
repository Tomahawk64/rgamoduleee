// lib/pandit/models/pandit_dashboard_models.dart

import '../../booking/models/booking_model.dart';
import '../../booking/models/booking_status.dart';

// ── Pandit Assignment ─────────────────────────────────────────────────────────
/// Wraps a [BookingModel] with pandit-specific acceptance state.
class PanditAssignment {
  const PanditAssignment({
    required this.booking,
    this.panditAccepted = false,
  });

  final BookingModel booking;

  /// True once the pandit has explicitly accepted the assignment.
  final bool panditAccepted;

  bool get isPendingAction =>
      booking.status == BookingStatus.assigned && !panditAccepted;

  bool get isActive =>
      panditAccepted && booking.status == BookingStatus.assigned;

  bool get isCompleted => booking.status == BookingStatus.completed;
  bool get isCancelled => booking.status == BookingStatus.cancelled;

  PanditAssignment copyWith({BookingModel? booking, bool? panditAccepted}) =>
      PanditAssignment(
        booking: booking ?? this.booking,
        panditAccepted: panditAccepted ?? this.panditAccepted,
      );
}

// ── Earnings Summary ──────────────────────────────────────────────────────────
class EarningsSummary {
  const EarningsSummary({
    required this.totalEarnedPaise,
    required this.thisMonthPaise,
    required this.pendingPayoutPaise,
    required this.completedCount,
    required this.thisMonthCount,
  });

  final int totalEarnedPaise;
  final int thisMonthPaise;
  final int pendingPayoutPaise;
  final int completedCount;
  final int thisMonthCount;

  String get formattedTotal => _fmt(totalEarnedPaise);
  String get formattedMonth => _fmt(thisMonthPaise);
  String get formattedPending => _fmt(pendingPayoutPaise);

  static String _fmt(int paise) {
    final r = paise ~/ 100;
    if (r >= 100000) return '₹${(r / 100000).toStringAsFixed(1)}L';
    if (r >= 1000) return '₹${(r / 1000).toStringAsFixed(1)}K';
    return '₹$r';
  }

  static EarningsSummary zero() => const EarningsSummary(
        totalEarnedPaise: 0,
        thisMonthPaise: 0,
        pendingPayoutPaise: 0,
        completedCount: 0,
        thisMonthCount: 0,
      );
}

// ── Pandit Profile Extension ──────────────────────────────────────────────────
class PanditProfile {
  const PanditProfile({
    required this.id,
    required this.name,
    required this.specialties,
    required this.rating,
    required this.totalBookings,
    required this.consultationEnabled,
    required this.yearsExperience,
    required this.languages,
    this.bio,
  });

  final String id;
  final String name;
  final List<String> specialties;
  final double rating;
  final int totalBookings;
  final bool consultationEnabled;
  final int yearsExperience;
  final List<String> languages;
  final String? bio;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  PanditProfile copyWith({bool? consultationEnabled}) => PanditProfile(
        id: id,
        name: name,
        specialties: specialties,
        rating: rating,
        totalBookings: totalBookings,
        consultationEnabled: consultationEnabled ?? this.consultationEnabled,
        yearsExperience: yearsExperience,
        languages: languages,
        bio: bio,
      );
}
