/// Demo-mode configuration for the Saral Pooja client demo.
///
/// When [demoMode] is `true`:
///   - The login screen shows quick-login chips for the 3 demo accounts.
///   - Admin destructive actions (delete pooja, toggle pandit) show a
///     snackbar instead of hitting the backend.
///   - Payment always simulates success (MockPaymentService — already wired).
///   - Auto-assign pandit to new bookings when no pandit is specified.
///
/// Set to `false` before building a production release.
class DemoConfig {
  DemoConfig._();

  /// Master switch for demo-mode behaviour.
  static const bool demoMode = false;

  // ── Demo account credentials ───────────────────────────────────────────

  static const String demoUserEmail = 'demo_user@saralpooja.com';
  static const String demoPanditEmail = 'demo_pandit@saralpooja.com';
  static const String demoAdminEmail = 'demo_admin@saralpooja.com';
  static const String demoPassword = 'Demo@123';

  /// Human-readable labels for the quick-login chips.
  static const List<DemoAccount> demoAccounts = [
    DemoAccount(
      label: 'Demo User',
      email: demoUserEmail,
      password: demoPassword,
      icon: '👤',
      role: 'user',
      mockId: '11111111-1111-4111-8111-111111111111',
      fullName: 'Rajesh Kumar',
      phone: '+919876543210',
    ),
    DemoAccount(
      label: 'Demo Pandit',
      email: demoPanditEmail,
      password: demoPassword,
      icon: '🙏',
      role: 'pandit',
      mockId: '22222222-2222-4222-8222-222222222222',
      fullName: 'Pandit Shivendra Shastri',
      phone: '+919988776655',
    ),
    DemoAccount(
      label: 'Demo Admin',
      email: demoAdminEmail,
      password: demoPassword,
      icon: '🛡️',
      role: 'admin',
      mockId: '33333333-3333-4333-8333-333333333333',
      fullName: 'Admin Saral Pooja',
      phone: '+919111222333',
    ),
  ];

  /// Returns `true` when [email] belongs to one of the demo accounts.
  static bool isDemoEmail(String email) =>
      email == demoUserEmail ||
      email == demoPanditEmail ||
      email == demoAdminEmail;
}

/// A pre-configured demo account entry.
class DemoAccount {
  const DemoAccount({
    required this.label,
    required this.email,
    required this.password,
    required this.icon,
    required this.role,
    required this.mockId,
    required this.fullName,
    this.phone,
  });

  final String label;
  final String email;
  final String password;
  final String icon;
  final String role;
  final String mockId;
  final String fullName;
  final String? phone;
}
