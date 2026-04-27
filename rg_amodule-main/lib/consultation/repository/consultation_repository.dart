import 'dart:async';
import 'dart:typed_data';

import '../models/consultation_session.dart';
import '../models/pandit_model.dart';
import '../models/scheduled_consultation_request.dart';

// ── Session Repository ────────────────────────────────────────────────────────
//
// WebSocket-ready interface for consultation session management.
//
// PRODUCTION MIGRATION:
//   1. Add `web_socket_channel` to pubspec.yaml
//   2. Implement `WsSessionRepository` using `WebSocketChannel`
//   3. Replace `MockSessionRepository` in the provider with `WsSessionRepository`
//   4. All controllers/screens need ZERO changes — they only reference this interface.
//
// WebSocket message protocol (JSON):
//   Client → Server:
//     { "type": "send_message",  "text": "...", "session_id": "..." }
//     { "type": "extend_session","minutes": 10, "session_id": "..." }
//     { "type": "end_session",   "session_id": "..." }
//   Server → Client:
//     { "type": "session_started",  "session_id": "..." }
//     { "type": "pandit_message",   "text": "...", "sender_id": "...", ... }
//     { "type": "typing",           "is_typing": true }
//     { "type": "time_update",      "remaining_seconds": 540 }
//     { "type": "session_extended", "added_seconds": 600 }
//     { "type": "session_ended",    "reason": "time_expired" }
//

/// Abstract repository — the only contract controllers depend on.
abstract class ISessionRepository {
  /// Creates the consultation row in DB and returns a ready [ConsultationSession].
  /// Must be called before [connect].
  Future<ConsultationSession> startSession({
    required PanditModel pandit,
    required ConsultationRate rate,
    required String userId,
    required String userName,
  });

  /// Returns the currently active session for this user, if any.
  Future<ConsultationSession?> fetchActiveSessionForUser({
    required String userId,
    required String userName,
  });

  /// Returns the currently active session that this pandit is in, if any.
  Future<ConsultationSession?> fetchActiveSessionForPandit({
    required String panditId,
    required String panditName,
  });

  /// Creates a scheduled consultation request that can be accepted,
  /// rescheduled, or rejected by the pandit.
  Future<ScheduledConsultationRequest> requestScheduledSession({
    required PanditModel pandit,
    required ConsultationRate rate,
    required String userId,
    required String userName,
    required DateTime scheduledFor,
    required bool isPaid,
    required String? paymentId,
    String? customerNote,
  });

  /// List scheduled consultation requests for a user.
  Future<List<ScheduledConsultationRequest>> fetchUserScheduledRequests(
      String userId);

  /// List scheduled consultation requests for a pandit.
  Future<List<ScheduledConsultationRequest>> fetchPanditScheduledRequests(
      String panditId);

  /// Pandit action on a scheduled request.
  Future<void> panditRespondToScheduledRequest({
    required String sessionId,
    required String action,
    DateTime? proposedStart,
    String? note,
  });

  /// User response when pandit proposes a new time.
  Future<void> userRespondToProposedTime({
    required String sessionId,
    required bool accept,
    String? note,
  });

  /// Marks a consultation request as paid after successful Razorpay payment.
  Future<void> markConsultationPaid({
    required String sessionId,
    required String paymentId,
  });

  /// Starts a confirmed scheduled consultation — transitions it to 'active'
  /// and returns a [ConsultationSession] ready for [connect].
  Future<ConsultationSession> startScheduledSession({
    required ScheduledConsultationRequest request,
    required String currentUserId,
    required String currentUserName,
  });

  /// Requests a live chat session (immediate start, no scheduling).
  /// Only works if the pandit is online.
  Future<ConsultationSession> requestLiveChat({
    required PanditModel pandit,
    required ConsultationRate rate,
    required String userId,
    required String userName,
    bool isPaid = true,
    String? paymentId,
    String? customerNote,
  });

  /// Joins a live chat session (user or pandit).
  /// Timer starts only when both parties have joined.
  Future<void> joinLiveChat(String sessionId);

  /// Gets pending live chat requests for a pandit.
  Future<List<ScheduledConsultationRequest>> getPendingLiveChats(String panditId);

