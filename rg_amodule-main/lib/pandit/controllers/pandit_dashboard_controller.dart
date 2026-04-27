// lib/pandit/controllers/pandit_dashboard_controller.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../booking/models/booking_status.dart';
import '../models/pandit_dashboard_models.dart';
import '../repository/pandit_repository.dart';

// ── Dashboard State ───────────────────────────────────────────────────────────

class PanditDashboardState {
  const PanditDashboardState({
    this.assignments = const [],
    this.profile,
    this.consultationEnabled = false,
    this.loading = false,
    this.togglingConsultation = false,
    this.togglingOnline = false,
    this.togglingOfflineBooking = false,
    this.error,
  });

  final List<PanditAssignment> assignments;
  final PanditProfile? profile;
  final bool consultationEnabled;
  final bool loading;
  final bool togglingConsultation;
  final bool togglingOnline;
  final bool togglingOfflineBooking;
  final String? error;

  // ── Filtered views ─────────────────────────────────────────────────────────

  List<PanditAssignment> get activeAssignments =>
      assignments.where((a) => a.isActive).toList();

  List<PanditAssignment> get completedAssignments =>
      assignments.where((a) => a.isCompleted).toList();

  // ── Summary counts ─────────────────────────────────────────────────────────

  int get activeCount => activeAssignments.length;
  int get completedCount => completedAssignments.length;
  int get totalCount => assignments.length;

  PanditDashboardState copyWith({
    List<PanditAssignment>? assignments,
    PanditProfile? profile,
    bool? consultationEnabled,
    bool? loading,
    bool? togglingConsultation,
    bool? togglingOnline,
    bool? togglingOfflineBooking,
    String? error,
    bool clearError = false,
  }) =>
      PanditDashboardState(
        assignments: assignments ?? this.assignments,
        profile: profile ?? this.profile,
        consultationEnabled:
            consultationEnabled ?? this.consultationEnabled,
        loading: loading ?? this.loading,
        togglingConsultation:
            togglingConsultation ?? this.togglingConsultation,
        togglingOnline: togglingOnline ?? this.togglingOnline,
        togglingOfflineBooking: togglingOfflineBooking ?? this.togglingOfflineBooking,
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
      ]);
      final assignments = results[0] as List<PanditAssignment>;
      final profile = results[1] as PanditProfile;
      state = state.copyWith(
        assignments: assignments,
        profile: profile,
        consultationEnabled: profile.consultationEnabled,
        loading: false,
      );
    } catch (e, st) {
      debugPrint('PanditDashboard load() error: $e\n$st');
      state = state.copyWith(
        loading: false,
        error: kDebugMode ? e.toString() : 'Failed to load dashboard. Please try again.',
      );
    }
  }

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
      // Re-read from DB to confirm the write actually persisted
      final profile = await _repo.fetchProfile(_panditId);
      state = state.copyWith(
        profile: profile,
        consultationEnabled: profile.consultationEnabled,
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

  // ── Toggle online status ───────────────────────────────────────────────────

  Future<void> toggleOnlineStatus() async {
    final next = !(state.profile?.isOnline ?? false);
    state = state.copyWith(togglingOnline: true);
    try {
      await _repo.setOnlineStatus(_panditId, isOnline: next);
      // Re-read from DB to confirm the write actually persisted
      final profile = await _repo.fetchProfile(_panditId);
      state = state.copyWith(
        profile: profile,
        togglingOnline: false,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        togglingOnline: false,
        error: 'Failed to update online status.',
      );
    }
  }

  // ── Toggle offline booking ───────────────────────────────────────────────

  Future<void> toggleOfflineBooking() async {
    final next = !(state.profile?.offlineBookingEnabled ?? false);
    state = state.copyWith(togglingOfflineBooking: true);
    try {
      await _repo.setOfflineBookingEnabled(_panditId, enabled: next);
      // Re-read from DB to confirm the write actually persisted
      final profile = await _repo.fetchProfile(_panditId);
      state = state.copyWith(
        profile: profile,
        togglingOfflineBooking: false,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        togglingOfflineBooking: false,
        error: 'Failed to update offline booking status.',
      );
    }
  }

  // ── Upload avatar ─────────────────────────────────────────────────────────

  Future<void> uploadAvatar(String url) async {
    try {
      await _repo.updateAvatarUrl(_panditId, url);
      if (state.profile != null) {
        state = state.copyWith(
          profile: state.profile!.copyWith(avatarUrl: url),
          clearError: true,
        );
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to update photo: ${e.toString()}');
    }
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
