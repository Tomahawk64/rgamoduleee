class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.requesterId,
    required this.requesterRole,
    required this.requesterName,
    required this.phone,
    required this.problem,
    required this.status,
    this.adminNote,
    this.handledBy,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
  });

  final String id;
  final String requesterId;
  final String requesterRole;
  final String requesterName;
  final String phone;
  final String problem;
  final String status;
  final String? adminNote;
  final String? handledBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;

  bool get isClosed => status == 'completed' || status == 'rejected';

  String get statusLabel {
    switch (status) {
      case 'submitted':
        return 'Submitted';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  static SupportTicket fromRow(Map<String, dynamic> row) {
    return SupportTicket(
      id: row['id'] as String,
      requesterId: row['requester_id'] as String,
      requesterRole: row['requester_role'] as String? ?? 'user',
      requesterName: row['requester_name'] as String? ?? 'User',
      phone: row['phone'] as String? ?? '',
      problem: row['problem'] as String? ?? '',
      status: row['status'] as String? ?? 'submitted',
      adminNote: row['admin_note'] as String?,
      handledBy: row['handled_by'] as String?,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ?? DateTime.now(),
      resolvedAt: row['resolved_at'] == null
          ? null
          : DateTime.tryParse(row['resolved_at'] as String),
    );
  }
}