  /// Pandit responds to a live chat request (accept/reject).
  Future<void> respondLiveChatRequest({
    required String sessionId,
    required String action, // 'accept' or 'reject'
  });

  /// Returns a broadcast stream of [SessionEvent]s for the given session.
  /// In production: establishes and returns a WebSocket channel stream.
  Stream<SessionEvent> connect(ConsultationSession session);

  /// Send a chat message from the user.
  Future<void> sendMessage(
    String sessionId,
    String text,
    String senderId, {
    String? imageUrl,
  });

  /// Upload a chat image and return a public URL.
  Future<String> uploadChatImage({
    required String sessionId,
    required String senderId,
    required Uint8List bytes,
    required String fileExt,
  });

  /// Request session extension (adds [addMinutes] minutes, triggers payment).
  /// Returns the new canonical [duration_minutes] as confirmed by the server.
  Future<int> extendSession(String sessionId, int addMinutes);

  /// Gracefully terminate the session.
  Future<void> endSession(String sessionId);

  /// Fetch live server state for a session: {consumed_minutes, duration_minutes, status}.
  /// Returns null if the session row does not exist.
  /// Used to re-sync the local countdown after the app was backgrounded.
  Future<Map<String, dynamic>?> fetchSessionStatus(String sessionId);

  /// Dispose all resources for [sessionId].
  void dispose(String sessionId);
}

/// Abstract repository for pandit data.
abstract class IPanditRepository {
  Future<List<PanditModel>> fetchOnlinePandits();
  Future<PanditModel?> fetchPandit(String panditId);

  Future<List<PanditModel>> fetchAlternativeOnlinePandits({
    required String excludePanditId,
    int limit = 3,
  });
}

// ── Mock Implementations ──────────────────────────────────────────────────────

/// Simulates WebSocket session events for development and UI preview.
/// Swap with `WsSessionRepository` to go live.
class MockSessionRepository implements ISessionRepository {
  final Map<String, StreamController<SessionEvent>> _controllers = {};
  final List<ScheduledConsultationRequest> _scheduledRequests = [];

