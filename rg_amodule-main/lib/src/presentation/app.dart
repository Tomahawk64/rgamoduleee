import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/models.dart';
import 'providers.dart';
import 'screens.dart';

class SaralPoojaCleanApp extends ConsumerWidget {
  const SaralPoojaCleanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(cleanRouterProvider);
    return MaterialApp.router(
      title: 'Saral Pooja',
      debugShowCheckedModeBanner: false,
      theme: SaralTheme.light,
      routerConfig: router,
    );
  }
}

final cleanRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final appState = ref.read(appControllerProvider);
      final role = appState.user.role;
      final path = state.uri.path;
      final isAuthPath = path == '/login' || path == '/signup';
      if (!appState.isAuthenticated && !isAuthPath) {
        return '/login';
      }
      if (appState.isAuthenticated && isAuthPath) {
        return '/home';
      }
      if (path.startsWith('/admin') && role != UserRole.admin) {
        return '/account';
      }
      if (path.startsWith('/pandit') &&
          role != UserRole.pandit &&
          role != UserRole.admin) {
        return '/account';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      ShellRoute(
        builder: (context, state, child) => UserShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/packages', builder: (_, _) => const PackageScreen()),
          GoRoute(
            path: '/special',
            builder: (_, _) => const SpecialPoojaScreen(),
          ),
          GoRoute(path: '/shop', builder: (_, _) => const ShopScreen()),
          GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
        ],
      ),
      GoRoute(path: '/admin', builder: (_, _) => const AdminDashboardScreen()),
      GoRoute(
        path: '/pandit',
        builder: (_, _) => const PanditDashboardScreen(),
      ),
      GoRoute(
        path: '/book/:type/:id',
        builder: (_, state) => BookingFormScreen(
          type: state.pathParameters['type']!,
          catalogueId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/chat-booking',
        builder: (_, _) => const ChatBookingScreen(),
      ),
      GoRoute(
        path: '/booking/:id',
        builder: (_, state) =>
            BookingDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) =>
            ChatRoomScreen(sessionId: state.pathParameters['id']!),
      ),
    ],
  );
});

class SaralTheme {
  static ThemeData get light {
    const saffron = Color(0xFFE8892E);
    const maroon = Color(0xFF6D2D24);
    const cream = Color(0xFFFFF8EA);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: saffron,
        primary: saffron,
        secondary: const Color(0xFFB88732),
        surface: const Color(0xFFFFFCF6),
        error: const Color(0xFFBA1A1A),
      ),
      scaffoldBackgroundColor: cream,
      textTheme: GoogleFonts.interTextTheme(),
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: maroon,
        centerTitle: false,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: saffron,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
