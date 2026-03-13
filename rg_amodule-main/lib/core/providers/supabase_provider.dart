import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exposes the singleton [SupabaseClient] to the Riverpod dependency tree.
///
/// `Supabase.initialize()` must be called before `runApp()` (see main.dart).
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
