// lib/consultation/repository/ws_session_repository.dart
// Production Supabase + Realtime implementation of [ISessionRepository].
// Replaces [MockSessionRepository] by pointing providers at this class.

import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../account/models/app_notification.dart';
import '../../account/repository/notifications_repository.dart';
import '../../core/utils/supabase_storage_upload_helper.dart';
import '../models/consultation_session.dart';
import '../models/pandit_model.dart';
import '../models/scheduled_consultation_request.dart';
import 'consultation_repository.dart';

// ── WsSessionRepository ────────────────────────────────────────────────────────
//
// Uses Supabase Realtime (Postgres Changes) to receive new pandit messages,
// and RPCs for session lifecycle (start / end / extend).
//
// Timer is driven server-side via periodic TimeUpdateEvent rows written by
// a Supabase Edge Function (or cron worker). For smoother UX, a local 1-second
// Timer interpolates between server ticks.
//

class WsSessionRepository implements ISessionRepository {
  WsSessionRepository(this._client);

  final SupabaseClient _client;
  static const _chatMediaBucket = 'consultation-chat-media';

  // Per-session controllers and cleanup handles
  final Map<String, StreamController<SessionEvent>> _controllers = {};
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, Timer> _localTimers = {};
  final Map<String, int> _remainingSeconds = {};
  final Map<String, bool> _bothJoinedEmitted = {};

  // ── startSession ─────────────────────────────────────────────────────────

  @override
  Future<ConsultationSession> startSession({
    required PanditModel pandit,
    required ConsultationRate rate,
    required String userId,
    required String userName,
  }) async {
    final result = await _client.rpc('start_consultation_session', params: {
      'p_pandit_id':        pandit.id,
      'p_duration_minutes': rate.duration,
      // price stored in rupees in DB (numeric 10,2); paise÷100
      'p_price':            rate.totalPaise / 100.0,
    });

    final data = result as Map<String, dynamic>;
    if (data['error'] != null) {
      throw StateError(data['error'] as String);
    }

    final sessionId  = data['session_id'] as String;
    final startedAt  = DateTime.tryParse(
          data['started_at'] as String? ?? '') ??
        DateTime.now();

    return ConsultationSession(
      id:           sessionId,
      pandit:       pandit,
      userId:       userId,
      userName:     userName,
      rate:         rate,
      totalSeconds: rate.duration * 60,
      status:       SessionStatus.connecting,
      startedAt:    startedAt,
    );
  }

