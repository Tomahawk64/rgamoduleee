// lib/pandit/repository/pandit_repository.dart

import '../../booking/models/booking_model.dart';
import '../../booking/models/booking_status.dart';
import '../../booking/models/time_slot_model.dart';
import '../models/pandit_dashboard_models.dart';

// ── Abstract contract ─────────────────────────────────────────────────────────

abstract class IPanditDashboardRepository {
  /// Fetch bookings assigned to [panditId].
  Future<List<PanditAssignment>> fetchAssignments(String panditId);

  /// Accept an assignment (pandit confirms).
  Future<void> acceptAssignment(String bookingId);

  /// Reject an assignment (returns booking to pending pool).
  Future<void> rejectAssignment(String bookingId);

  /// Update booking status (e.g. assigned → completed).
  Future<void> updateStatus(String bookingId, BookingStatus newStatus);

  /// Fetch the pandit's profile.
  Future<PanditProfile> fetchProfile(String panditId);

  /// Toggle online consultation availability.
  Future<void> setConsultationEnabled(String panditId, {required bool enabled});

  /// Compute earnings summary from completed bookings.
  Future<EarningsSummary> fetchEarnings(String panditId);
}

// ── Mock implementation ───────────────────────────────────────────────────────

class MockPanditDashboardRepository implements IPanditDashboardRepository {
  MockPanditDashboardRepository() {
    // Seed assignments for the demo pandit
    _assignments.addAll(_seededAssignments('mock_pandit'));
  }

  final List<PanditAssignment> _assignments = [];

  // ── Abstract implementations ──────────────────────────────────────────────