  @override
  Future<ConsultationSession> startSession({
    required PanditModel pandit,
    required ConsultationRate rate,
    required String userId,
    required String userName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return ConsultationSession.create(
      pandit: pandit,
      rate: rate,
      userId: userId,
      userName: userName,
    );
  }

  @override
  Future<ConsultationSession?> fetchActiveSessionForUser({
    required String userId,
    required String userName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return null;
  }

  @override
  Future<ConsultationSession?> fetchActiveSessionForPandit({
    required String panditId,
    required String panditName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return null;
  }

  @override
  Future<ScheduledConsultationRequest> requestScheduledSession({
    required PanditModel pandit,
    required ConsultationRate rate,
    required String userId,
    required String userName,
    required DateTime scheduledFor,
    required bool isPaid,
    required String? paymentId,
    String? customerNote,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final req = ScheduledConsultationRequest(
      id: 'sched_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      userName: userName,
      panditId: pandit.id,
      panditName: pandit.name,
      status: ConsultationRequestStatus.pending,
      durationMinutes: rate.duration,
      amountPaise: rate.totalPaise,
      scheduledFor: scheduledFor,
      createdAt: DateTime.now(),
      customerNote: customerNote,
      isPaid: isPaid,
      paymentId: paymentId,
    );
    _scheduledRequests.add(req);
    return req;
  }

  @override
  Future<List<ScheduledConsultationRequest>> fetchUserScheduledRequests(
      String userId) async {
    await Future.delayed(const Duration(milliseconds: 250));
    return _scheduledRequests.where((r) => r.userId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<ScheduledConsultationRequest>> fetchPanditScheduledRequests(
      String panditId) async {
    await Future.delayed(const Duration(milliseconds: 250));
    return _scheduledRequests.where((r) => r.panditId == panditId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> panditRespondToScheduledRequest({
    required String sessionId,
    required String action,
    DateTime? proposedStart,
    String? note,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final i = _scheduledRequests.indexWhere((e) => e.id == sessionId);
    if (i == -1) return;
    final current = _scheduledRequests[i];
    ConsultationRequestStatus status = current.status;
    DateTime? proposed = current.proposedFor;

    if (action == 'accept') {
      status = ConsultationRequestStatus.confirmed;
      proposed = null;
    } else if (action == 'propose') {
      status = ConsultationRequestStatus.rescheduleProposed;
      proposed = proposedStart;
    } else if (action == 'reject') {
      status = ConsultationRequestStatus.rejected;
    }

    _scheduledRequests[i] = ScheduledConsultationRequest(
      id: current.id,
      userId: current.userId,
      userName: current.userName,
      panditId: current.panditId,
      panditName: current.panditName,
      status: status,
      durationMinutes: current.durationMinutes,
      amountPaise: current.amountPaise,
      scheduledFor: current.scheduledFor,
      createdAt: current.createdAt,
      proposedFor: proposed,
      customerNote: current.customerNote,
      panditNote: note,
      isPaid: current.isPaid,
      paymentId: current.paymentId,
    );
  }

  @override
  Future<void> userRespondToProposedTime({
    required String sessionId,
    required bool accept,
    String? note,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final i = _scheduledRequests.indexWhere((e) => e.id == sessionId);
    if (i == -1) return;
    final current = _scheduledRequests[i];
    _scheduledRequests[i] = ScheduledConsultationRequest(
      id: current.id,
      userId: current.userId,
      userName: current.userName,
      panditId: current.panditId,
      panditName: current.panditName,
      status: accept
          ? ConsultationRequestStatus.confirmed
          : ConsultationRequestStatus.refunded,
      durationMinutes: current.durationMinutes,
      amountPaise: current.amountPaise,
      scheduledFor: accept
          ? (current.proposedFor ?? current.scheduledFor)
          : current.scheduledFor,
      createdAt: current.createdAt,
      proposedFor: null,
      customerNote: note ?? current.customerNote,
      panditNote: current.panditNote,
      isPaid: current.isPaid,
      paymentId: current.paymentId,
    );
  }

  @override
  Future<void> markConsultationPaid({
    required String sessionId,
    required String paymentId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final i = _scheduledRequests.indexWhere((e) => e.id == sessionId);
    if (i == -1) return;
    final current = _scheduledRequests[i];
    _scheduledRequests[i] = ScheduledConsultationRequest(
      id: current.id,
      userId: current.userId,
      userName: current.userName,
      panditId: current.panditId,
      panditName: current.panditName,
      status: current.status,
      durationMinutes: current.durationMinutes,
      amountPaise: current.amountPaise,
      scheduledFor: current.scheduledFor,
      createdAt: current.createdAt,
      proposedFor: current.proposedFor,
      customerNote: current.customerNote,
      panditNote: current.panditNote,
      isPaid: true,
      paymentId: paymentId,
    );
  }

  @override
  Future<ConsultationSession> startScheduledSession({
    required ScheduledConsultationRequest request,
    required String currentUserId,
    required String currentUserName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final rate = ConsultationRate(
      duration: request.durationMinutes,
      totalPaise: request.amountPaise,
    );
    final pandit = PanditModel(
      id: request.panditId,
      name: request.panditName,
      specialty: 'Consultation',
      rating: 0,
      totalSessions: 0,
      isOnline: true,
      rates: [rate],
    );
    return ConsultationSession.create(
      pandit: pandit,
      rate: rate,
      userId: request.userId,
      userName: request.userName,
    );
  }

  @override
  Stream<SessionEvent> connect(ConsultationSession session) {
    final ctrl = StreamController<SessionEvent>.broadcast();
    _controllers[session.id] = ctrl;

    // Simulate server handshake after 800ms
    Future.delayed(const Duration(milliseconds: 800), () {
      if (ctrl.isClosed) return;
      ctrl.add(SessionStartedEvent(sessionId: session.id));

      // Pandit sends a welcome message after 1.5s
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (ctrl.isClosed) return;
        ctrl.add(TypingEvent(isTyping: true));

        Future.delayed(const Duration(milliseconds: 1200), () {
          if (ctrl.isClosed) return;
          ctrl.add(TypingEvent(isTyping: false));
          ctrl.add(PanditMessageEvent(
            message: ChatMessage(
              sessionId: session.id,
              senderId: session.pandit.id,
              senderName: session.pandit.name,
              text:
                  'Namaste 🙏 I am ${session.pandit.name}. How may I help you today?',
              isFromPandit: true,
            ),
          ));
        });
      });
    });

    return ctrl.stream;
  }

  @override
  Future<void> sendMessage(
    String sessionId,
    String text,
    String senderId, {
    String? imageUrl,
  }) async {
    final ctrl = _controllers[sessionId];
    if (ctrl == null || ctrl.isClosed) return;

    // Simulate pandit reading and replying after a short delay
    await Future.delayed(const Duration(milliseconds: 300));
    ctrl.add(TypingEvent(isTyping: true));

    await Future.delayed(
        Duration(milliseconds: 1500 + (text.length * 20).clamp(0, 3000)));

    if (ctrl.isClosed) return;
    ctrl.add(TypingEvent(isTyping: false));

    final replies = [
      'I understand. Based on your query, I can see that...',
      'That is a very relevant question. Let me explain from a Vedic perspective...',
      'According to your kundali, this is an auspicious period for ...',
      'You should perform a Ganesh puja before proceeding.',
      'The planetary alignments suggest caution in the coming weeks.',
      'From a Vastu standpoint, the north-east direction needs attention.',
    ];
    replies.shuffle();

    ctrl.add(PanditMessageEvent(
      message: ChatMessage(
        sessionId: sessionId,
        senderId: 'pandit',
        senderName: 'Pandit',
        text: replies.first,
        isFromPandit: true,
      ),
    ));
  }

  @override
  Future<String> uploadChatImage({
    required String sessionId,
    required String senderId,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return 'https://example.com/mock/$sessionId/$senderId.${fileExt.toLowerCase()}';
  }

  @override
  Future<int> extendSession(String sessionId, int addMinutes) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final ctrl = _controllers[sessionId];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.add(SessionExtendedEvent(addedSeconds: addMinutes * 60));
    }
    // Mock returns a plausible new total (base 15 min + all extensions).
    return 15 + addMinutes;
  }

  @override
  Future<void> endSession(String sessionId) async {
    final ctrl = _controllers[sessionId];
    if (ctrl == null || ctrl.isClosed) return;
    ctrl.add(const SessionEndedEvent(reason: 'user_ended'));
    await Future.delayed(const Duration(milliseconds: 200));
    dispose(sessionId);
  }

  /// Mock always returns "session is active with 0 consumed minutes" —
  /// the real implementation queries the consultations table.
  @override
  Future<Map<String, dynamic>?> fetchSessionStatus(String sessionId) async {
    return const {'status': 'active', 'consumed_minutes': 0, 'duration_minutes': 15};
  }

  @override
  Future<ConsultationSession> requestLiveChat({
    required PanditModel pandit,
    required ConsultationRate rate,
    required String userId,
    required String userName,
    bool isPaid = true,
    String? paymentId,
    String? customerNote,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return ConsultationSession.create(
      pandit: pandit,
      rate: rate,
      userId: userId,
      userName: userName,
    );
  }

  @override
  Future<void> joinLiveChat(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<List<ScheduledConsultationRequest>> getPendingLiveChats(
      String panditId) async {
    await Future.delayed(const Duration(milliseconds: 250));
    return [];
  }

  @override
  Future<void> respondLiveChatRequest({
    required String sessionId,
    required String action,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
  }

  @override
  void dispose(String sessionId) {
    _controllers[sessionId]?.close();
    _controllers.remove(sessionId);
  }
}

/// Returns the mock pandit list. Swap with Supabase query in production:
///   `await supabase.from('pandit_profiles').select().eq('is_online', true)`
class MockPanditRepository implements IPanditRepository {
  @override
  Future<List<PanditModel>> fetchOnlinePandits() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return kMockPandits;
  }

  @override
  Future<PanditModel?> fetchPandit(String panditId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return kMockPandits.firstWhere((p) => p.id == panditId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<PanditModel>> fetchAlternativeOnlinePandits({
    required String excludePanditId,
    int limit = 3,
  }) async {
    await Future.delayed(const Duration(milliseconds: 120));
    return kMockPandits
        .where((p) => p.isOnline && p.id != excludePanditId)
        .take(limit)
        .toList();
  }
}
