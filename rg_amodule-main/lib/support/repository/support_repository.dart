import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/support_ticket.dart';

class SupportRepository {
  const SupportRepository(this._client);

  final SupabaseClient _client;

  Future<void> submitTicket({
    required String requesterId,
    required String requesterRole,
    required String requesterName,
    required String phone,
    required String problem,
  }) async {
    final normalizedPhone = phone.trim();
    final normalizedProblem = problem.trim();

    if (normalizedPhone.length < 7 || normalizedPhone.length > 20) {
      throw StateError('Please enter a valid contact number.');
    }
    if (normalizedProblem.length < 10 || normalizedProblem.length > 2000) {
      throw StateError('Problem description must be 10-2000 characters.');
    }

    await _client.from('support_tickets').insert({
      'requester_id': requesterId,
      'requester_role': requesterRole,
      'requester_name': requesterName,
      'phone': normalizedPhone,
      'problem': normalizedProblem,
    });
  }

  Future<List<SupportTicket>> fetchMyTickets(String requesterId) async {
    final rows = await _client
        .from('support_tickets')
        .select('id,requester_id,requester_role,requester_name,phone,problem,status,admin_note,handled_by,created_at,updated_at,resolved_at')
        .eq('requester_id', requesterId)
        .order('created_at', ascending: false)
        .range(0, 99);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(SupportTicket.fromRow)
        .toList();
  }

  Future<List<SupportTicket>> fetchAllTicketsForAdmin({String? status}) async {
    final base = _client
        .from('support_tickets')
        .select('id,requester_id,requester_role,requester_name,phone,problem,status,admin_note,handled_by,created_at,updated_at,resolved_at');

    final rows = (status == null || status.isEmpty
            ? base
            : base.eq('status', status))
        .order('created_at', ascending: false)
        .range(0, 299);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(SupportTicket.fromRow)
        .toList();
  }

  Future<void> adminUpdateTicketStatus({
    required String ticketId,
    required String status,
    String? adminNote,
  }) async {
    final result = await _client.rpc('admin_update_support_ticket_status', params: {
      'p_ticket_id': ticketId,
      'p_status': status,
      'p_admin_note': adminNote,
    });

    final data = result as Map<String, dynamic>;
    if (data['error'] != null) {
      throw StateError(data['error'] as String);
    }
  }
}
