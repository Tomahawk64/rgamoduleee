import 'package:uuid/uuid.dart';
import 'pandit_model.dart';

// ── Consultation Session Models ───────────────────────────────────────────────
//
// Core state objects for the paid live-chat consultation system.
//

// ── Session Status ────────────────────────────────────────────────────────────

enum SessionStatus {
  /// Not yet initialised.
  idle,

  /// WebSocket connecting / authenticating with backend.
  connecting,

  /// Session is active and time is running.
  active,

  /// Less than 60 seconds remaining — show warning badge.
  warning,

  /// Time fully elapsed — chat is locked.
  expired,

  /// Session ended gracefully by either party.
  ended,
}

extension SessionStatusX on SessionStatus {
  bool get isLive => this == SessionStatus.active || this == SessionStatus.warning;
  bool get isTerminal =>
      this == SessionStatus.expired || this == SessionStatus.ended;
}

// ── Consultation Flow Step ────────────────────────────────────────────────────

enum ConsultationFlowStep {
  /// Viewing pandit profile + selecting duration.
  selectDuration,

  /// Payment details / UPI placeholder.
  payment,

  /// Backend connecting (seat reserved, session creating).
  connecting,

  /// Session started — navigate to chat.
  started,
}

// ── Selected Duration ─────────────────────────────────────────────────────────

/// Wraps a [ConsultationRate] selected during the flow.
class SelectedRate {
  const SelectedRate({required this.rate, required this.pandit});
  final ConsultationRate rate;
  final PanditModel pandit;
}

// ── Chat Message ──────────────────────────────────────────────────────────────

/// Represents a single chat message in a consultation session.
class ChatMessage {
  ChatMessage({
    String? id,
    required this.sessionId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.isFromPandit,
    DateTime? sentAt,
  })  : id = id ?? const Uuid().v4(),
        sentAt = sentAt ?? DateTime.now();

  final String id;
  final String sessionId;
  final String senderId;
  final String senderName;
  final String text;
  final bool isFromPandit;
  final DateTime sentAt;

  /// True when this is a system message (session start, extend, expiry).
  bool get isSystem => senderId == 'system';

  ChatMessage copyWith({String? text}) => ChatMessage(
        id: id,
        sessionId: sessionId,
        senderId: senderId,
        senderName: senderName,
        text: text ?? this.text,
        isFromPandit: isFromPandit,
        sentAt: sentAt,
      );
}

// ── Consultation Session ──────────────────────────────────────────────────────

/// Immutable snapshot of a consultation session.
class ConsultationSession {
  const ConsultationSession({
    required this.id,
    required this.pandit,
    required this.userId,
    required this.userName,
    required this.rate,
    required this.totalSeconds,
    required this.status,
    required this.startedAt,
    this.extendedSeconds = 0,
  });

  final String id;
  final PanditModel pandit;
  final String userId;
  final String userName;
  final ConsultationRate rate;

  /// Purchased duration in seconds.
  final int totalSeconds;

  /// Additional time added via extensions.
  final int extendedSeconds;

  final SessionStatus status;
  final DateTime startedAt;

  /// Total allowed seconds including extensions.
  int get allottedSeconds => totalSeconds + extendedSeconds;

  StaticSessionInfo get info => StaticSessionInfo(
        panditName: pandit.name,
        specialty: pandit.specialty,
        durationMinutes: rate.duration,
        totalPaise: rate.totalPaise,
      );

  ConsultationSession copyWith({
    SessionStatus? status,
    int? extendedSeconds,
  }) =>
      ConsultationSession(
        id: id,
        pandit: pandit,
        userId: userId,
        userName: userName,
        rate: rate,
        totalSeconds: totalSeconds,
        extendedSeconds: extendedSeconds ?? this.extendedSeconds,
        status: status ?? this.status,
        startedAt: startedAt,
      );

  /// Factory to create a fresh session.
  factory ConsultationSession.create({
    required PanditModel pandit,
    required ConsultationRate rate,
    required String userId,
    required String userName,
  }) =>
      ConsultationSession(
        id: const Uuid().v4(),
        pandit: pandit,
        userId: userId,
        userName: userName,
        rate: rate,
        totalSeconds: rate.duration * 60,
        status: SessionStatus.connecting,
        startedAt: DateTime.now(),
      );
}

/// Minimal session info for displaying in chat app bar (avoids
/// heavy reference cycles).
class StaticSessionInfo {
  const StaticSessionInfo({
    required this.panditName,
    required this.specialty,
    required this.durationMinutes,
    required this.totalPaise,
  });
  final String panditName;
  final String specialty;
  final int durationMinutes;
  final int totalPaise;
  double get totalRupees => totalPaise / 100;
}

// ── Session Events (WebSocket Protocol) ──────────────────────────────────────
//
// In production these come from the WebSocket server.
// In mock they are emitted from [MockSessionRepository].
//

abstract class SessionEvent {
  const SessionEvent();
}

/// Server sends a chat message from pandit.
class PanditMessageEvent extends SessionEvent {
  const PanditMessageEvent({required this.message});
  final ChatMessage message;
}

/// Pandit started/stopped typing indicator.
class TypingEvent extends SessionEvent {
  const TypingEvent({required this.isTyping});
  final bool isTyping;
}

/// Server acknowledged session is live (handshake complete).
class SessionStartedEvent extends SessionEvent {
  const SessionStartedEvent({required this.sessionId});
  final String sessionId;
}

/// Server confirmed time extension.
class SessionExtendedEvent extends SessionEvent {
  const SessionExtendedEvent({required this.addedSeconds});
  final int addedSeconds;
}

/// Server-driven time update (server-controlled architecture).
/// In production the server sends this periodically; client adjusts display.
class TimeUpdateEvent extends SessionEvent {
  const TimeUpdateEvent({required this.remainingSeconds});
  final int remainingSeconds;
}

/// Server ended the session (graceful close or time expiry on server side).
class SessionEndedEvent extends SessionEvent {
  const SessionEndedEvent({required this.reason});
  final String reason;
}
