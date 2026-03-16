enum ConsultationRequestStatus {
  pending,
  confirmed,
  rescheduleProposed,
  active,
  ended,
  expired,
  refunded,
  rejected,
}

extension ConsultationRequestStatusX on ConsultationRequestStatus {
  String get label {
    switch (this) {
      case ConsultationRequestStatus.pending:
        return 'Pending Pandit Confirmation';
      case ConsultationRequestStatus.confirmed:
        return 'Confirmed';
      case ConsultationRequestStatus.rescheduleProposed:
        return 'Reschedule Proposed';
      case ConsultationRequestStatus.active:
        return 'Live';
      case ConsultationRequestStatus.ended:
        return 'Ended';
      case ConsultationRequestStatus.expired:
        return 'Expired';
      case ConsultationRequestStatus.refunded:
        return 'Refunded';
      case ConsultationRequestStatus.rejected:
        return 'Rejected';
    }
  }

  static ConsultationRequestStatus fromDb(String status) {
    switch (status) {
      case 'pending':
        return ConsultationRequestStatus.pending;
      case 'confirmed':
        return ConsultationRequestStatus.confirmed;
      case 'reschedule_proposed':
        return ConsultationRequestStatus.rescheduleProposed;
      case 'active':
        return ConsultationRequestStatus.active;
      case 'ended':
        return ConsultationRequestStatus.ended;
      case 'expired':
        return ConsultationRequestStatus.expired;
      case 'refunded':
        return ConsultationRequestStatus.refunded;
      case 'rejected':
        return ConsultationRequestStatus.rejected;
      default:
        return ConsultationRequestStatus.pending;
    }
  }
}

class ScheduledConsultationRequest {
  const ScheduledConsultationRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.panditId,
    required this.panditName,
    required this.status,
    required this.durationMinutes,
    required this.amountPaise,
    required this.scheduledFor,
    required this.createdAt,
    this.proposedFor,
    this.customerNote,
    this.panditNote,
    this.isPaid = false,
    this.paymentId,
  });

  final String id;
  final String userId;
  final String userName;
  final String panditId;
  final String panditName;
  final ConsultationRequestStatus status;
  final int durationMinutes;
  final int amountPaise;
  final DateTime scheduledFor;
  final DateTime createdAt;
  final DateTime? proposedFor;
  final String? customerNote;
  final String? panditNote;
  final bool isPaid;
  final String? paymentId;

  String get amountLabel => '₹${(amountPaise / 100).toStringAsFixed(0)}';
}
