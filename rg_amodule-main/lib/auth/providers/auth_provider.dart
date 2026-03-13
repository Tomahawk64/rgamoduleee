import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/auth_controller.dart';
import '../models/auth_state.dart';
import '../models/user_model.dart';
import '../repository/auth_repository.dart';
import '../../core/providers/supabase_provider.dart';
import '../../models/role_enum.dart';

// ── Repository provider ───────────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepository(client);
});

// ── Controller / StateNotifier provider ──────────────────────────────────────
/// Single provider for all auth state.
///
/// The [AuthController] internally subscribes to the Supabase
/// [onAuthStateChange] stream, so every sign-in, token-refresh, sign-out and
/// initial-session event automatically updates this state.
final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});

// ── Convenience providers ─────────────────────────────────────────────────────

/// Currently authenticated user, or `null` when unauthenticated.
final currentUserProvider = Provider<UserModel?>((ref) {
  final state = ref.watch(authProvider);
  if (state is AuthAuthenticated) return state.user;
  return null;
});

/// Current user role. Defaults to [UserRole.guest] when not signed in.
final userRoleProvider = Provider<UserRole>((ref) {
  return ref.watch(currentUserProvider)?.role ?? UserRole.guest;
});

/// Whether a full (non-guest) authenticated session is active.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null && user.role != UserRole.guest;
});
