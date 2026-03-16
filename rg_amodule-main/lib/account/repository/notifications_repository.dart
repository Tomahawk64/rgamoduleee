import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';

abstract class INotificationsRepository {
  Stream<List<AppNotification>> watchNotifications(String userId);
  Future<void> markAllRead(String userId);
  Future<void> markRead(String notificationId);
  Future<void> createNotification({
    required String userId,
    required AppNotificationType type,
    required String title,
    required String body,
    String? entityType,
    String? entityId,
    Map<String, dynamic> metadata,
  });
}

class SupabaseNotificationsRepository implements INotificationsRepository {
  const SupabaseNotificationsRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .cast<Map<String, dynamic>>()
              .map(AppNotification.fromJson)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  @override
  Future<void> markAllRead(String userId) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', userId)
        .isFilter('read_at', null);
  }

  @override
  Future<void> markRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', notificationId)
        .isFilter('read_at', null);
  }

  @override
  Future<void> createNotification({
    required String userId,
    required AppNotificationType type,
    required String title,
    required String body,
    String? entityType,
    String? entityId,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    await _client.rpc('create_app_notification', params: {
      'p_user_id': userId,
      'p_type': _dbType(type),
      'p_title': title,
      'p_body': body,
      'p_entity_type': entityType,
      'p_entity_id': entityId,
      'p_metadata': metadata,
    });
  }

  static String _dbType(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.bookingRequested:
        return 'booking_requested';
      case AppNotificationType.bookingConfirmed:
        return 'booking_confirmed';
      case AppNotificationType.bookingAssigned:
        return 'booking_assigned';
      case AppNotificationType.bookingCancelled:
        return 'booking_cancelled';
      case AppNotificationType.paymentPending:
        return 'payment_pending';
      case AppNotificationType.paymentCompleted:
        return 'payment_completed';
      case AppNotificationType.consultationRequested:
        return 'consultation_requested';
      case AppNotificationType.consultationConfirmed:
        return 'consultation_confirmed';
      case AppNotificationType.consultationRescheduleProposed:
        return 'consultation_reschedule_proposed';
      case AppNotificationType.consultationRejected:
        return 'consultation_rejected';
      case AppNotificationType.consultationRefunded:
        return 'consultation_refunded';
      case AppNotificationType.general:
        return 'general';
    }
  }
}

class MockNotificationsRepository implements INotificationsRepository {
  MockNotificationsRepository();

  final _items = <AppNotification>[
    AppNotification(
      id: 'demo_1',
      userId: 'mock_user',
      type: AppNotificationType.bookingConfirmed,
      title: 'Booking confirmed',
      body: 'Your demo booking has been confirmed.',
      createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
      isRead: false,
    ),
  ];

  final _controller = StreamController<List<AppNotification>>.broadcast();

  void _emit() {
    final sorted = [..._items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _controller.add(sorted);
  }

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) {
    Future.microtask(_emit);
    return _controller.stream.map(
      (items) => items.where((item) => item.userId == userId).toList(),
    );
  }

  @override
  Future<void> markAllRead(String userId) async {
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.userId != userId || item.isRead) continue;
      _items[i] = AppNotification(
        id: item.id,
        userId: item.userId,
        type: item.type,
        title: item.title,
        body: item.body,
        createdAt: item.createdAt,
        isRead: true,
        entityType: item.entityType,
        entityId: item.entityId,
        metadata: item.metadata,
      );
    }
    _emit();
  }

  @override
  Future<void> markRead(String notificationId) async {
    final index = _items.indexWhere((item) => item.id == notificationId);
    if (index == -1) return;
    final item = _items[index];
    _items[index] = AppNotification(
      id: item.id,
      userId: item.userId,
      type: item.type,
      title: item.title,
      body: item.body,
      createdAt: item.createdAt,
      isRead: true,
      entityType: item.entityType,
      entityId: item.entityId,
      metadata: item.metadata,
    );
    _emit();
  }

  @override
  Future<void> createNotification({
    required String userId,
    required AppNotificationType type,
    required String title,
    required String body,
    String? entityType,
    String? entityId,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    _items.add(
      AppNotification(
        id: 'demo_${_items.length + 1}',
        userId: userId,
        type: type,
        title: title,
        body: body,
        createdAt: DateTime.now(),
        isRead: false,
        entityType: entityType,
        entityId: entityId,
        metadata: metadata,
      ),
    );
    _emit();
  }
}