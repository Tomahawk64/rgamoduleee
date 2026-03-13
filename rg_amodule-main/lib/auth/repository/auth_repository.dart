import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../models/role_enum.dart';
import '../models/user_model.dart';

// ── Custom exception ──────────────────────────────────────────────────────────
class AuthRepositoryException implements Exception {
  const AuthRepositoryException(this.message, {this.code});

  final String message;

  /// Optional Supabase / Postgres error code.
  final String? code;

  @override
  String toString() => 'AuthRepositoryException: $message';
}

// ── Repository ────────────────────────────────────────────────────────────────

/// Handles all Supabase Authentication & Profiles table calls.
///
/// This class is the single point of contact between the app and Supabase.
/// Controllers / notifiers never import `supabase_flutter` directly.
class AuthRepository {
  const AuthRepository(this._client);

  final supa.SupabaseClient _client;

  // ── Sign-up ─────────────────────────────────────────────────────────────
  /// Creates a new auth user and inserts a corresponding profile row.
  ///
  /// The DB trigger `on_auth_user_created` also inserts the profile, but we
  /// do an explicit upsert here to handle cases where the trigger is absent.
  Future<UserModel> signUp({
    required String name,
    required String email,
    required String password,
    UserRole role = UserRole.user,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'full_name': name.trim(),
          'name': name.trim(), // kept for fallback
          'role': role.name,
        },
      );

      final authUser = response.user;
      if (authUser == null) {
        throw const AuthRepositoryException(
          'Sign-up succeeded but no user was returned. '
          'Please check your email to confirm your account.',
        );
      }

      // Try to upsert the profile row separately.
      // This is a best-effort call; even if it fails (e.g. trigger already
      // created the row, or a constraint error), the auth user exists and
      // the onAuthStateChange stream will handle loading the profile.
      try {
        await _client.from('profiles').upsert({
          'id': authUser.id,
          'full_name': name.trim(),
          'role': role.name,
          'is_active': true,
        }, onConflict: 'id');

        if (role == UserRole.pandit) {
          await _ensurePanditDetails(authUser.id);
        }
      } catch (_) {
        // Ignore — profile will be created/loaded by the stream handler.
      }

