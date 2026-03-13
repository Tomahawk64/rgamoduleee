/// Supabase project credentials.
///
/// Replace the placeholder values below with your actual Supabase
/// project URL and anon/public key before running the app.
///
/// You can find them at:
///   https://supabase.com/dashboard/project/<your-project>/settings/api
class SupabaseConfig {
  SupabaseConfig._();

  /// Your Supabase project URL, e.g. https://xyzcompany.supabase.co
  static const String url = 'https://esxttdierlivqpblpnyw.supabase.co';

  /// Your Supabase anon (public) key.
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVzeHR0ZGllcmxpdnFwYmxwbnl3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5OTkxMzIsImV4cCI6MjA4NzU3NTEzMn0.SSzjoRySZX8027i3JFowAP5XPQ8lQ69woMiSqkFYW1k';
}

// ══════════════════════════════════════════════════════════════════════════════
// RUN THIS SQL IN SUPABASE → SQL EDITOR  (fixes the 500 signup error)
// ══════════════════════════════════════════════════════════════════════════════
//
// Step 1 — Drop any old/broken trigger first:
//
// DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
// DROP FUNCTION IF EXISTS public.handle_new_user();
//
// Step 2 — Recreate the trigger matching the real profiles schema
//          (full_name, role, is_active — no email column):
//
// CREATE OR REPLACE FUNCTION public.handle_new_user()
// RETURNS trigger AS $$
// BEGIN
//   INSERT INTO public.profiles (id, full_name, role, is_active)
//   VALUES (
//     NEW.id,
//     COALESCE(
//       NEW.raw_user_meta_data->>'full_name',
//       NEW.raw_user_meta_data->>'name',
//       SPLIT_PART(NEW.email, '@', 1)
//     ),
//     COALESCE(NEW.raw_user_meta_data->>'role', 'user'),
//     true
//   )
//   ON CONFLICT (id) DO NOTHING;
//   RETURN NEW;
// EXCEPTION WHEN OTHERS THEN
//   RETURN NEW; -- never let a profile error block auth signup
// END;
// $$ LANGUAGE plpgsql SECURITY DEFINER;
//
// CREATE TRIGGER on_auth_user_created
//   AFTER INSERT ON auth.users
//   FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
//
// Step 3 — RLS policies (run once if not already done):
//
// ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
//
// CREATE POLICY "Users can view own profile"
//   ON public.profiles FOR SELECT USING (auth.uid() = id);
//
// CREATE POLICY "Users can update own profile"
//   ON public.profiles FOR UPDATE USING (auth.uid() = id);
//
// CREATE POLICY "Users can insert own profile"
//   ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
