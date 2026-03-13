// scripts/seed.dart  — REWRITTEN v3
//
// Seeds all load-test data WITHOUT creating new auth users.
// Avoids the profiles_role_check constraint entirely by reusing an existing
// pandit that is already in the database.
//
// -- HOW TO RUN ----------------------------------------------------------------
//
//   cd scripts
//   $env:SUPABASE_SERVICE_ROLE_KEY = "eyJ..."   # PowerShell
//   dart run seed.dart
//
//   Or inline:
//   dart run seed.dart --service-role-key=eyJ...
//
// Find it: Supabase Dashboard -> Settings -> API -> service_role (secret)
//
// -- STRATEGY -----------------------------------------------------------------
//
//   Your live DB has a `profiles_role_check` constraint that prevents creating
//   new auth users via any API (signup, admin API) because the handle_new_user
//   trigger inserts profiles with role='user' and that violates the constraint.
//
//   This script avoids the problem entirely:
//   - Does NOT create any new auth users
//   - Signs in as test@test.com (must already exist)
//   - Queries the DB for an existing pandit with is_online=true
//   - Sets up consultation_rates and test package for that pandit
//   - Writes the pandit's real UUID into load_test.dart automatically
//
//   If no online pandit exists yet, open the app as admin and enable one
//   in Admin -> Pandits, or run this SQL in Supabase Dashboard:
//     UPDATE pandit_details SET is_online=true, consultation_enabled=true
//     WHERE id = '<your-pandit-id>';
//
// -- IDEMPOTENT ---------------------------------------------------------------
//   Safe to re-run multiple times.
//
// -----------------------------------------------------------------------------

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const kSupabaseUrl  = 'https://esxttdierlivqpblpnyw.supabase.co';
const kAnonKey      = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
    '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVzeHR0ZGllcmxpdnFwYmxwbnl3Iiwicm9s'
    'ZSI6ImFub24iLCJpYXQiOjE3NzE5OTkxMzIsImV4cCI6MjA4NzU3NTEzMn0'
    '.SSzjoRySZX8027i3JFowAP5XPQ8lQ69woMiSqkFYW1k';

const kTestUserEmail    = 'test@test.com';
const kTestUserPassword = 'Abc@123';

// Fixed UUID for the test package (plain table row, no Auth trigger).
const kPackageId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

// -----------------------------------------------------------------------------

