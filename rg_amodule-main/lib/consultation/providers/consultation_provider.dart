import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/demo_config.dart';
import '../../core/providers/supabase_provider.dart';
import '../controllers/consultation_controller.dart';
import '../models/consultation_session.dart';
import '../models/pandit_model.dart';
import '../models/scheduled_consultation_request.dart';
import '../repository/consultation_repository.dart';
import '../repository/ws_session_repository.dart';

/// Emits a tick whenever consultations or pandit online status changes.
/// Screens can listen and invalidate relevant providers to get realtime updates.
final consultationRealtimeTickProvider = StreamProvider<int>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final controller = StreamController<int>.broadcast();
  var tick = 0;

  final channel = client
      .channel('consultation-realtime-sync')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'consultations',
        callback: (_) {
          tick += 1;
          controller.add(tick);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'pandit_details',
        callback: (_) {
          tick += 1;
          controller.add(tick);
        },
      )
      .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});

// ── Repository Providers ──────────────────────────────────────────────────────

/// Uses mocks in demo mode, Supabase otherwise.
final sessionRepositoryProvider = Provider<ISessionRepository>((ref) {
  if (DemoConfig.demoMode) return MockSessionRepository();
  return WsSessionRepository(ref.watch(supabaseClientProvider));
});

/// Uses mocks in demo mode, Supabase otherwise.
final panditRepositoryProvider = Provider<IPanditRepository>((ref) {
  if (DemoConfig.demoMode) return MockPanditRepository();
  return SupabasePanditRepository(ref.watch(supabaseClientProvider));
});

// ── Pandits List Provider ─────────────────────────────────────────────────────

final panditsProvider =
    StateNotifierProvider<PanditsController, PanditsState>((ref) {
  final ctrl = PanditsController(ref.watch(panditRepositoryProvider));
  ctrl.load();
  return ctrl;
});

// ── Consultation Flow Provider ────────────────────────────────────────────────
//
// Keyed by panditId — creates one flow controller per pandit selection.
// Automatically disposed when no longer watched.

final consultationFlowProvider = StateNotifierProvider.family
    .autoDispose<ConsultationFlowController, ConsultationFlowState, String>(
  (ref, panditId) {
    final pandits = ref.read(panditsProvider).pandits;
    final repo    = ref.read(sessionRepositoryProvider);
    PanditModel pandit;
    try {
      pandit = pandits.firstWhere((p) => p.id == panditId);
    } catch (_) {
      // Fallback: build a minimal placeholder pandit so the screen doesn't crash.
      pandit = PanditModel(
        id: panditId,
        name: 'Pandit',
        specialty: 'Astrology',
        rating: 0,
        totalSessions: 0,
        isOnline: true,
        rates: const [
          ConsultationRate(duration: 10, totalPaise: 9900),
          ConsultationRate(duration: 15, totalPaise: 14900),
          ConsultationRate(duration: 20, totalPaise: 19900),
        ],
      );
    }
    return ConsultationFlowController(pandit, repository: repo);
  },
);

// ── Session Provider ──────────────────────────────────────────────────────────
//
// Keyed by sessionId — one controller per active session.
// The controller connects to the repository immediately on creation.

final sessionProvider = StateNotifierProvider.family
    .autoDispose<SessionController, SessionState, ConsultationSession>(
  (ref, session) {
    final repo = ref.watch(sessionRepositoryProvider);
    final ctrl = SessionController(session: session, repository: repo);
    ctrl.init();
    return ctrl;
  },
);

final userScheduledConsultationsProvider =
    FutureProvider.family<List<ScheduledConsultationRequest>, String>(
  (ref, userId) async {
    return ref
        .watch(sessionRepositoryProvider)
        .fetchUserScheduledRequests(userId);
  },
);

final panditScheduledConsultationsProvider =
    FutureProvider.family<List<ScheduledConsultationRequest>, String>(
  (ref, panditId) async {
    return ref
        .watch(sessionRepositoryProvider)
        .fetchPanditScheduledRequests(panditId);
  },
);

// ── Pandit Active Session Provider ───────────────────────────────────────────
//
// Returns the pandit's currently active live consultation session, if any.
// Used by the pandit dashboard to show a "Rejoin Chat" button.

final panditActiveSessionProvider =
    FutureProvider.autoDispose.family<ConsultationSession?, String>(
  (ref, key) async {
    final parts = key.split('|');
    final panditId = parts[0];
    final panditName = parts.length > 1 ? parts[1] : 'Pandit';
    return ref.watch(sessionRepositoryProvider).fetchActiveSessionForPandit(
          panditId: panditId,
          panditName: panditName,
        );
  },
);
