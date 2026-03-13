// lib/admin/providers/admin_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/demo_config.dart';
import '../controllers/admin_controller.dart';
import '../models/admin_models.dart';
import '../repository/admin_repository.dart';
import '../repository/mock_admin_repository.dart';
import '../repository/supabase_admin_repository.dart';
import '../../core/providers/supabase_provider.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final adminRepositoryProvider = Provider<IAdminRepository>((ref) {
  if (DemoConfig.demoMode) return MockAdminRepository();
  return SupabaseAdminRepository(ref.watch(supabaseClientProvider));
});

// ── Main dashboard provider ───────────────────────────────────────────────────

final adminProvider =
    StateNotifierProvider.autoDispose<AdminController, AdminState>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  return AdminController(repo);
});

// ── Derived providers ─────────────────────────────────────────────────────────

final adminPoojasProvider = Provider.autoDispose<List<AdminPooja>>((ref) {
  return ref.watch(adminProvider).poojas;
});

final adminPanditsProvider = Provider.autoDispose<List<AdminPandit>>((ref) {
  return ref.watch(adminProvider).pandits;
});

final adminBookingsProvider =
    Provider.autoDispose<List<AdminBookingRow>>((ref) {
  return ref.watch(adminProvider).bookings;
});

final adminConsultationsProvider =
    Provider.autoDispose<List<AdminConsultationRow>>((ref) {
  return ref.watch(adminProvider).consultations;
});

final adminReportProvider = Provider.autoDispose<AdminReport?>((ref) {
  return ref.watch(adminProvider).report;
});

final adminLoadingProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(adminProvider).loading;
});