Future<void> main(List<String> args) async {
  final serviceKey = _resolveServiceKey(args);
  if (serviceKey == null) {
    stderr.writeln('''
ERROR: service_role key not provided.

  \$env:SUPABASE_SERVICE_ROLE_KEY = "eyJ..."
  dart run seed.dart

Or: dart run seed.dart --service-role-key=eyJ...
''');
    exit(1);
  }

  _banner('rg_amodule Seed Script', DateTime.now().toString());

  final svc      = _svcHeaders(serviceKey);
  final adminHdr = svc; // same service-role key used for auth admin API

  // -- Step 1: Sign in as test user to verify credentials work ---------------
  await _step('Verifying test@test.com credentials', () async {
    final res = await _signIn(kTestUserEmail, kTestUserPassword);
    if (res == null) {
      stderr.writeln('  ERROR: Cannot sign in as $kTestUserEmail.');
      stderr.writeln('  Create this user in Supabase Dashboard -> Authentication -> Users.');
      exit(1);
    }
    print('  -> id = $res');
  });

  // -- Step 2: Find or create a pandit in the DB ----------------------------
  // Tries pandit_details → profiles(role=pandit) → auto-insert seed row.
  late String panditId;
  String panditIdTemp = '';
  await _step('Finding or seeding a pandit in the DB', () async {
    // 2a: Try pandit_details (may not exist if migrations not yet applied)
    final pdRes = await http.get(
      Uri.parse('$kSupabaseUrl/rest/v1/pandit_details?select=id&limit=1'),
      headers: svc,
    );
    if (pdRes.statusCode == 200) {
      final rows = jsonDecode(pdRes.body) as List;
      if (rows.isNotEmpty) {
        panditIdTemp = (rows.first as Map<String, dynamic>)['id'] as String;
        print('  -> Found pandit in pandit_details: $panditIdTemp');
      }
    }

    // 2b: Fallback — query profiles without is_active filter
    if (panditIdTemp.isEmpty) {
      final prRes = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/profiles?role=eq.pandit&select=id&limit=1'),
        headers: svc,
      );
      if (prRes.statusCode == 200) {
        final rows = jsonDecode(prRes.body) as List;
        if (rows.isNotEmpty) {
          panditIdTemp = (rows.first as Map<String, dynamic>)['id'] as String;
          print('  -> Found pandit in profiles: $panditIdTemp');
        }
      }
    }

    // 2c: Auto-create a seed pandit via admin API (trigger inserts profile)
    if (panditIdTemp.isEmpty) {
      print('  -> No pandit found — trying admin API to create seed.pandit@test.local...');
      const seedPanditId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
      final insRes = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/admin/users'),
        headers: adminHdr,
        body: jsonEncode({
          'id':              seedPanditId,
          'email':           'seed.pandit@test.local',
          'password':        'Abc@123',
          'email_confirm':   true,
          'user_metadata':   {'role': 'pandit', 'full_name': 'Test Pandit'},
        }),
      );
      if (insRes.statusCode == 200 || insRes.statusCode == 201) {
        panditIdTemp = seedPanditId;
        print('  -> Created auth user + profile for pandit: $panditIdTemp');
      } else if (insRes.statusCode == 422 &&
          insRes.body.contains('email_exists')) {
        // Auth user already exists (from a prior run where trigger was broken).
        // Fetch their UUID, then ensure the profile row exists.
        print('  -> Auth user already exists — fetching UUID and ensuring profile...');
        final listRes = await http.get(
          Uri.parse('$kSupabaseUrl/auth/v1/admin/users?email=seed.pandit@test.local'),
          headers: adminHdr,
        );
        String existingId = seedPanditId; // fallback to known UUID
        if (listRes.statusCode == 200) {
          final parsed = jsonDecode(listRes.body);
          // Response may be {"users":[...]} or a plain list
          final List<dynamic> users = parsed is List
              ? parsed
              : (parsed['users'] as List? ?? []);
          if (users.isNotEmpty) {
            existingId = (users.first as Map<String, dynamic>)['id'] as String;
          }
        }
        // Directly upsert the profile row using service-role (bypasses RLS)
        final profRes = await http.post(
          Uri.parse('$kSupabaseUrl/rest/v1/profiles'),
          headers: {...svc, 'Prefer': 'resolution=merge-duplicates,return=minimal'},
          body: jsonEncode({
            'id':        existingId,
            'full_name': 'Test Pandit',
            'role':      'pandit',
            'is_active': true,
          }),
        );
        if (profRes.statusCode == 200 ||
            profRes.statusCode == 201 ||
            profRes.statusCode == 204) {
          panditIdTemp = existingId;
          print('  -> Profile upserted for existing auth user: $panditIdTemp');
        } else if (profRes.statusCode == 400 &&
            profRes.body.contains('profiles_role_check')) {
          // The CHECK constraint on profiles.role doesn't include 'pandit'.
          // Show the user the exact SQL to fix it.
          stderr.writeln('');
          stderr.writeln('  ERROR: profiles_role_check constraint rejects role=pandit.');
          stderr.writeln('  Run this SQL in Supabase Dashboard → SQL Editor to fix it:');
          stderr.writeln('');
          stderr.writeln('  ALTER TABLE public.profiles DROP CONSTRAINT profiles_role_check;');
          stderr.writeln('  ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check');
          stderr.writeln("    CHECK (role IN ('user', 'pandit', 'admin'));");
          stderr.writeln('');
          stderr.writeln('  Then re-run this seed script.');
          exit(1);
        } else {
          stderr.writeln('  ERROR: Could not upsert profile.');
          stderr.writeln('  HTTP ${profRes.statusCode}: ${profRes.body}');
          exit(1);
        }
      } else {
        stderr.writeln('');
        stderr.writeln('  ERROR: Admin API returned HTTP ${insRes.statusCode}.');
        stderr.writeln('  Body: ${insRes.body}');
        stderr.writeln('');
        stderr.writeln('  The live DB trigger is broken (profiles_role_check violation).');
        stderr.writeln('  Fix it by running this SQL in Supabase Dashboard → SQL Editor:');
        stderr.writeln('');
        stderr.writeln('  ┌─ COPY FROM HERE ──────────────────────────────────────────┐');
        stderr.writeln('  -- 1. Drop broken trigger');
        stderr.writeln('  DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;');
        stderr.writeln('  DROP FUNCTION IF EXISTS public.handle_new_user();');
        stderr.writeln('');
        stderr.writeln('  -- 2. Recreate with correct schema + safe exception handler');
        stderr.writeln('  CREATE OR REPLACE FUNCTION public.handle_new_user()');
        stderr.writeln('  RETURNS trigger AS \$\$');
        stderr.writeln('  BEGIN');
        stderr.writeln('    INSERT INTO public.profiles (id, full_name, role, is_active)');
        stderr.writeln('    VALUES (');
        stderr.writeln('      NEW.id,');
        stderr.writeln("      COALESCE(NEW.raw_user_meta_data->>'full_name',");
        stderr.writeln("               NEW.raw_user_meta_data->>'name',");
        stderr.writeln("               SPLIT_PART(NEW.email, '@', 1)),");
        stderr.writeln("      COALESCE(NEW.raw_user_meta_data->>'role', 'user'),");
        stderr.writeln('      true');
        stderr.writeln('    ) ON CONFLICT (id) DO NOTHING;');
        stderr.writeln('    RETURN NEW;');
        stderr.writeln('  EXCEPTION WHEN OTHERS THEN');
        stderr.writeln('    RETURN NEW;');
        stderr.writeln('  END;');
        stderr.writeln('  \$\$ LANGUAGE plpgsql SECURITY DEFINER;');
        stderr.writeln('');
        stderr.writeln('  CREATE TRIGGER on_auth_user_created');
        stderr.writeln('    AFTER INSERT ON auth.users');
        stderr.writeln('    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();');
        stderr.writeln('  └─ COPY TO HERE ────────────────────────────────────────────┘');
        stderr.writeln('');
        stderr.writeln('  After running that SQL, re-run this seed script.');
        exit(1);
      }
    }
    panditId = panditIdTemp;
  });

  // -- Step 3: Ensure pandit_details has is_online=true ----------------------
  await _step('Ensuring pandit is_online=true, consultation_enabled=true', () async {
    final res = await http.patch(
      Uri.parse('$kSupabaseUrl/rest/v1/pandit_details?id=eq.$panditId'),
      headers: {...svc, 'Prefer': 'return=minimal'},
      body: jsonEncode({
        'is_online':            true,
        'consultation_enabled': true,
      }),
    );
    if (res.statusCode == 404) {
      print('  -> pandit_details table not found (migrations not applied) — skipping');
      print('  -> Apply 001_initial_schema.sql in SQL Editor to enable online status.');
      return;
    }
    _assertOk(res, 'Patch pandit_details');
    print('  -> Done');
  });

  // -- Step 4: Upsert consultation_rates -------------------------------------
  await _step('Upserting consultation_rates for pandit', () async {
    final rows = [
      {'pandit_id': panditId, 'duration_minutes': 10, 'price': 99.00,  'is_active': true},
      {'pandit_id': panditId, 'duration_minutes': 15, 'price': 149.00, 'is_active': true},
      {'pandit_id': panditId, 'duration_minutes': 30, 'price': 249.00, 'is_active': true},
      {'pandit_id': panditId, 'duration_minutes': 60, 'price': 449.00, 'is_active': true},
    ];
    bool skipped = false;
    for (final r in rows) {
      final res = await _upsert(svc, 'consultation_rates', r,
          onConflict: 'pandit_id,duration_minutes');
      if (res.statusCode == 404) {
        print('  -> consultation_rates table not found — skipping all rates');
        print('  -> Apply 001_initial_schema.sql in SQL Editor to seed rates.');
        skipped = true;
        break;
      }
      _assertOk(res, 'Rate ${r['duration_minutes']}min');
    }
    if (!skipped) print('  -> 10 / 15 / 30 / 60 min rates');
  });

  // -- Step 5: Upsert test package -------------------------------------------
  // Uses adaptive retry: if a column doesn't exist (PGRST204), strip it and retry.
  await _step('Upserting test package ($kPackageId)', () async {
    // Start with the full desired schema; columns are pruned on PGRST204.
    final fullRow = <String, dynamic>{
      'id':               kPackageId,
      'title':            'Load Test Satyanarayan Puja',
      'description':      'Seed package for automated load-testing. Do not book.',
      'price':            999.00,
      'discount_price':   799.00,
      'duration_minutes': 90,
      'is_online':        true,
      'is_offline':       true,
      'category':         'puja',
      'includes':         ['Pandit', 'Samagri Kit', 'Online Streaming'],
      'is_active':        true,
      'is_featured':      false,
    };
    final row = Map<String, dynamic>.from(fullRow);
    const maxRetries = 15; // one per optional column
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      final res = await _upsert(svc, 'packages', row);
      if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204) {
        print('  -> Done (columns: ${row.keys.where((k) => k != 'id').join(', ')})');
        return;
      }
      // PGRST204 = column not found in schema cache — strip it and retry
      if (res.statusCode == 400) {
        final body = res.body;
        final match = RegExp(r"find the '([^']+)' column").firstMatch(body);
        if (match != null) {
          final bad = match.group(1)!;
          row.remove(bad);
          print('  -> Column "$bad" not in live schema — removing and retrying...');
          continue;
        }
      }
      _assertOk(res, 'Upsert package');
      return;
    }
    stderr.writeln('  ERROR: Could not upsert package after $maxRetries attempts.');
    exit(1);
  });

  // -- Step 6: Patch kPanditId in load_test.dart ----------------------------
  await _step('Writing real pandit UUID to load_test.dart', () async {
    final f = File('load_test.dart');
    if (!f.existsSync()) {
      print('  -> load_test.dart not found in cwd.');
      print('  -> Set manually: kPanditId = "$panditId"');
      return;
    }
    var src = f.readAsStringSync();
    final re = RegExp(r"const kPanditId\s*=\s*'[^']*';");
    if (re.hasMatch(src)) {
      src = src.replaceFirst(re, "const kPanditId  = '$panditId';");
      f.writeAsStringSync(src);
      print('  -> Patched load_test.dart');
    } else {
      print('  -> Pattern not found. Set manually: kPanditId = "$panditId"');
    }
  });

  // -- Done ------------------------------------------------------------------
  print('');
  print('=' * 60);
  print(' Seed complete!');
  print('');
  print('  kPanditId  = "$panditId"   <- written to load_test.dart');
  print('  kPackageId = "$kPackageId"  <- fixed constant');
  print('');
  print('  Make sure migration 004_rpc_increment_duration.sql is applied.');
  print('  Then run: dart run load_test.dart');
  print('=' * 60);
}

