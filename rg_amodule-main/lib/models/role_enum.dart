/// User roles within the platform.
enum UserRole {
  /// Unregistered visitor – can browse but not book.
  guest,

  /// Standard registered customer – can browse, book, and purchase.
  user,

  /// Pandit / service provider – can manage their own offerings.
  pandit,

  /// Super administrator – full platform access.
  admin,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.guest:
        return 'Guest';
      case UserRole.user:
        return 'User';
      case UserRole.pandit:
        return 'Pandit';
      case UserRole.admin:
        return 'Admin';
    }
  }

  bool get isAuthenticated => this != UserRole.guest;
  bool get isAdmin => this == UserRole.admin;
  bool get isPandit => this == UserRole.pandit;
  bool get isCustomer => this == UserRole.user;

  /// Returns true if this role has at least the permissions of [other].
  bool isAtLeast(UserRole other) => index >= other.index;
}
