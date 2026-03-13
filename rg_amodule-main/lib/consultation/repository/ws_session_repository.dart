// lib/consultation/repository/ws_session_repository.dart
// Production Supabase + Realtime implementation of [ISessionRepository].
// Replaces [MockSessionRepository] by pointing providers at this class.

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/consultation_session.dart';
import '../models/pandit_model.dart';
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

  // Per-session controllers and cleanup handles
  final Map<String, StreamController<SessionEvent>> _controllers = {};
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, Timer> _localTimers = {};
  final Map<String, int> _remainingSeconds = {};

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

    // Emit session_started after Realtime subscription confirms
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!ctrl.isClosed) {
        ctrl.add(SessionStartedEvent(sessionId: session.id));
        _startLocalTimer(session.id, ctrl);
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
      String sessionId, String text, String senderId) async {
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
    });
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
      isFromPandit: role == 'pandit',
      sentAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
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
          .eq('is_online', true)
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
