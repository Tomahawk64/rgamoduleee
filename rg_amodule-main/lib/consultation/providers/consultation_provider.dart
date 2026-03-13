import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/demo_config.dart';
import '../../core/providers/supabase_provider.dart';
import '../controllers/consultation_controller.dart';
import '../models/consultation_session.dart';
import '../models/pandit_model.dart';
import '../repository/consultation_repository.dart';
import '../repository/ws_session_repository.dart';

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
        specialty: 'Consultation',
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