  @override
  Future<ConsultationSession?> fetchActiveSessionForUser({
    required String userId,
    required String userName,
  }) async {
    final row = await _client
        .from('consultations')
        .select('id,pandit_id,user_id,start_ts,duration_minutes,price,status,user:profiles!consultations_user_id_fkey(full_name)')
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('start_ts', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;

    final panditId = row['pandit_id'] as String?;
    if (panditId == null) return null;
    final pandit = await SupabasePanditRepository(_client).fetchPandit(panditId);
    if (pandit == null) return null;

    final durationMinutes = row['duration_minutes'] as int? ?? 10;
    final totalPaise = (((row['price'] as num?)?.toDouble() ?? 99.0) * 100).toInt();
    final rate = ConsultationRate(
      duration: durationMinutes,
      totalPaise: totalPaise,
    );

    return ConsultationSession(
      id: row['id'] as String,
      pandit: pandit,
      userId: userId,
      userName: userName,
      rate: rate,
      totalSeconds: durationMinutes * 60,
      status: SessionStatus.connecting,
      startedAt: DateTime.tryParse(row['start_ts'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  Future<ConsultationSession?> fetchActiveSessionForPandit({
    required String panditId,
    required String panditName,
  }) async {
    final row = await _client
        .from('consultations')
        .select(
          'id,pandit_id,user_id,start_ts,duration_minutes,price,status,'
          'user:profiles!consultations_user_id_fkey(full_name)',
        )
        .eq('pandit_id', panditId)
        .eq('status', 'active')
        .order('start_ts', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;

    final pandit = await SupabasePanditRepository(_client).fetchPandit(panditId);
    if (pandit == null) return null;

    final userId = row['user_id'] as String? ?? '';
    final userProfile = row['user'] as Map<String, dynamic>? ?? const {};
    final userName = userProfile['full_name'] as String? ?? 'User';
    final durationMinutes = row['duration_minutes'] as int? ?? 10;
    final totalPaise = (((row['price'] as num?)?.toDouble() ?? 99.0) * 100).toInt();
    final rate = ConsultationRate(
      duration: durationMinutes,
      totalPaise: totalPaise,
    );

    return ConsultationSession(
      id: row['id'] as String,
      pandit: pandit,
      userId: userId,
      userName: userName,
      rate: rate,
      totalSeconds: durationMinutes * 60,
      status: SessionStatus.connecting,
      startedAt: DateTime.tryParse(row['start_ts'] as String? ?? '') ?? DateTime.now(),
    );
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
    final result = await _client.rpc('request_consultation_slot', params: {
      'p_pandit_id': pandit.id,
      'p_duration_minutes': rate.duration,
      'p_price': rate.totalPaise / 100.0,
      'p_scheduled_for': scheduledFor.toUtc().toIso8601String(),
      'p_is_paid': isPaid,
      'p_payment_id': paymentId,
      'p_customer_note': customerNote,
    });

    final data = result as Map<String, dynamic>;
    if (data['error'] != null) {
      throw StateError(data['error'] as String);
    }

    final sessionId = data['session_id'] as String;
    final row = await _client
        .from('consultations')
        .select('''
          id,user_id,pandit_id,status,duration_minutes,price,start_ts,created_at,
          proposed_ts,customer_note,pandit_note,is_paid,payment_id,
          user:profiles!consultations_user_id_fkey(full_name),
          pandit:profiles!consultations_pandit_id_fkey(full_name)
        ''')
        .eq('id', sessionId)
        .single();
    final request = _scheduledFromRow(row);

    if (isPaid) {
      await _createNotification(
        userId: userId,
        type: AppNotificationType.paymentCompleted,
        title: 'Payment completed',
        body: 'Payment received for your consultation with ${pandit.name}.',
        entityType: 'consultation',
        entityId: request.id,
      );
    }
    await _createNotification(
      userId: userId,
      type: AppNotificationType.consultationRequested,
      title: 'Consultation requested',
      body: 'Your slot request for ${pandit.name} was sent for ${_formatDateTime(request.scheduledFor)}.',
      entityType: 'consultation',
      entityId: request.id,
    );
    await _createNotification(
      userId: pandit.id,
      type: AppNotificationType.consultationRequested,
      title: 'New consultation request',
      body: '$userName requested a consultation for ${_formatDateTime(request.scheduledFor)}.',
      entityType: 'consultation',
      entityId: request.id,
    );

    return request;
  }

  @override
  Future<List<ScheduledConsultationRequest>> fetchUserScheduledRequests(
      String userId) async {
    final rows = await _client
        .from('consultations')
        .select('''
          id,user_id,pandit_id,status,duration_minutes,price,start_ts,created_at,
          proposed_ts,customer_note,pandit_note,is_paid,payment_id,
          user:profiles!consultations_user_id_fkey(full_name),
          pandit:profiles!consultations_pandit_id_fkey(full_name)
        ''')
        .eq('user_id', userId)
        .inFilter('status', [
          'pending',
          'confirmed',
          'reschedule_proposed',
          'active',
          'ended',
          'expired',
          'refunded',
          'rejected'
        ])
        .order('created_at', ascending: false)
        .range(0, 99);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_scheduledFromRow)
        .toList();
  }

  @override
  Future<List<ScheduledConsultationRequest>> fetchPanditScheduledRequests(
      String panditId) async {
    final rows = await _client
        .from('consultations')
        .select('''
          id,user_id,pandit_id,status,duration_minutes,price,start_ts,created_at,
          proposed_ts,customer_note,pandit_note,is_paid,payment_id,
          user:profiles!consultations_user_id_fkey(full_name),
          pandit:profiles!consultations_pandit_id_fkey(full_name)
        ''')
        .eq('pandit_id', panditId)
        .inFilter('status', [
          'pending',
          'confirmed',
          'reschedule_proposed',
          'active',
          'ended',
          'expired',
          'refunded',
          'rejected'
        ])
        .order('created_at', ascending: false)
        .range(0, 99);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_scheduledFromRow)
        .toList();
  }

  @override
  Future<void> panditRespondToScheduledRequest({
    required String sessionId,
    required String action,
    DateTime? proposedStart,
    String? note,
  }) async {
    final result = await _client.rpc('pandit_respond_consultation_request', params: {
      'p_session_id': sessionId,
      'p_action': action,
      'p_proposed_ts': proposedStart?.toUtc().toIso8601String(),
      'p_note': note,
    });

    final data = result as Map<String, dynamic>;
    if (data['error'] != null) {
      throw StateError(data['error'] as String);
    }

    final request = await _fetchScheduledRequest(sessionId);
    switch (action) {
      case 'accept':
        await _createNotification(
          userId: request.userId,
          type: AppNotificationType.consultationConfirmed,
          title: 'Consultation confirmed',
          body: '${request.panditName} confirmed your consultation for ${_formatDateTime(request.scheduledFor)}.',
          entityType: 'consultation',
          entityId: sessionId,
        );
      case 'propose':
        final proposed = request.proposedFor ?? proposedStart;
        if (proposed != null) {
          await _createNotification(
            userId: request.userId,
            type: AppNotificationType.consultationRescheduleProposed,
            title: 'New consultation time proposed',
            body: '${request.panditName} proposed ${_formatDateTime(proposed)} for your consultation.',
            entityType: 'consultation',
            entityId: sessionId,
          );
        }
      case 'reject':
        await _createNotification(
          userId: request.userId,
          type: request.isPaid
              ? AppNotificationType.consultationRefunded
              : AppNotificationType.consultationRejected,
          title: request.isPaid ? 'Consultation refunded' : 'Consultation rejected',
          body: request.isPaid
              ? '${request.panditName} declined the request. A refund is pending for this consultation.'
              : '${request.panditName} declined your consultation request.',
          entityType: 'consultation',
          entityId: sessionId,
        );
    }
  }

  @override
  Future<void> userRespondToProposedTime({
    required String sessionId,
    required bool accept,
    String? note,
  }) async {
    final result = await _client.rpc('user_respond_consultation_proposal', params: {
      'p_session_id': sessionId,
      'p_accept': accept,
      'p_note': note,
    });

    final data = result as Map<String, dynamic>;
    if (data['error'] != null) {
      throw StateError(data['error'] as String);
    }

    final request = await _fetchScheduledRequest(sessionId);
    if (accept) {
      await _createNotification(
        userId: request.userId,
        type: AppNotificationType.consultationConfirmed,
        title: 'Consultation confirmed',
        body: 'You accepted the new slot for ${_formatDateTime(request.scheduledFor)}.',
        entityType: 'consultation',
        entityId: sessionId,
      );
      await _createNotification(
        userId: request.panditId,
        type: AppNotificationType.consultationConfirmed,
        title: 'User accepted new time',
        body: '${request.userName} accepted the updated consultation slot.',
        entityType: 'consultation',
        entityId: sessionId,
      );
      return;
    }

    await _createNotification(
      userId: request.userId,
      type: AppNotificationType.consultationRefunded,
      title: 'Consultation declined',
      body: 'You declined the proposed time. This consultation is now marked for refund.',
      entityType: 'consultation',
      entityId: sessionId,
    );
    await _createNotification(
      userId: request.panditId,
      type: AppNotificationType.consultationRejected,
      title: 'User declined proposed time',
      body: '${request.userName} declined the proposed consultation time.',
      entityType: 'consultation',
      entityId: sessionId,
    );
  }

  // ── startScheduledSession ────────────────────────────────────────────────

  @override
  Future<ConsultationSession> startScheduledSession({
    required ScheduledConsultationRequest request,
    required String currentUserId,
    required String currentUserName,
  }) async {
    final result = await _client.rpc('start_scheduled_consultation', params: {
      'p_session_id': request.id,
    });

    final data = result as Map<String, dynamic>;
    if (data['error'] != null) {
      throw StateError(data['error'] as String);
    }

    final startedAt = DateTime.tryParse(
          data['started_at'] as String? ?? '') ??
        DateTime.now();

    // Fetch pandit model for the chat screen
    final pandit = await SupabasePanditRepository(_client)
        .fetchPandit(request.panditId);
    if (pandit == null) {
      throw StateError('Pandit profile not found');
    }

    final rate = ConsultationRate(
      duration: request.durationMinutes,
      totalPaise: request.amountPaise,
    );

    // Notify both parties
    await _createNotification(
      userId: request.userId,
      type: AppNotificationType.consultationConfirmed,
      title: 'Consultation started',
      body: 'Your consultation with ${request.panditName} is now live!',
      entityType: 'consultation',
      entityId: request.id,
    );
    await _createNotification(
      userId: request.panditId,
      type: AppNotificationType.consultationConfirmed,
      title: 'Consultation started',
      body: 'Your consultation with ${request.userName} is now live!',
      entityType: 'consultation',
      entityId: request.id,
    );

    return ConsultationSession(
      id: request.id,
      pandit: pandit,
      userId: request.userId,
      userName: request.userName,
      rate: rate,
      totalSeconds: request.durationMinutes * 60,
      status: SessionStatus.connecting,
      startedAt: startedAt,
    );
  }

  // ── connect ─────────────────────────────────────────────────────────────

  @override
  Stream<SessionEvent> connect(ConsultationSession session) {
    final ctrl = StreamController<SessionEvent>.broadcast();
    _controllers[session.id] = ctrl;

    final initialSeconds = _calcRemaining(session);
    _remainingSeconds[session.id] = initialSeconds;

    // ── Subscription safety ──────────────────────────────────────────────
    // Track whether Realtime confirmed the subscription.
    // If the channel errors or times out before confirmation, roll back
    // the DB session immediately so the user is not charged for an orphan.
    bool subscribed = false;
    Timer? subscribeTimeoutTimer;

    // 3-second hard timeout: if Realtime hasn't acked, force rollback.
    subscribeTimeoutTimer = Timer(const Duration(seconds: 3), () {
      if (subscribed) return;
      _rollbackOrphanedSession(session.id, ctrl,
          'Realtime connection timed out — session has been safely cancelled.');
    });

    // Subscribe to Supabase Realtime for new messages in this session
    final channel = _client
        .channel('consultation:${session.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'consultation_id',
            value: session.id,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            if (!ctrl.isClosed && row.isNotEmpty) {
              ctrl.add(PanditMessageEvent(message: _messageFromRow(row)));
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'consultations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: session.id,
          ),
          callback: (payload) {
            if (ctrl.isClosed) return;
            final row = payload.newRecord;
            // Status changed to ended / expired
            final status = row['status'] as String?;
            if (status == 'ended' || status == 'expired') {
              ctrl.add(SessionEndedEvent(reason: status ?? 'ended'));
            }
            // Duration extended
            final newDuration = row['duration_minutes'] as int?;
            if (newDuration != null) {
              final currentRemaining =
                  _remainingSeconds[session.id] ?? initialSeconds;
              ctrl.add(SessionExtendedEvent(
                  addedSeconds: newDuration * 60 - session.allottedSeconds));
              _remainingSeconds[session.id] =
                  currentRemaining + newDuration * 60 - session.allottedSeconds;
            }
            // Both parties joined — start timer
            final pJoined = row['pandit_joined_at'];
            final uJoined = row['user_joined_at'];
            if (pJoined != null && uJoined != null &&
                !(_bothJoinedEmitted[session.id] ?? false)) {
              _bothJoinedEmitted[session.id] = true;
              ctrl.add(SessionStartedEvent(sessionId: session.id));
              _startLocalTimer(session.id, ctrl);
            }
          },
        )
        .subscribe((RealtimeSubscribeStatus status, [Object? error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            // Channel confirmed — cancel the timeout guard.
            subscribed = true;
            subscribeTimeoutTimer?.cancel();
            subscribeTimeoutTimer = null;
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            // Subscription failed — roll back the DB session if not yet confirmed.
            subscribeTimeoutTimer?.cancel();
            if (!subscribed) {
              _rollbackOrphanedSession(
                session.id,
                ctrl,
                'Realtime subscription failed (${status.name}) — session safely cancelled.',
              );
            }
          }
        });

    _channels[session.id] = channel;

    // After Realtime subscription is set up, call join RPC and decide whether
    // to start the timer immediately (both joined) or wait.
    Future.delayed(const Duration(milliseconds: 600), () async {
      if (ctrl.isClosed) return;
      try {
        final joinResult = await _client.rpc('join_consultation_chat', params: {
          'p_session_id': session.id,
        });
        final data = joinResult as Map<String, dynamic>? ?? {};
        final bothJoined = data['both_joined'] as bool? ?? false;
        if (ctrl.isClosed) return;

        if (bothJoined) {
          _bothJoinedEmitted[session.id] = true;
          ctrl.add(SessionStartedEvent(sessionId: session.id));
          _startLocalTimer(session.id, ctrl);
        } else {
          // Only this party is in — wait for the Realtime UPDATE to detect
          // the other party's join (handled in the consultations UPDATE callback).
          ctrl.add(const WaitingForPartnerEvent());
        }
      } catch (_) {
        // If join RPC fails (e.g., instant session without the columns),
        // fall back to starting immediately.
        if (!ctrl.isClosed) {
          _bothJoinedEmitted[session.id] = true;
          ctrl.add(SessionStartedEvent(sessionId: session.id));
          _startLocalTimer(session.id, ctrl);
        }
      }
    });

    return ctrl.stream;
  }

  // ── _rollbackOrphanedSession ─────────────────────────────────────────────
  //
  // Called when a Realtime subscription fails/times-out after the DB session
  // row was already created by start_consultation_session RPC.
  // Calls end_consultation_session with reason='admin' to prevent the user
  // from being charged for an unreachable session.
  //
  void _rollbackOrphanedSession(
    String sessionId,
    StreamController<SessionEvent> ctrl,
    String uiMessage,
  ) {
    // Fire-and-forget: don't await, as we must not block the stream.
    _client.rpc('end_consultation_session', params: {
      'p_session_id': sessionId,
      'p_reason':     'admin',
    }).catchError((Object e) {
      // Intentionally silent — the UI error is surfaced via the stream error below.
    });

    if (!ctrl.isClosed) {
      ctrl.addError(StateError(uiMessage));
      ctrl.close();
    }
    dispose(sessionId);
  }

  // ── sendMessage ──────────────────────────────────────────────────────────

  @override
  Future<void> sendMessage(
    String sessionId,
    String text,
    String senderId, {
    String? imageUrl,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    // Guard: verify session is still active server-side
    try {
      final row = await _client
          .from('consultations')
          .select('status')
          .eq('id', sessionId)
          .single();
      if (row['status'] != 'active') throw StateError('Session has ended');
    } on PostgrestException {
      // Row not found — session was terminated
      throw StateError('Session not found');
    }

    await _client.from('messages').insert({
      'consultation_id': sessionId,
      'sender_id': userId,
      'content': text,
      'image_url': imageUrl,
    });
  }

  @override
  Future<String> uploadChatImage({
    required String sessionId,
    required String senderId,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    final ext = fileExt.replaceAll('.', '').toLowerCase();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final contentType = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/jpeg';
    return SupabaseStorageUploadHelper.uploadImageWithFallback(
      client: _client,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      folder: '$sessionId/$senderId',
      primaryBucket: _chatMediaBucket,
      fallbackBuckets: [
        SupabaseStorageUploadHelper.profileImagesBucket,
      ],
    );
  }

  // ── extendSession ────────────────────────────────────────────────────────

  /// Atomically increments [duration_minutes] on the server via the
  /// `increment_session_duration` RPC (no client-side read-modify-write).
  ///
  /// Returns the new canonical [duration_minutes] re-fetched from the DB.
  /// Using an RPC for the write means concurrent callers each receive their
  /// own committed total — no lost updates.
  @override
  Future<int> extendSession(String sessionId, int addMinutes) async {
    // ── 1. Atomic server-side increment ──────────────────────────────────
    try {
      await _client.rpc('increment_session_duration', params: {
        'p_session_id':  sessionId,
        'p_add_minutes': addMinutes,
      });
    } on PostgrestException catch (e) {
      throw StateError('Failed to extend session: ${e.message}');
    }

    // ── 2. Re-fetch canonical new duration — no local arithmetic ─────────
    // fetchSessionStatus already guards .single() with a try/catch and
    // returns null on PGRST116 (row not found), so no unguarded .single().
    final status = await fetchSessionStatus(sessionId);
    final newDurationMins = (status?['duration_minutes'] as int?) ?? 0;
    if (newDurationMins == 0) {
      throw StateError(
          'extendSession: could not confirm new duration — '
          'session $sessionId may have already ended.');
    }
    return newDurationMins;
  }

  // ── endSession ───────────────────────────────────────────────────────────

  @override
  Future<void> endSession(String sessionId) async {
    await _client.rpc('end_consultation_session', params: {
      'p_session_id': sessionId,
      'p_reason': 'manual',
    });
    dispose(sessionId);
  }

  // ── fetchSessionStatus ───────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>?> fetchSessionStatus(String sessionId) async {
    try {
      final row = await _client
          .from('consultations')
          .select('consumed_minutes, duration_minutes, status')
          .eq('id', sessionId)
          .single();
      return row;
    } on PostgrestException {
      return null;
    }
  }

  // ── dispose ──────────────────────────────────────────────────────────────

  @override
  void dispose(String sessionId) {
    _localTimers[sessionId]?.cancel();
    _localTimers.remove(sessionId);

    _channels[sessionId]?.unsubscribe();
    _channels.remove(sessionId);

    _controllers[sessionId]?.close();
    _controllers.remove(sessionId);

    _remainingSeconds.remove(sessionId);
    _bothJoinedEmitted.remove(sessionId);
  }

  // ── private helpers ───────────────────────────────────────────────────────

  /// Seconds remaining at connection time based on start_ts + allotted time.
  int _calcRemaining(ConsultationSession session) {
    final elapsed = DateTime.now().difference(session.startedAt).inSeconds;
    return (session.allottedSeconds - elapsed).clamp(0, session.allottedSeconds);
  }

  void _startLocalTimer(
      String sessionId, StreamController<SessionEvent> ctrl) {
    _localTimers[sessionId]?.cancel();
    _localTimers[sessionId] =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (ctrl.isClosed) {
        timer.cancel();
        return;
      }
      final remaining = (_remainingSeconds[sessionId] ?? 0) - 1;
      _remainingSeconds[sessionId] = remaining.clamp(0, 999999);
      ctrl.add(TimeUpdateEvent(remainingSeconds: remaining.clamp(0, 999999)));
      if (remaining <= 0) {
        timer.cancel();
        ctrl.add(const SessionEndedEvent(reason: 'time_expired'));
      }
    });
  }

  static ChatMessage _messageFromRow(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    final role = profile?['role'] as String? ?? 'user';
    return ChatMessage(
      id: row['id'] as String,
      sessionId: row['consultation_id'] as String,
      senderId: row['sender_id'] as String,
      senderName: profile?['full_name'] as String? ?? 'Pandit',
      text: row['content'] as String,
        imageUrl: row['image_url'] as String?,
      isFromPandit: role == 'pandit',
      sentAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static ScheduledConsultationRequest _scheduledFromRow(
      Map<String, dynamic> row) {
    final user = row['user'] as Map<String, dynamic>? ?? const {};
    final pandit = row['pandit'] as Map<String, dynamic>? ?? const {};
    return ScheduledConsultationRequest(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      userName: user['full_name'] as String? ?? '',
      panditId: row['pandit_id'] as String,
      panditName: pandit['full_name'] as String? ?? '',
      status: ConsultationRequestStatusX.fromDb(
        row['status'] as String? ?? 'pending',
      ),
      durationMinutes: row['duration_minutes'] as int? ?? 0,
      amountPaise: (((row['price'] as num?)?.toDouble() ?? 0.0) * 100).toInt(),
      scheduledFor: DateTime.tryParse(row['start_ts'] as String? ?? '') ??
          DateTime.now(),
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      proposedFor: row['proposed_ts'] != null
          ? DateTime.tryParse(row['proposed_ts'] as String)
          : null,
      customerNote: row['customer_note'] as String?,
      panditNote: row['pandit_note'] as String?,
      isPaid: row['is_paid'] as bool? ?? false,
      paymentId: row['payment_id'] as String?,
    );
  }

  Future<ScheduledConsultationRequest> _fetchScheduledRequest(String sessionId) async {
    final row = await _client
        .from('consultations')
        .select('''
          id,user_id,pandit_id,status,duration_minutes,price,start_ts,created_at,
          proposed_ts,customer_note,pandit_note,is_paid,payment_id,
          user:profiles!consultations_user_id_fkey(full_name),
          pandit:profiles!consultations_pandit_id_fkey(full_name)
        ''')
        .eq('id', sessionId)
        .single();
    return _scheduledFromRow(row);
  }

  Future<void> _createNotification({
    required String userId,
    required AppNotificationType type,
    required String title,
    required String body,
    String? entityType,
    String? entityId,
  }) async {
    try {
      await SupabaseNotificationsRepository(_client).createNotification(
        userId: userId,
        type: type,
        title: title,
        body: body,
        entityType: entityType,
        entityId: entityId,
      );
    } catch (_) {
      // Notifications must not block consultation transitions.
    }
  }

  static String _formatDateTime(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $period';
  }
}

// ── SupabasePanditRepository ──────────────────────────────────────────────────

class SupabasePanditRepository implements IPanditRepository {
  const SupabasePanditRepository(this._client);

  final SupabaseClient _client;

  // Schema: pandit_details(id pk→profiles.id, specialties text[], languages text[],
  //   experience_years int, bio text, is_online bool, consultation_enabled bool)
  // Join: profiles!id(full_name, avatar_url, rating)   — pd.id = profiles.id
  // Join: consultation_rates!pandit_id(duration_minutes, price, is_active)

  static const _kSelect = '''
    id,
    specialties,
    languages,
    experience_years,
    bio,
    is_online,
    consultation_enabled
  ''';

  @override
  Future<List<PanditModel>> fetchOnlinePandits() async {
    try {
      final rows = await _client
          .from('pandit_details')
          .select(_kSelect)
          .eq('consultation_enabled', true)
          .order('experience_years', ascending: false);

      final panditRows = (rows as List).cast<Map<String, dynamic>>();
      final ids = panditRows.map((r) => r['id'] as String).toSet();
      if (ids.isEmpty) return const [];

      final profileRows = await _client
          .from('profiles')
          .select('id, full_name, avatar_url, rating')
          .inFilter('id', ids.toList());
      final profilesById = <String, Map<String, dynamic>>{};
      for (final r in (profileRows as List)) {
        final row = r as Map<String, dynamic>;
        profilesById[row['id'] as String] = row;
      }

      final ratesRows = await _client
          .from('consultation_rates')
          .select('pandit_id, duration_minutes, price, is_active')
          .inFilter('pandit_id', ids.toList());
      final ratesByPandit = <String, List<Map<String, dynamic>>>{};
      for (final r in (ratesRows as List)) {
        final row = r as Map<String, dynamic>;
        final pid = row['pandit_id'] as String?;
        if (pid == null) continue;
        ratesByPandit.putIfAbsent(pid, () => []).add(row);
      }

      return panditRows.map((row) {
        final id = row['id'] as String;
        return _panditFromRow({
          ...row,
          'profiles': profilesById[id] ?? const <String, dynamic>{},
          'consultation_rates':
              ratesByPandit[id] ?? const <Map<String, dynamic>>[],
        });
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch pandits: ${e.message}');
    }
  }

  @override
  Future<PanditModel?> fetchPandit(String panditId) async {
    try {
      final row = await _client
          .from('pandit_details')
          .select(_kSelect)
          .eq('id', panditId)
          .single();

      final profileRow = await _client
          .from('profiles')
          .select('id, full_name, avatar_url, rating')
          .eq('id', panditId)
          .maybeSingle();

      final ratesRows = await _client
          .from('consultation_rates')
          .select('pandit_id, duration_minutes, price, is_active')
          .eq('pandit_id', panditId);

      return _panditFromRow({
        ...row,
        'profiles': profileRow ?? const <String, dynamic>{},
        'consultation_rates':
            (ratesRows as List).cast<Map<String, dynamic>>(),
      });
    } on PostgrestException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static PanditModel _panditFromRow(Map<String, dynamic> row) {
    // profiles!id returns a single map (one-to-one relationship)
    final profile = row['profiles'] as Map<String, dynamic>? ?? {};

    // specialties is text[] from DB
    final specialties =
        (row['specialties'] as List? ?? []).cast<String>();

    // languages is text[] from pandit_details (not from profiles)
    final langs =
        (row['languages'] as List? ?? ['Hindi']).cast<String>();

    // consultation_rates!pandit_id returns a list; filter active, sort by duration
    final rateRows = (row['consultation_rates'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .where((r) => r['is_active'] as bool? ?? true)
        .toList()
      ..sort((a, b) => (a['duration_minutes'] as int)
          .compareTo(b['duration_minutes'] as int));

    // price in DB is numeric(10,2) in rupees → convert to paise
    final rates = rateRows.isEmpty
        ? const [
            ConsultationRate(duration: 10, totalPaise: 9900),
            ConsultationRate(duration: 15, totalPaise: 14900),
            ConsultationRate(duration: 20, totalPaise: 19900),
          ]
        : rateRows
            .map((r) => ConsultationRate(
                  duration: r['duration_minutes'] as int,
                  totalPaise:
                      ((r['price'] as num).toDouble() * 100).round(),
                ))
            .toList();

    return PanditModel(
      // pandit_details.id == profiles.id (one-to-one)
      id: row['id'] as String,
      name: profile['full_name'] as String? ?? 'Pandit',
      specialty: specialties.isNotEmpty
          ? specialties.join(', ')
          : 'General Pandit',
      rating: (profile['rating'] as num?)?.toDouble() ?? 4.5,
      // total_sessions not in schema — set to 0 (displayable but not critical)
      totalSessions: 0,
      isOnline: row['is_online'] as bool? ?? false,
      languagesSpoken: langs.isNotEmpty ? langs : const ['Hindi'],
      avatarUrl: profile['avatar_url'] as String?,
      experienceYears: row['experience_years'] as int? ?? 0,
      bio: row['bio'] as String?,
      rates: rates,
    );
  }
}
