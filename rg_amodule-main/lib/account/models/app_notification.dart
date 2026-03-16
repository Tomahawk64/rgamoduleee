import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum AppNotificationType {
  bookingRequested,
  bookingConfirmed,
  bookingAssigned,
  bookingCancelled,
  paymentPending,
  paymentCompleted,
  consultationRequested,
  consultationConfirmed,
  consultationRescheduleProposed,
  consultationRejected,
  consultationRefunded,
  general,
}

extension AppNotificationTypeX on AppNotificationType {
  static AppNotificationType fromDb(String? value) {
    switch (value) {
      case 'booking_requested':
        return AppNotificationType.bookingRequested;
      case 'booking_confirmed':
        return AppNotificationType.bookingConfirmed;
      case 'booking_assigned':
        return AppNotificationType.bookingAssigned;
      case 'booking_cancelled':
        return AppNotificationType.bookingCancelled;
      case 'payment_pending':
        return AppNotificationType.paymentPending;
      case 'payment_completed':
        return AppNotificationType.paymentCompleted;
      case 'consultation_requested':
        return AppNotificationType.consultationRequested;
      case 'consultation_confirmed':
        return AppNotificationType.consultationConfirmed;
      case 'consultation_reschedule_proposed':
        return AppNotificationType.consultationRescheduleProposed;
      case 'consultation_rejected':
        return AppNotificationType.consultationRejected;
      case 'consultation_refunded':
        return AppNotificationType.consultationRefunded;
      default:
        return AppNotificationType.general;
    }
  }

  Color get color {
    switch (this) {
      case AppNotificationType.bookingRequested:
      case AppNotificationType.paymentPending:
        return AppColors.warning;
      case AppNotificationType.bookingConfirmed:
      case AppNotificationType.paymentCompleted:
      case AppNotificationType.consultationConfirmed:
        return AppColors.success;
      case AppNotificationType.bookingAssigned:
      case AppNotificationType.consultationRequested:
      case AppNotificationType.consultationRescheduleProposed:
      case AppNotificationType.consultationRefunded:
        return AppColors.info;
      case AppNotificationType.bookingCancelled:
      case AppNotificationType.consultationRejected:
        return AppColors.error;
      case AppNotificationType.general:
        return AppColors.primary;
    }
  }

  IconData get icon {
    switch (this) {
      case AppNotificationType.bookingRequested:
        return Icons.calendar_today_rounded;
      case AppNotificationType.bookingConfirmed:
        return Icons.verified_rounded;
      case AppNotificationType.bookingAssigned:
        return Icons.person_pin_circle_outlined;
      case AppNotificationType.bookingCancelled:
        return Icons.cancel_outlined;
      case AppNotificationType.paymentPending:
        return Icons.pending_actions_rounded;
      case AppNotificationType.paymentCompleted:
        return Icons.payments_rounded;
      case AppNotificationType.consultationRequested:
        return Icons.forum_outlined;
      case AppNotificationType.consultationConfirmed:
        return Icons.video_call_rounded;
      case AppNotificationType.consultationRescheduleProposed:
        return Icons.update_rounded;
      case AppNotificationType.consultationRejected:
        return Icons.block_rounded;
      case AppNotificationType.consultationRefunded:
        return Icons.currency_rupee_rounded;
      case AppNotificationType.general:
        return Icons.notifications_none_rounded;
    }
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.entityType,
    this.entityId,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String userId;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? entityType;
  final String? entityId;
  final Map<String, dynamic> metadata;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'];
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: AppNotificationTypeX.fromDb(json['type'] as String?),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      isRead: json['read_at'] != null,
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      metadata: metadata is Map<String, dynamic>
          ? metadata
          : metadata is Map
              ? Map<String, dynamic>.from(metadata)
              : const <String, dynamic>{},
    );
  }
}