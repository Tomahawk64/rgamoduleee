import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/core/app_config.dart';
import 'src/presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    razorpayKeyId: String.fromEnvironment('RAZORPAY_KEY_ID'),
    cloudflareUploadFunction: String.fromEnvironment(
      'CLOUDFLARE_UPLOAD_FUNCTION',
      defaultValue: 'cloudflare-r2-upload-url',
    ),
  );

  if (config.hasSupabase) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
    );
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: SaralPoojaApp()));
}

class SaralPoojaApp extends StatelessWidget {
  const SaralPoojaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const SaralPoojaCleanApp();
  }
}