      return UserModel(
        id: authUser.id,
        name: name.trim(),
        email: email.trim().toLowerCase(),
        role: role,
        createdAt: DateTime.now(),
      );
    } on supa.AuthException catch (e) {
      throw AuthRepositoryException(_mapSupabaseAuthError(e), code: e.code);
    } on AuthRepositoryException {
      rethrow;
    } catch (e) {
      throw AuthRepositoryException('Sign-up failed: ${e.toString()}');
    }
  }

  // ── Sign-in ─────────────────────────────────────────────────────────────
  /// Authenticates with email + password and fetches the user's profile.
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final authUser = response.user;
      if (authUser == null) {
        throw const AuthRepositoryException('Login failed. Please try again.');
      }

      return await _fetchOrCreateProfile(authUser);
    } on supa.AuthException catch (e) {
      throw AuthRepositoryException(_mapSupabaseAuthError(e), code: e.code);
    } on AuthRepositoryException {
      rethrow;
    } catch (e) {
      throw AuthRepositoryException('Login failed. Please try again.');
    }
  }

  // ── Sign-out ─────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on supa.AuthException catch (e) {
      throw AuthRepositoryException(_mapSupabaseAuthError(e), code: e.code);
    } catch (e) {
      throw AuthRepositoryException('Sign-out failed.');
    }
  }

  // ── Fetch profile ────────────────────────────────────────────────────────
  /// Queries the `profiles` table and returns a [UserModel].
  /// Returns `null` if no row is found (e.g. before trigger fires).
  Future<UserModel?> fetchProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;
      return UserModel.fromProfileJson(data);
    } catch (e) {
      // Don't crash the app for a missing profile — caller decides what to do.
      return null;
    }
  }

  // ── Restore session ──────────────────────────────────────────────────────
  /// Called at app-start to check for a persisted (auto-login) session.
  ///
  /// Supabase stores the session in [flutter_secure_storage] automatically.
  Future<UserModel?> restoreSession() async {
    try {
      final session = _client.auth.currentSession;
      if (session == null) return null;

      final authUser = session.user;
      return await _fetchOrCreateProfile(authUser);
    } catch (_) {
      return null;
    }
  }

  // ── Send password reset ──────────────────────────────────────────────────
  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim().toLowerCase());
    } on supa.AuthException catch (e) {
      throw AuthRepositoryException(_mapSupabaseAuthError(e), code: e.code);
    } catch (_) {
      throw const AuthRepositoryException(
          'Could not send reset email. Please try again.');
    }
  }

  // ── Auth state stream ────────────────────────────────────────────────────
  /// Raw Supabase auth-change stream. The controller listens to this.
  Stream<supa.AuthState> get authStateStream =>
      _client.auth.onAuthStateChange;

  /// Synchronous access to the current session (may be null if signed out).
  supa.Session? get currentSession => _client.auth.currentSession;

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Fetches the profile row. If missing (no trigger / first login after email
  /// confirmation), inserts it now using the live session so RLS is satisfied.
  Future<UserModel> _fetchOrCreateProfile(supa.User authUser) async {
    var profile = await fetchProfile(authUser.id);
    if (profile != null) {
      // profiles table has no email column — fill it from auth.users
      if (profile.email.isEmpty && authUser.email != null) {
        profile = profile.copyWith(email: authUser.email);
      }
      if (profile.role == UserRole.pandit) {
        await _ensurePanditDetails(authUser.id);
      }
      return profile;
    }

    // Profile is missing — build values from auth metadata and INSERT.
    final meta    = authUser.userMetadata ?? {};
    final name    = (meta['full_name'] as String?) ??
        (meta['name'] as String?) ??
        authUser.email?.split('@').first ??
        'User';
    final roleName = (meta['role'] as String?) ?? UserRole.user.name;

    try {
      await _client.from('profiles').insert({
        'id':        authUser.id,
        'full_name': name,
        'role':      roleName,
        'is_active': true,
      });
      // Re-fetch after insert to get the DB-generated row.
      final inserted = await fetchProfile(authUser.id);
      if (inserted != null) {
        if (inserted.role == UserRole.pandit) {
          await _ensurePanditDetails(authUser.id);
        }
        return inserted.copyWith(email: authUser.email);
      }
    } catch (_) {
      // INSERT failed — profile may have just been created by the DB trigger
      // (race condition). Try one more fetch before falling back.
      final retry = await fetchProfile(authUser.id);
      if (retry != null) {
        if (retry.role == UserRole.pandit) {
          await _ensurePanditDetails(authUser.id);
        }
        return retry.copyWith(email: authUser.email);
      }
    }

    // Absolute fallback: return an in-memory model so login doesn't hard-fail.
    return UserModel(
      id:        authUser.id,
      name:      name,
      email:     authUser.email ?? '',
      role:      UserRole.values.firstWhere(
        (r) => r.name == roleName,
        orElse:  () => UserRole.user,
      ),
      createdAt: DateTime.tryParse(authUser.createdAt),
    );
  }

  Future<void> _ensurePanditDetails(String userId) async {
    try {
      await _client.from('pandit_details').upsert({
        'id': userId,
        'specialties': <String>[],
        'languages': <String>['Hindi'],
        'experience_years': 0,
        'is_online': false,
        'consultation_enabled': false,
      }, onConflict: 'id');
    } catch (_) {
      // Ignore bootstrap errors; profile/auth flow must continue.
    }
  }

  /// Public version used by [AuthController._loadProfile] —
  /// fetches the profile and inserts it when missing.
  Future<UserModel> fetchOrCreateProfile(supa.User authUser) =>
      _fetchOrCreateProfile(authUser);

  /// Maps Supabase auth exception messages to user-friendly strings.
  String _mapSupabaseAuthError(supa.AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please verify your email before logging in.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already been registered')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('password should be')) {
      return 'Password must be at least 6 characters.';
    }
    if (msg.contains('unable to validate email address')) {
      return 'Please enter a valid email address.';
    }
    if (msg.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (msg.contains('network')) {
      return 'Network error. Please check your connection.';
    }
    if (e.statusCode == '500' || msg.contains('500') || msg.contains('internal')) {
      return 'Server error. Please check that your Supabase project is active and try again.';
    }
    return e.message;
  }
}
