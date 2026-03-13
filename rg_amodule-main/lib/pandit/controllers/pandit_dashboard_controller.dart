// lib/pandit/controllers/pandit_dashboard_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../booking/models/booking_status.dart';
import '../models/pandit_dashboard_models.dart';
import '../repository/pandit_repository.dart';

// ── Dashboard State ───────────────────────────────────────────────────────────

class PanditDashboardState {
  const PanditDashboardState({
    this.assignments = const [],
    this.profile,
    this.earnings,
    this.consultationEnabled = false,
    this.loading = false,
    this.togglingConsultation = false,
    this.error,
  });

  final List<PanditAssignment> assignments;
  final PanditProfile? profile;
  final EarningsSummary? earnings;
  final bool consultationEnabled;
  final bool loading;
  final bool togglingConsultation;
  final String? error;

  // ── Filtered views ─────────────────────────────────────────────────────────

  List<PanditAssignment> get newRequests =>
      assignments.where((a) => a.isPendingAction).toList();

  List<PanditAssignment> get activeAssignments =>
      assignments.where((a) => a.isActive).toList();

  List<PanditAssignment> get completedAssignments =>
      assignments.where((a) => a.isCompleted).toList();

  // ── Summary counts ─────────────────────────────────────────────────────────

  int get pendingCount => newRequests.length;
  int get activeCount => activeAssignments.length;
  int get completedCount => completedAssignments.length;
  int get totalCount => assignments.length;

  PanditDashboardState copyWith({
    List<PanditAssignment>? assignments,
    PanditProfile? profile,
    EarningsSummary? earnings,
    bool? consultationEnabled,
    bool? loading,
    bool? togglingConsultation,
    String? error,
    bool clearError = false,
  }) =>
      PanditDashboardState(
        assignments: assignments ?? this.assignments,
        profile: profile ?? this.profile,
        earnings: earnings ?? this.earnings,
        consultationEnabled:
            consultationEnabled ?? this.consultationEnabled,
        loading: loading ?? this.loading,
        togglingConsultation:
            togglingConsultation ?? this.togglingConsultation,
        error: clearError ? null : error ?? this.error,
      );
}

// ── Controller ────────────────────────────────────────────────────────────────

class PanditDashboardController
    extends StateNotifier<PanditDashboardState> {
  PanditDashboardController(this._repo, this._panditId)
      : super(const PanditDashboardState()) {
    load();
  }

  final IPanditDashboardRepository _repo;
  final String _panditId;

  // ── Load all dashboard data ───────────────────────────────────────────────

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final results = await Future.wait([
        _repo.fetchAssignments(_panditId),
        _repo.fetchProfile(_panditId),
        _repo.fetchEarnings(_panditId),
      ]);
      final assignments = results[0] as List<PanditAssignment>;
      final profile = results[1] as PanditProfile;
      final earnings = results[2] as EarningsSummary;
      state = state.copyWith(
        assignments: assignments,
        profile: profile,
        earnings: earnings,
        consultationEnabled: profile.consultationEnabled,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Failed to load dashboard. Please try again.',
      );
    }
  }

  // ── Accept assignment ─────────────────────────────────────────────────────

  Future<void> acceptAssignment(String bookingId) async {
    try {
      await _repo.acceptAssignment(bookingId);
      final updated = state.assignments.map((a) {
        if (a.booking.id != bookingId) return a;
        return a.copyWith(panditAccepted: true);
      }).toList();
      state = state.copyWith(assignments: updated, clearError: true);
      // Refresh earnings after status change
      _refreshEarnings();
    } catch (_) {
      state = state.copyWith(error: 'Failed to accept booking.');
    }
  }

  // ── Reject assignment ─────────────────────────────────────────────────────

  Future<void> rejectAssignment(String bookingId) async {
    try {
      await _repo.rejectAssignment(bookingId);
      // Remove from locally tracked assignments
      final updated = assignments..removeWhere((a) => a.booking.id == bookingId);
      state = state.copyWith(assignments: List.unmodifiable(updated), clearError: true);
    } catch (_) {
      state = state.copyWith(error: 'Failed to reject booking.');
    }
  }

  List<PanditAssignment> get assignments =>
      List<PanditAssignment>.from(state.assignments);

  // ── Update booking status ─────────────────────────────────────────────────

  Future<void> updateStatus(
      String bookingId, BookingStatus newStatus) async {
    try {
      await _repo.updateStatus(bookingId, newStatus);
      final updated = state.assignments.map((a) {
        if (a.booking.id != bookingId) return a;
        return a.copyWith(
          booking: a.booking.copyWith(status: newStatus),
        );
      }).toList();
      state = state.copyWith(assignments: updated, clearError: true);
      _refreshEarnings();
    } catch (_) {
      state = state.copyWith(error: 'Failed to update booking status.');
    }
  }

  // ── Toggle consultation ───────────────────────────────────────────────────

  Future<void> toggleConsultation() async {
    final next = !state.consultationEnabled;
    state = state.copyWith(togglingConsultation: true);
    try {
      await _repo.setConsultationEnabled(_panditId, enabled: next);
      state = state.copyWith(
        consultationEnabled: next,
        togglingConsultation: false,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        togglingConsultation: false,
        error: 'Failed to update consultation status.',
      );
    }
  }

  // ── Refresh earnings ──────────────────────────────────────────────────────

  Future<void> _refreshEarnings() async {
    try {
      final earnings = await _repo.fetchEarnings(_panditId);
      state = state.copyWith(earnings: earnings);
    } catch (_) {}
  }

  // ── Convenience lookup ────────────────────────────────────────────────────

  PanditAssignment? findById(String bookingId) {
    try {
      return state.assignments.firstWhere((a) => a.booking.id == bookingId);
    } catch (_) {
      return null;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}
