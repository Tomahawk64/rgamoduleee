import 'package:equatable/equatable.dart';
import '../../models/role_enum.dart';

/// Immutable domain model representing an authenticated (or guest) user.
class UserModel extends Equatable {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.phone,
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? avatarUrl;
  final String? phone;
  final DateTime? createdAt;

  // ── Factory: Guest ────────────────────────────────────────────────────────
  factory UserModel.guest() => const UserModel(
        id: 'guest',
        name: 'Guest',
        email: '',
        role: UserRole.guest,
      );

  // ── Factory: from generic JSON ───────────────────────────────────────────
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: UserRole.values.firstWhere(
          (r) => r.name == (json['role'] as String?),
          orElse: () => UserRole.user,
        ),
        avatarUrl: json['avatar_url'] as String?,
        phone: json['phone'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  // ── Factory: from Supabase `profiles` table row ──────────────────────────
  /// Maps the actual DB columns (full_name, no email) to the domain model.
  factory UserModel.fromProfileJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        // DB stores name as 'full_name'; fall back to 'name' for flexibility
        name: (json['full_name'] as String?) ??
            (json['name'] as String?) ??
            '',
        // email lives in auth.users, not in profiles — may be passed in or empty
        email: (json['email'] as String?) ?? '',
        role: UserRole.values.firstWhere(
          (r) => r.name == (json['role'] as String?),
          orElse: () => UserRole.user,
        ),
        avatarUrl: json['avatar_url'] as String?,
        phone: json['phone'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
        'avatar_url': avatarUrl,
        'phone': phone,
        'created_at': createdAt?.toIso8601String(),
      };

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? avatarUrl,
    String? phone,
    DateTime? createdAt,
  }) =>
      UserModel(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        role: role ?? this.role,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        phone: phone ?? this.phone,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  List<Object?> get props => [id, name, email, role, avatarUrl, phone];
}
