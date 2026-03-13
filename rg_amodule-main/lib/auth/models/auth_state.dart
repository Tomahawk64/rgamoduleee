import 'package:equatable/equatable.dart';
import '../models/user_model.dart';

// ── Auth State ────────────────────────────────────────────────────────────────
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial / checking persisted session.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Loading an auth operation (login / register / logout).
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Successfully authenticated.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final UserModel user;

  @override
  List<Object?> get props => [user];
}

/// Not authenticated – user is a guest.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// An auth error occurred.
class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

/// Signup succeeded but email confirmation is required before login.
class AuthEmailConfirmationPending extends AuthState {
  const AuthEmailConfirmationPending({required this.email});
  final String email;

  @override
  List<Object?> get props => [email];
}