// -----------------------------------------------------------------------------
// HELPERS
// -----------------------------------------------------------------------------

/// Signs in with email/password. Returns the user UUID on success, null on failure.
Future<String?> _signIn(String email, String password) async {
  final res = await http.post(
    Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=password'),
    headers: {'Content-Type': 'application/json', 'apikey': kAnonKey},
    body: jsonEncode({'email': email, 'password': password}),
  );
  if (res.statusCode != 200) return null;
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  return (body['user'] as Map<String, dynamic>)['id'] as String?;
}

// -----------------------------------------------------------------------------
// HELPERS
// -----------------------------------------------------------------------------

Future<http.Response> _upsert(
  Map<String, String> headers,
  String table,
  Map<String, dynamic> body, {
  String? onConflict,
}) {
  final qs = onConflict != null
      ? '?on_conflict=${Uri.encodeQueryComponent(onConflict)}'
      : '';
  return http.post(
    Uri.parse('$kSupabaseUrl/rest/v1/$table$qs'),
    headers: {...headers, 'Prefer': 'resolution=merge-duplicates'},
    body: jsonEncode(body),
  );
}

Map<String, String> _svcHeaders(String key) => {
  'Content-Type':  'application/json',
  'apikey':        key,
  'Authorization': 'Bearer $key',
};

String? _resolveServiceKey(List<String> args) {
  for (final a in args) {
    if (a.startsWith('--service-role-key=')) return a.substring('--service-role-key='.length).trim();
  }
  return Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
}

void _assertOk(http.Response res, String label) {
  if (res.statusCode >= 400) {
    stderr.writeln('  ERROR [$label] HTTP ${res.statusCode}: ${res.body}');
    exit(1);
  }
}

Future<void> _step(String label, Future<void> Function() fn) async {
  print('\n[$label]');
  await fn();
}

void _banner(String t, String s) {
  print('-' * 60);
  print(' $t');
  print(' $s');
  print('-' * 60);
}
