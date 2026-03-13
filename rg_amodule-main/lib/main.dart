import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Initialise Supabase ───────────────────────────────────────────────────
  // Supabase automatically restores the persisted session from
  // flutter_secure_storage on startup — no manual token management needed.
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    // authOptions lets us configure deep-link URL scheme for password-reset.
    // authOptions: const AuthClientOptions(authFlowType: AuthFlowType.pkce),
  );

  // Lock to portrait on mobile.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    // ProviderScope is required at the root for Riverpod.
    const ProviderScope(child: SaralPoojaApp()),
  );
}

/// Root application widget.
/// Consumes [routerProvider] to drive navigation via go_router.
class SaralPoojaApp extends ConsumerWidget {
  const SaralPoojaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Saral Pooja',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}

