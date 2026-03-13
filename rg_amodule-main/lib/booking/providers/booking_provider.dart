import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/demo_config.dart';
import '../../core/providers/supabase_provider.dart';
import '../controllers/booking_controller.dart';
import '../models/booking_model.dart';
import '../repository/booking_repository.dart';
import '../../packages/models/package_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────

/// Uses [MockBookingRepository] in demo mode, Supabase otherwise.
final bookingRepositoryProvider = Provider<IBookingRepository>((ref) {
  if (DemoConfig.demoMode) return MockBookingRepository();
  return SupabaseBookingRepository(ref.watch(supabaseClientProvider));
});

// ── Wizard ────────────────────────────────────────────────────────────────────

/// Family parameter: optional pre-selected [PackageModel] id.
/// Usage: ref.watch(bookingWizardProvider(null)) — blank wizard
///        ref.watch(bookingWizardProvider(pkg))  — pre-selected
final bookingWizardProvider = StateNotifierProvider.family<
    BookingWizardController, BookingWizardState, PackageModel?>(
  (ref, preSelected) {
    final repo = ref.watch(bookingRepositoryProvider);
    return BookingWizardController(repo, preSelectedPackage: preSelected);
  },
);

// ── Booking list ──────────────────────────────────────────────────────────────
final bookingListProvider =
    StateNotifierProvider<BookingListController, BookingListState>(
  (ref) {
    final repo = ref.watch(bookingRepositoryProvider);
    return BookingListController(repo);
  },
);

// ── Convenience: single booking by id ────────────────────────────────────────
final bookingByIdProvider = Provider.family<BookingModel?, String>((ref, id) {
  final list = ref.watch(bookingListProvider).bookings;
  return list.where((b) => b.id == id).firstOrNull;
});
