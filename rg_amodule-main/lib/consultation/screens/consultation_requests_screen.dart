import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/role_enum.dart';
import '../models/scheduled_consultation_request.dart';
import '../providers/consultation_provider.dart';

class ConsultationRequestsScreen extends ConsumerWidget {
  const ConsultationRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login.')));
    }

    final isPandit = user.role == UserRole.pandit;
    final async = isPandit
        ? ref.watch(panditScheduledConsultationsProvider(user.id))
        : ref.watch(userScheduledConsultationsProvider(user.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isPandit
            ? 'Consultation Requests'
            : 'My Consultations'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No consultation requests yet.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _RequestCard(
              request: list[i],
              isPandit: isPandit,
              onActionDone: () {
                if (isPandit) {
                  ref.invalidate(panditScheduledConsultationsProvider(user.id));
                } else {
                  ref.invalidate(userScheduledConsultationsProvider(user.id));
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({
    required this.request,
    required this.isPandit,
    required this.onActionDone,
  });

  final ScheduledConsultationRequest request;
  final bool isPandit;
  final VoidCallback onActionDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(sessionRepositoryProvider);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isPandit ? request.userName : request.panditName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              _StatusChip(status: request.status),
            ],
          ),
          const SizedBox(height: 8),
          Text('Scheduled: ${_fmt(request.scheduledFor)}'),
          if (request.proposedFor != null)
            Text('Proposed: ${_fmt(request.proposedFor!)}',
                style: const TextStyle(color: AppColors.warning)),
          Text('Duration: ${request.durationMinutes} min • ${request.amountLabel}'),
          if ((request.customerNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('User note: ${request.customerNote!}'),
          ],
          if ((request.panditNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Pandit note: ${request.panditNote!}'),
          ],
          const SizedBox(height: 10),
          if (isPandit && request.status == ConsultationRequestStatus.pending)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () async {
                    await repo.panditRespondToScheduledRequest(
                      sessionId: request.id,
                      action: 'accept',
                    );
                    onActionDone();
                  },
                  child: const Text('Accept'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final dt = await _pickDateTime(context);
                    if (dt == null) return;
                    await repo.panditRespondToScheduledRequest(
                      sessionId: request.id,
                      action: 'propose',
                      proposedStart: dt,
                    );
                    onActionDone();
                  },
                  child: const Text('Propose Time'),
                ),
                TextButton(
                  onPressed: () async {
                    await repo.panditRespondToScheduledRequest(
                      sessionId: request.id,
                      action: 'reject',
                    );
                    onActionDone();
                  },
                  child: const Text('Reject'),
                ),
              ],
            ),
          if (!isPandit &&
              request.status == ConsultationRequestStatus.rescheduleProposed)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () async {
                    await repo.userRespondToProposedTime(
                      sessionId: request.id,
                      accept: true,
                    );
                    onActionDone();
                  },
                  child: const Text('Accept New Time'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    await repo.userRespondToProposedTime(
                      sessionId: request.id,
                      accept: false,
                    );
                    onActionDone();
                  },
                  child: const Text('Decline'),
                ),
              ],
            ),
          // Start Chat for confirmed consultations (both pandit & user)
          if (request.status == ConsultationRequestStatus.confirmed)
            _StartChatButton(request: request, onActionDone: onActionDone),
        ],
      ),
    );
  }

  static String _fmt(DateTime dt) {
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
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m $p';
  }

  static Future<DateTime?> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      initialDate: now,
    );
    if (d == null || !context.mounted) return null;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 2))),
    );
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ConsultationRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ConsultationRequestStatus.pending => AppColors.warning,
      ConsultationRequestStatus.confirmed => AppColors.success,
      ConsultationRequestStatus.rescheduleProposed => AppColors.info,
      ConsultationRequestStatus.active => AppColors.success,
      ConsultationRequestStatus.ended => AppColors.textSecondary,
      ConsultationRequestStatus.expired => AppColors.warning,
      ConsultationRequestStatus.refunded => AppColors.info,
      ConsultationRequestStatus.rejected => AppColors.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ── Start Chat Button ─────────────────────────────────────────────────────────

class _StartChatButton extends ConsumerStatefulWidget {
  const _StartChatButton({
    required this.request,
    required this.onActionDone,
  });

  final ScheduledConsultationRequest request;
  final VoidCallback onActionDone;

  @override
  ConsumerState<_StartChatButton> createState() => _StartChatButtonState();
}

class _StartChatButtonState extends ConsumerState<_StartChatButton> {
  bool _loading = false;

  Future<void> _startChat() async {
    // Check if scheduled time has arrived (allow 5 min early)
    final now = DateTime.now();
    final earliest = widget.request.scheduledFor.subtract(const Duration(minutes: 5));
    if (now.isBefore(earliest)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Scheduled time hasn\'t arrived yet. Chat opens at ${_fmtDt(widget.request.scheduledFor)}.',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final repo = ref.read(sessionRepositoryProvider);
      final user = ref.read(currentUserProvider);
      final session = await repo.startScheduledSession(
        request: widget.request,
        currentUserId: user?.id ?? '',
        currentUserName: user?.name ?? 'User',
      );
      if (mounted) {
        context.push(Routes.consultationChat, extra: session);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start chat: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _fmtDt(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m $p';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _loading ? null : _startChat,
        icon: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.chat_rounded, size: 18),
        label: const Text('Start Chat'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
