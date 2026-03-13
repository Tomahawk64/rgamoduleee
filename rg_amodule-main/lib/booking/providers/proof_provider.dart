import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../controllers/proof_controller.dart';
import '../repository/proof_repository.dart';

// ── Repository ────────────────────────────────────────────────────────────────

/// Provides the live [SupabaseProofRepository] wired to the Supabase client.
///
/// To run the app against the in-memory mock (e.g. during UI development
/// without a backend), override this provider:
///
/// ```dart
/// // in main.dart or a test:
/// overrides: [
///   proofRepositoryProvider.overrideWithValue(MockProofRepository.seeded()),
/// ]
/// ```
final proofRepositoryProvider = Provider<IProofRepository>((ref) {
  return SupabaseProofRepository(ref.watch(supabaseClientProvider));
});

// ── Upload provider (family keyed by bookingId) ───────────────────────────────

/// Use this in the ProofUploadScreen.
///
/// Example:
///   final ctrl = ref.read(proofUploadProvider('booking_123').notifier);
final proofUploadProvider = StateNotifierProvider.family<
    ProofUploadController, ProofUploadState, String>(
  (ref, bookingId) => ProofUploadController(
    ref.watch(proofRepositoryProvider),
  ),
);

// ── View provider (family keyed by bookingId) ─────────────────────────────────

/// Use this in BookingDetailScreen to fetch and display an existing proof.
///
/// Example:
///   final state = ref.watch(proofViewProvider('booking_123'));
final proofViewProvider = StateNotifierProvider.family<
    ProofViewController, ProofViewState, String>(
  (ref, bookingId) => ProofViewController(
    ref.watch(proofRepositoryProvider),
    bookingId,
  ),
);
