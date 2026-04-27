// test/admin/admin_statistics_test.dart
// Automated tests for admin statistics feature

import 'package:flutter_test/flutter_test.dart';
import 'package:saralpooja/admin/models/booking_statistics_models.dart';

void main() {
  group('BookingStatistics Model Tests', () {
    test('BookingStatistics creation', () {
      final stats = BookingStatistics(
        totalBookings: 100,
        completedBookings: 80,
        cancelledBookings: 15,
        pendingBookings: 5,
        monthlyStats: MonthlyStatistics(
          month: 4,
          year: 2026,
          totalBookings: 30,
          completedBookings: 25,
          cancelledBookings: 3,
          pendingBookings: 2,
        ),
        weeklyStats: WeeklyStatistics(
          weekNumber: 16,
          year: 2026,
          totalBookings: 8,
          completedBookings: 6,
          cancelledBookings: 1,
          pendingBookings: 1,
        ),
      );
      
      expect(stats.totalBookings, 100);
      expect(stats.completedBookings, 80);
      expect(stats.cancelledBookings, 15);
      expect(stats.pendingBookings, 5);
    });

    test('MonthlyStatistics creation and JSON', () {
      final monthly = MonthlyStatistics(
        month: 4,
        year: 2026,
        totalBookings: 30,
        completedBookings: 25,
        cancelledBookings: 3,
        pendingBookings: 2,
      );
      
      expect(monthly.month, 4);
      expect(monthly.year, 2026);
      expect(monthly.monthName, 'April');
      expect(monthly.totalBookings, 30);
      
      final json = monthly.toJson();
      expect(json['month'], 4);
      expect(json['year'], 2026);
      expect(json['total_bookings'], 30);
    });

    test('WeeklyStatistics creation and JSON', () {
      final weekly = WeeklyStatistics(
        weekNumber: 16,
        year: 2026,
        totalBookings: 8,
        completedBookings: 6,
        cancelledBookings: 1,
        pendingBookings: 1,
      );
      
      expect(weekly.weekNumber, 16);
      expect(weekly.year, 2026);
      expect(weekly.totalBookings, 8);
      
      final json = weekly.toJson();
      expect(json['week_number'], 16);
      expect(json['year'], 2026);
    });

    test('PanditBookingStats creation', () {
      final panditStats = PanditBookingStats(
        panditId: 'pandit-123',
        panditName: 'Test Pandit',
        statistics: BookingStatistics(
          totalBookings: 50,
          completedBookings: 40,
          cancelledBookings: 5,
          pendingBookings: 5,
          monthlyStats: MonthlyStatistics(
            month: 4,
            year: 2026,
            totalBookings: 10,
            completedBookings: 8,
            cancelledBookings: 1,
            pendingBookings: 1,
          ),
          weeklyStats: WeeklyStatistics(
            weekNumber: 16,
            year: 2026,
            totalBookings: 3,
            completedBookings: 2,
            cancelledBookings: 0,
            pendingBookings: 1,
          ),
        ),
      );
      
      expect(panditStats.panditId, 'pandit-123');
      expect(panditStats.panditName, 'Test Pandit');
      expect(panditStats.statistics.totalBookings, 50);
    });

    test('UserBookingStats creation', () {
      final userStats = UserBookingStats(
        userId: 'user-123',
        userName: 'Test User',
        statistics: BookingStatistics(
          totalBookings: 20,
          completedBookings: 15,
          cancelledBookings: 3,
          pendingBookings: 2,
          monthlyStats: MonthlyStatistics(
            month: 4,
            year: 2026,
            totalBookings: 5,
            completedBookings: 4,
            cancelledBookings: 1,
            pendingBookings: 0,
          ),
          weeklyStats: WeeklyStatistics(
            weekNumber: 16,
            year: 2026,
            totalBookings: 2,
            completedBookings: 1,
            cancelledBookings: 1,
            pendingBookings: 0,
          ),
        ),
      );
      
      expect(userStats.userId, 'user-123');
      expect(userStats.userName, 'Test User');
      expect(userStats.statistics.totalBookings, 20);
    });

    test('BookingStatistics fromJson', () {
      final json = {
        'total_bookings': 100,
        'completed_bookings': 80,
        'cancelled_bookings': 15,
        'pending_bookings': 5,
        'monthly_stats': {
          'month': 4,
          'year': 2026,
          'total_bookings': 30,
          'completed_bookings': 25,
          'cancelled_bookings': 3,
          'pending_bookings': 2,
        },
        'weekly_stats': {
          'week_number': 16,
          'year': 2026,
          'total_bookings': 8,
          'completed_bookings': 6,
          'cancelled_bookings': 1,
          'pending_bookings': 1,
        },
      };
      
      final stats = BookingStatistics.fromJson(json);
      expect(stats.totalBookings, 100);
      expect(stats.completedBookings, 80);
      expect(stats.monthlyStats.month, 4);
      expect(stats.weeklyStats.weekNumber, 16);
    });

    test('PanditBookingStats fromJson', () {
      final json = {
        'pandit_id': 'pandit-123',
        'pandit_name': 'Test Pandit',
        'statistics': {
          'total_bookings': 50,
          'completed_bookings': 40,
          'cancelled_bookings': 5,
          'pending_bookings': 5,
          'monthly_stats': {
            'month': 4,
            'year': 2026,
            'total_bookings': 10,
            'completed_bookings': 8,
            'cancelled_bookings': 1,
            'pending_bookings': 1,
          },
          'weekly_stats': {
            'week_number': 16,
            'year': 2026,
            'total_bookings': 3,
            'completed_bookings': 2,
            'cancelled_bookings': 0,
            'pending_bookings': 1,
          },
        },
      };
      
      final stats = PanditBookingStats.fromJson(json);
      expect(stats.panditId, 'pandit-123');
      expect(stats.panditName, 'Test Pandit');
      expect(stats.statistics.totalBookings, 50);
    });

    test('MonthlyStatistics monthName for all months', () {
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      
      for (var i = 1; i <= 12; i++) {
        final stats = MonthlyStatistics(
          month: i,
          year: 2026,
          totalBookings: 0,
          completedBookings: 0,
          cancelledBookings: 0,
          pendingBookings: 0,
        );
        expect(stats.monthName, months[i - 1]);
      }
    });

    test('WeeklyStatistics currentWeekNumber calculation', () {
      final weekNum = WeeklyStatistics.currentWeekNumber();
      expect(weekNum, isPositive);
      expect(weekNum, lessThanOrEqualTo(53)); // Max weeks in a year
    });
  });
}
