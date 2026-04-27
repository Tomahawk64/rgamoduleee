import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../support/models/support_ticket.dart';
import '../../support/providers/support_provider.dart';

class AdminSupportTicketsScreen extends ConsumerStatefulWidget {
  const AdminSupportTicketsScreen({super.key});

  @override
  ConsumerState<AdminSupportTicketsScreen> createState() => _AdminSupportTicketsScreenState();
}

class _AdminSupportTicketsScreenState extends ConsumerState<AdminSupportTicketsScreen> {
  String? _filterStatus;

  @override
  Widget build(BuildContext context) {
    ref.listen(supportRealtimeTickProvider, (_, __) {
      ref.invalidate(adminSupportTicketsProvider(_filterStatus));
    });

    final async = ref.watch(adminSupportTicketsProvider(_filterStatus));

    return Scaffold(
      appBar: AppBar(title: const Text('Support Tickets')),
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: DropdownButtonFormField<String?>(
              initialValue: _filterStatus,
              decoration: const InputDecoration(
                labelText: 'Filter Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('All')),
                DropdownMenuItem<String?>(value: 'submitted', child: Text('Submitted')),
                DropdownMenuItem<String?>(value: 'processing', child: Text('Processing')),
                DropdownMenuItem<String?>(value: 'completed', child: Text('Completed')),
                DropdownMenuItem<String?>(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (value) => setState(() => _filterStatus = value),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load tickets: $e')),
              data: (tickets) {
                if (tickets.isEmpty) {
                  return const Center(child: Text('No support tickets found.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(adminSupportTicketsProvider(_filterStatus)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: tickets.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _TicketCard(ticket: tickets[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends ConsumerStatefulWidget {
  const _TicketCard({required this.ticket});
  final SupportTicket ticket;

  @override
  ConsumerState<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends ConsumerState<_TicketCard> {
  bool _updating = false;

  Color _statusColor(String status) {
    switch (status) {
      case 'submitted':
        return AppColors.warning;
      case 'processing':
        return AppColors.info;
      case 'completed':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _updating = true);
    try {
      await ref.read(supportRepositoryProvider).adminUpdateTicketStatus(
            ticketId: widget.ticket.id,
            status: status,
          );
      ref.invalidate(adminSupportTicketsProvider(null));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ticket marked $status')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final statusColor = _statusColor(t.status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.requesterName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  t.statusLabel,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${t.requesterRole.toUpperCase()} • ${t.phone}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text(t.problem),
          if ((t.adminNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Admin note: ${t.adminNote}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 10),
          if (_updating)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: t.status == 'submitted' ? () => _updateStatus('processing') : null,
                  child: const Text('Mark Processing'),
                ),
                FilledButton(
                  onPressed: t.status == 'processing' || t.status == 'submitted'
                      ? () => _updateStatus('completed')
                      : null,
                  child: const Text('Mark Completed'),
                ),
                TextButton(
                  onPressed: t.status == 'completed' || t.status == 'rejected'
                      ? null
                      : () => _updateStatus('rejected'),
                  child: const Text('Reject'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
