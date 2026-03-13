import 'package:flutter/material.dart';

// ── Booking Status ────────────────────────────────────────────────────────────
enum BookingStatus {
  /// Created but not yet reviewed / assigned.
  pending,

  /// Admin has accepted; awaiting pandit dispatch.
  confirmed,

  /// Pandit has been assigned and notified.
  assigned,

  /// Service rendered successfully.
  completed,

  /// Cancelled by user or admin.
  cancelled,
}

extension BookingStatusX on BookingStatus {
  String get label {
    switch (this) {
      case BookingStatus.pending:   return 'Pending';
      case BookingStatus.confirmed: return 'Confirmed';
      case BookingStatus.assigned:  return 'Assigned';
      case BookingStatus.completed: return 'Completed';
      case BookingStatus.cancelled: return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case BookingStatus.pending:   return const Color(0xFFF59E0B); // amber
      case BookingStatus.confirmed: return const Color(0xFF3B82F6); // blue
      case BookingStatus.assigned:  return const Color(0xFF8B5CF6); // violet
      case BookingStatus.completed: return const Color(0xFF10B981); // green
      case BookingStatus.cancelled: return const Color(0xFFEF4444); // red
    }
  }

  IconData get icon {
    switch (this) {
      case BookingStatus.pending:   return Icons.hourglass_top_rounded;
      case BookingStatus.confirmed: return Icons.check_circle_outline_rounded;
      case BookingStatus.assigned:  return Icons.person_pin_circle_rounded;
      case BookingStatus.completed: return Icons.task_alt_rounded;
      case BookingStatus.cancelled: return Icons.cancel_outlined;
    }
  }

  /// Whether the booking is still actionable (can be cancelled, modified).
  bool get isActive =>
      this == BookingStatus.pending ||
      this == BookingStatus.confirmed ||
      this == BookingStatus.assigned;

  bool get isFinal =>
      this == BookingStatus.completed || this == BookingStatus.cancelled;

  /// Supabase value stored as snake_case string.
  String get dbValue => name; // 'pending', 'confirmed', etc.

  static BookingStatus fromDb(String value) {
    return BookingStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => BookingStatus.pending,
    );
  }
}