  @override
  Future<List<PanditAssignment>> fetchAssignments(String panditId) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return List.unmodifiable(
      _assignments.where((a) => a.booking.panditId == panditId).toList(),
    );
  }

  @override
  Future<void> acceptAssignment(String bookingId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final idx = _assignments.indexWhere((a) => a.booking.id == bookingId);
    if (idx >= 0) {
      _assignments[idx] = _assignments[idx].copyWith(panditAccepted: true);
    }
  }

  @override
  Future<void> rejectAssignment(String bookingId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final idx = _assignments.indexWhere((a) => a.booking.id == bookingId);
    if (idx >= 0) {
      _assignments[idx] = _assignments[idx].copyWith(
        booking: _assignments[idx].booking.copyWith(
          status: BookingStatus.pending,
          panditId: '',
          panditName: '',
        ),
        panditAccepted: false,
      );
    }
  }

  @override
  Future<void> updateStatus(String bookingId, BookingStatus newStatus) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final idx = _assignments.indexWhere((a) => a.booking.id == bookingId);
    if (idx >= 0) {
      _assignments[idx] = _assignments[idx].copyWith(
        booking: _assignments[idx].booking.copyWith(status: newStatus),
      );
    }
  }

  @override
  Future<PanditProfile> fetchProfile(String panditId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _kDemoProfile.copyWith();
  }

  @override
  Future<void> setConsultationEnabled(String panditId,
      {required bool enabled}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // In production: update pandit profile in Supabase
  }

  @override
  Future<EarningsSummary> fetchEarnings(String panditId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final now = DateTime.now();
    final mine = _assignments.where((a) => a.booking.panditId == panditId);
    final completed = mine
        .where((a) => a.booking.status == BookingStatus.completed)
        .toList();
    final thisMonth = completed.where((a) =>
        a.booking.date.year == now.year &&
        a.booking.date.month == now.month);
    final totalPaise =
        completed.fold<int>(0, (s, a) => s + (a.booking.amount * 100).round());
    final monthPaise = thisMonth.fold<int>(
        0, (s, a) => s + (a.booking.amount * 100).round());
    // Simulate 80% payout ratio
    final pendingPaise = (totalPaise * 0.20).round();

    return EarningsSummary(
      totalEarnedPaise: totalPaise,
      thisMonthPaise: monthPaise,
      pendingPayoutPaise: pendingPaise,
      completedCount: completed.length,
      thisMonthCount: thisMonth.length,
    );
  }

  // ── Seed helpers ──────────────────────────────────────────────────────────

  static List<PanditAssignment> _seededAssignments(String panditId) {
    final now = DateTime.now();
    return [
      // ── New request (needs acceptance) ──────────────────────────────────
      PanditAssignment(
        booking: BookingModel(
          id: 'pa_001',
          userId: 'user_101',
          packageId: 'pkg_satyanarayan',
          packageTitle: 'Satyanarayan Puja',
          category: 'Puja',
          date: now.add(const Duration(days: 3)),
          slot: const TimeSlot(
            id: 'slot_09',
            startHour: 9, startMinute: 0,
            endHour: 11,  endMinute: 0,
          ),
          location: const BookingLocation(
            addressLine1: '14, Shanti Nagar',
            city: 'Pune',
            pincode: '411001',
          ),
          status: BookingStatus.assigned,
          amount: 2100,
          createdAt: now.subtract(const Duration(hours: 2)),
          panditId: panditId,
          panditName: 'Pt. Ramesh Sharma',
          isPaid: true,
        ),
        panditAccepted: false,
      ),
      PanditAssignment(
        booking: BookingModel(
          id: 'pa_002',
          userId: 'user_102',
          packageId: 'pkg_grihpravesh',
          packageTitle: 'Grih Pravesh Puja',
          category: 'Griha Pravesh',
          date: now.add(const Duration(days: 5)),
          slot: const TimeSlot(
            id: 'slot_07',
            startHour: 7, startMinute: 30,
            endHour: 9,   endMinute: 30,
          ),
          location: const BookingLocation(
            addressLine1: 'Plot 22, Sector 7',
            city: 'Noida',
            pincode: '201301',
          ),
          status: BookingStatus.assigned,
          amount: 3500,
          createdAt: now.subtract(const Duration(hours: 5)),
          panditId: panditId,
          panditName: 'Pt. Ramesh Sharma',
          isPaid: true,
        ),
        panditAccepted: false,
      ),

      // ── Active (accepted, upcoming) ──────────────────────────────────────
      PanditAssignment(
        booking: BookingModel(
          id: 'pa_003',
          userId: 'user_103',
          packageId: 'pkg_navgraha',
          packageTitle: 'Navgraha Shanti Puja',
          category: 'Puja',
          date: now.add(const Duration(days: 1)),
          slot: const TimeSlot(
            id: 'slot_08',
            startHour: 8, startMinute: 0,
            endHour: 10,  endMinute: 0,
          ),
          location: const BookingLocation(
            addressLine1: '7, MG Road',
            city: 'Mumbai',
            pincode: '400001',
          ),
          status: BookingStatus.assigned,
          amount: 1800,
          createdAt: now.subtract(const Duration(days: 1)),
          panditId: panditId,
          panditName: 'Pt. Ramesh Sharma',
          isPaid: true,
        ),
        panditAccepted: true,
      ),
      PanditAssignment(
        booking: BookingModel(
          id: 'pa_004',
          userId: 'user_104',
          packageId: 'pkg_havan',
          packageTitle: 'Havan Ceremony',
          category: 'Havan',
          date: now.add(const Duration(days: 7)),
          slot: const TimeSlot(
            id: 'slot_10',
            startHour: 10, startMinute: 0,
            endHour: 12,   endMinute: 0,
          ),
          location: const BookingLocation(isOnline: true),
          status: BookingStatus.assigned,
          amount: 1500,
          createdAt: now.subtract(const Duration(days: 2)),
          panditId: panditId,
          panditName: 'Pt. Ramesh Sharma',
          isPaid: false,
        ),
        panditAccepted: true,
      ),

      // ── Completed ────────────────────────────────────────────────────────
      PanditAssignment(
        booking: BookingModel(
          id: 'pa_005',
          userId: 'user_105',
          packageId: 'pkg_satyanarayan',
          packageTitle: 'Satyanarayan Puja',
          category: 'Puja',
          date: now.subtract(const Duration(days: 5)),
          slot: const TimeSlot(
            id: 'slot_09',
            startHour: 9, startMinute: 0,
            endHour: 11,  endMinute: 0,
          ),
          location: const BookingLocation(
            addressLine1: '3, Laxmi Vihar',
            city: 'Jaipur',
            pincode: '302001',
          ),
          status: BookingStatus.completed,
          amount: 2100,
          createdAt: now.subtract(const Duration(days: 7)),
          panditId: panditId,
          panditName: 'Pt. Ramesh Sharma',
          isPaid: true,
        ),
        panditAccepted: true,
      ),
      PanditAssignment(
        booking: BookingModel(
          id: 'pa_006',
          userId: 'user_106',
          packageId: 'pkg_marriage',
          packageTitle: 'Vivah Sanskar',
          category: 'Marriage',
          date: now.subtract(const Duration(days: 12)),
          slot: const TimeSlot(
            id: 'slot_07',
            startHour: 7, startMinute: 0,
            endHour: 12,  endMinute: 0,
          ),
          location: const BookingLocation(
            addressLine1: 'Patel Marriage Hall',
            city: 'Ahmedabad',
            pincode: '380001',
          ),
          status: BookingStatus.completed,
          amount: 8500,
          createdAt: now.subtract(const Duration(days: 14)),
          panditId: panditId,
          panditName: 'Pt. Ramesh Sharma',
          isPaid: true,
        ),
        panditAccepted: true,
      ),
      PanditAssignment(
        booking: BookingModel(
          id: 'pa_007',
          userId: 'user_107',
          packageId: 'pkg_katha',
          packageTitle: 'Sunderkand Katha',
          category: 'Katha',
          date: now.subtract(const Duration(days: 20)),
          slot: const TimeSlot(
            id: 'slot_18',
            startHour: 18, startMinute: 0,
            endHour: 21,   endMinute: 0,
          ),
          location: const BookingLocation(
            addressLine1: '55, Ram Nagar',
            city: 'Lucknow',
            pincode: '226001',
          ),
          status: BookingStatus.completed,
          amount: 1200,
          createdAt: now.subtract(const Duration(days: 22)),
          panditId: panditId,
          panditName: 'Pt. Ramesh Sharma',
          isPaid: true,
        ),
        panditAccepted: true,
      ),
    ];
  }
}

// ── Demo profile ──────────────────────────────────────────────────────────────

const _kDemoProfile = PanditProfile(
  id: 'mock_pandit',
  name: 'Pt. Ramesh Sharma',
  specialties: ['Satyanarayan Puja', 'Griha Pravesh', 'Havan', 'Navgraha'],
  rating: 4.9,
  totalBookings: 1240,
  consultationEnabled: false,
  yearsExperience: 18,
  languages: ['Hindi', 'Sanskrit', 'Marathi'],
  bio:
      'Vedic scholar with 18 years of experience performing traditional Hindu ceremonies '
      'across Maharashtra and beyond. Trained under Pt. Raghunath Shastri at Kashi '
      'Vidyapeeth. Specialises in Satyanarayan Katha and Griha Pravesh rituals.',
);
