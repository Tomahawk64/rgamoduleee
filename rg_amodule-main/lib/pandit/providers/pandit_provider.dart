// lib/pandit/providers/pandit_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../controllers/pandit_dashboard_controller.dart';
import '../models/pandit_dashboard_models.dart';
import '../repository/pandit_repository.dart';
import '../repository/supabase_pandit_repository.dart';

// ── Repository ─────────────────────────────────────────────────────────────────

final panditDashboardRepositoryProvider =
    Provider<IPanditDashboardRepository>(
  (ref) => SupabasePanditDashboardRepository(),
);

// ── Dashboard ─────────────────────────────────────────────────────────────────

/// Keyed by panditId so the dashboard refreshes if a different pandit logs in.
final panditDashboardProvider = StateNotifierProvider.autoDispose<
    PanditDashboardController, PanditDashboardState>(
  (ref) {
    final repo = ref.watch(panditDashboardRepositoryProvider);
    // Use logged-in pandit's ID; fall back to demo ID for development
    final user = ref.watch(currentUserProvider);
    final panditId = (user?.id.isNotEmpty == true) ? user!.id : 'mock_pandit';
    return PanditDashboardController(repo, panditId);
  },
);

// ── Convenience selectors ─────────────────────────────────────────────────────

final panditNewRequestsProvider = Provider.autoDispose<List<PanditAssignment>>(
  (ref) => ref.watch(panditDashboardProvider).newRequests,
);

final panditActiveAssignmentsProvider =
    Provider.autoDispose<List<PanditAssignment>>(
  (ref) => ref.watch(panditDashboardProvider).activeAssignments,
);

final panditCompletedAssignmentsProvider =
    Provider.autoDispose<List<PanditAssignment>>(
  (ref) => ref.watch(panditDashboardProvider).completedAssignments,
);

final panditProfileProvider = Provider.autoDispose<PanditProfile?>(
  (ref) => ref.watch(panditDashboardProvider).profile,
);

final panditEarningsProvider = Provider.autoDispose<EarningsSummary?>(
  (ref) => ref.watch(panditDashboardProvider).earnings,
);

final panditConsultationEnabledProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(panditDashboardProvider).consultationEnabled,
);
