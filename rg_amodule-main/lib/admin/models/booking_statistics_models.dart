// lib/admin/models/booking_statistics_models.dart

// ── Booking Statistics Models ───────────────────────────────────────────────

class BookingStatistics {
  const BookingStatistics({
    required this.totalBookings,
    required this.completedBookings,
    required this.cancelledBookings,
    required this.pendingBookings,
    required this.monthlyStats,
    required this.weeklyStats,
  });

  final int totalBookings;
  final int completedBookings;
  final int cancelledBookings;
  final int pendingBookings;
  final MonthlyStatistics monthlyStats;
  final WeeklyStatistics weeklyStats;

  factory BookingStatistics.fromJson(Map<String, dynamic> json) {
    return BookingStatistics(
      totalBookings: json['total_bookings'] as int? ?? 0,
      completedBookings: json['completed_bookings'] as int? ?? 0,
      cancelledBookings: json['cancelled_bookings'] as int? ?? 0,
      pendingBookings: json['pending_bookings'] as int? ?? 0,
      monthlyStats: MonthlyStatistics.fromJson(
        json['monthly_stats'] as Map<String, dynamic>? ?? {},
      ),
      weeklyStats: WeeklyStatistics.fromJson(
        json['weekly_stats'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_bookings': totalBookings,
      'completed_bookings': completedBookings,
      'cancelled_bookings': cancelledBookings,
      'pending_bookings': pendingBookings,
      'monthly_stats': monthlyStats.toJson(),
      'weekly_stats': weeklyStats.toJson(),
    };
  }
}

class MonthlyStatistics {
  const MonthlyStatistics({
    required this.month,
    required this.year,
    required this.totalBookings,
    required this.completedBookings,
    required this.cancelledBookings,
    required this.pendingBookings,
  });

  final int month;
  final int year;
  final int totalBookings;
  final int completedBookings;
  final int cancelledBookings;
  final int pendingBookings;

  factory MonthlyStatistics.fromJson(Map<String, dynamic> json) {
    return MonthlyStatistics(
      month: json['month'] as int? ?? DateTime.now().month,
      year: json['year'] as int? ?? DateTime.now().year,
      totalBookings: json['total_bookings'] as int? ?? 0,
      completedBookings: json['completed_bookings'] as int? ?? 0,
      cancelledBookings: json['cancelled_bookings'] as int? ?? 0,
      pendingBookings: json['pending_bookings'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'year': year,
      'total_bookings': totalBookings,
      'completed_bookings': completedBookings,
      'cancelled_bookings': cancelledBookings,
      'pending_bookings': pendingBookings,
    };
  }

  String get monthName {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}

class WeeklyStatistics {
  const WeeklyStatistics({
    required this.weekNumber,
    required this.year,
    required this.totalBookings,
    required this.completedBookings,
    required this.cancelledBookings,
    required this.pendingBookings,
  });

  final int weekNumber;
  final int year;
  final int totalBookings;
  final int completedBookings;
  final int cancelledBookings;
  final int pendingBookings;

  factory WeeklyStatistics.fromJson(Map<String, dynamic> json) {
    return WeeklyStatistics(
      weekNumber: json['week_number'] as int? ?? currentWeekNumber(),
      year: json['year'] as int? ?? DateTime.now().year,
      totalBookings: json['total_bookings'] as int? ?? 0,
      completedBookings: json['completed_bookings'] as int? ?? 0,
      cancelledBookings: json['cancelled_bookings'] as int? ?? 0,
      pendingBookings: json['pending_bookings'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'week_number': weekNumber,
      'year': year,
      'total_bookings': totalBookings,
      'completed_bookings': completedBookings,
      'cancelled_bookings': cancelledBookings,
      'pending_bookings': pendingBookings,
    };
  }

  static int currentWeekNumber() {
    final now = DateTime.now();
    final firstDayOfYear = DateTime(now.year, 1, 1);
    final dayOfYear = now.difference(firstDayOfYear).inDays;
    return ((dayOfYear + firstDayOfYear.weekday - 1) / 7).floor() + 1;
  }
}

class PanditBookingStats {
  const PanditBookingStats({
    required this.panditId,
    required this.panditName,
    required this.statistics,
  });

  final String panditId;
  final String panditName;
  final BookingStatistics statistics;

  factory PanditBookingStats.fromJson(Map<String, dynamic> json) {
    return PanditBookingStats(
      panditId: json['pandit_id'] as String,
      panditName: json['pandit_name'] as String? ?? 'Unknown',
      statistics: BookingStatistics.fromJson(
        json['statistics'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pandit_id': panditId,
      'pandit_name': panditName,
      'statistics': statistics.toJson(),
    };
  }
}

class UserBookingStats {
  const UserBookingStats({
    required this.userId,
    required this.userName,
    required this.statistics,
  });

  final String userId;
  final String userName;
  final BookingStatistics statistics;

  factory UserBookingStats.fromJson(Map<String, dynamic> json) {
    return UserBookingStats(
      userId: json['user_id'] as String,
      userName: json['user_name'] as String? ?? 'Unknown',
      statistics: BookingStatistics.fromJson(
        json['statistics'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'statistics': statistics.toJson(),
    };
  }
}
