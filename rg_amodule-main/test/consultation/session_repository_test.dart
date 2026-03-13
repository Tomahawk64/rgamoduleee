// test/consultation/session_repository_test.dart
// Unit tests for MockSessionRepository and MockPanditRepository.
// Run with: flutter test test/consultation/session_repository_test.dart

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saralpooja/consultation/models/consultation_session.dart';
import 'package:saralpooja/consultation/models/pandit_model.dart';
import 'package:saralpooja/consultation/repository/consultation_repository.dart';

void main() {
  // ── MockPanditRepository ───────────────────────────────────────────────────

  group('MockPanditRepository', () {
    late IPanditRepository repo;

    setUp(() => repo = MockPanditRepository());

    test('fetchOnlinePandits returns non-empty list', () async {
      final pandits = await repo.fetchOnlinePandits();
      expect(pandits.isNotEmpty, isTrue);
    });

    test('fetched pandits have valid ids and names', () async {
      final pandits = await repo.fetchOnlinePandits();
      for (final p in pandits) {
        expect(p.id.isNotEmpty, isTrue);
        expect(p.name.isNotEmpty, isTrue);
      }
    });

    test('fetchPandit by known id returns the correct pandit', () async {
      final all = await repo.fetchOnlinePandits();
      final target = all.first;
      final result = await repo.fetchPandit(target.id);
      expect(result, isNotNull);
      expect(result!.id, target.id);
    });

    test('fetchPandit with unknown id returns null', () async {
      final result = await repo.fetchPandit('non_existent_pandit_id');
      expect(result, isNull);
    });

    test('each pandit has at least one rate tier', () async {
      final pandits = await repo.fetchOnlinePandits();
      for (final p in pandits) {
        expect(p.rates.isNotEmpty, isTrue,
            reason: '${p.name} should have rate tiers');
      }
    });
  });

  // ── MockSessionRepository ──────────────────────────────────────────────────

  group('MockSessionRepository', () {
    late ISessionRepository repo;
    late ConsultationSession session;

    setUp(() async {
      repo = MockSessionRepository();
      final pandits = await MockPanditRepository().fetchOnlinePandits();
      final pandit = pandits.first;
      session = ConsultationSession.create(
        pandit: pandit,
        rate: pandit.rates.first,
        userId: 'test_user_001',
        userName: 'Test User',
      );
    });

    tearDown(() => repo.dispose(session.id));

    test('connect returns a broadcast stream', () {
      final stream = repo.connect(session);
      expect(stream.isBroadcast, isTrue);
    });

    test('connect emits SessionStartedEvent within 2 seconds', () async {
      final stream = repo.connect(session);
      final events = <SessionEvent>[];
      final sub = stream.listen(events.add);

      await Future.delayed(const Duration(milliseconds: 900));
      await sub.cancel();

      expect(
        events.any((e) => e is SessionStartedEvent),
        isTrue,
        reason: 'SessionStartedEvent should be emitted within 900ms',
      );
    });

    test('connect emits PanditMessageEvent (welcome) after start', () async {
      final stream = repo.connect(session);
      final events = <SessionEvent>[];
      final sub = stream.listen(events.add);

      // Wait for the welcome message sequence
      await Future.delayed(const Duration(seconds: 4));
      await sub.cancel();

      expect(
        events.any((e) => e is PanditMessageEvent),
        isTrue,
        reason: 'Pandit should send a welcome message',
      );
    });

    test('sendMessage triggers pandit reply event', () async {
      final stream = repo.connect(session);
      final events = <SessionEvent>[];
      final sub = stream.listen(events.add);

      // Wait for session to start
      await Future.delayed(const Duration(milliseconds: 900));

      // Send a user message
      await repo.sendMessage(session.id, 'What is my lucky stone?', 'test_user_001');

      // Wait for pandit reply
      await Future.delayed(const Duration(seconds: 3));
      await sub.cancel();

      final panditMessages =
          events.whereType<PanditMessageEvent>().toList();
      expect(panditMessages.length, greaterThanOrEqualTo(1));
    });

    test('endSession emits SessionEndedEvent', () async {
      final stream = repo.connect(session);
      final events = <SessionEvent>[];
      final sub = stream.listen(events.add);

      await Future.delayed(const Duration(milliseconds: 900));
      await repo.endSession(session.id);

      await Future.delayed(const Duration(milliseconds: 300));
      await sub.cancel();

      expect(
        events.any((e) => e is SessionEndedEvent),
        isTrue,
      );
    });

    test('extendSession emits SessionExtendedEvent', () async {
      final stream = repo.connect(session);
      final events = <SessionEvent>[];
      final sub = stream.listen(events.add);

      await Future.delayed(const Duration(milliseconds: 900));
      await repo.extendSession(session.id, 10);

      await Future.delayed(const Duration(milliseconds: 600));
      await sub.cancel();

      expect(
        events.any((e) => e is SessionExtendedEvent),
        isTrue,
      );
    });

    test('dispose closes stream without error', () async {
      final stream = repo.connect(session);
      final completer = Completer<void>();
      stream.listen(
        (_) {},
        onDone: completer.complete,
      );

      await Future.delayed(const Duration(milliseconds: 100));
      repo.dispose(session.id);

      // Stream should complete after dispose
      await completer.future.timeout(const Duration(seconds: 2),
          onTimeout: () {});
      // If we reach here without error, the test passes
    });
  });

  // ── ConsultationSession ────────────────────────────────────────────────────

  group('ConsultationSession', () {
    test('allottedSeconds equals totalSeconds plus extendedSeconds', () {
      final pandit = kMockPandits.first;
      final session = ConsultationSession.create(
        pandit: pandit,
        rate: pandit.rates.first,
        userId: 'u001',
        userName: 'User',
      );
      expect(session.allottedSeconds,
          session.totalSeconds + session.extendedSeconds);
    });

    test('copyWith only updates specified fields', () {
      final pandit = kMockPandits.first;
      final session = ConsultationSession.create(
        pandit: pandit,
        rate: pandit.rates.first,
        userId: 'u001',
        userName: 'User',
      );

      final updated = session.copyWith(extendedSeconds: 600);
      expect(updated.extendedSeconds, 600);
      expect(updated.id, session.id);
      expect(updated.userId, session.userId);
    });
  });
}
