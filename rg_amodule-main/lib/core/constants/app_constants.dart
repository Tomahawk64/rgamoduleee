/// App-wide constant values.
class AppConstants {
  AppConstants._();

  static const String appName = 'Saral Pooja';
  static const String appVersion = '1.0.0';

  // Route names (mirrors AppRouter path constants)
  static const String splashRoute = '/';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String homeRoute = '/home';
  static const String packagesRoute = '/packages';
  static const String bookingRoute = '/booking/wizard';
  static const String consultationRoute = '/consultation';
  static const String shopRoute = '/shop';
  static const String adminRoute = '/admin';
  static const String panditRoute = '/pandit';
  static const String servicesRoute = '/services';

  // Shared-prefs keys
  static const String prefKeyRole = 'user_role';
  static const String prefKeyToken = 'auth_token';

  // Mock delays
  static const Duration mockDelay = Duration(milliseconds: 800);
  static const Duration splashDuration = Duration(seconds: 2);
}
