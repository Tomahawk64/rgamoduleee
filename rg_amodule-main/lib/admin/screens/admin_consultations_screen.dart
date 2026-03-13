// lib/admin/screens/admin_consultations_screen.dart
// View all consultation sessions, end active sessions, issue refund override.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../models/admin_models.dart';
import '../providers/admin_providers.dart';

class AdminConsultationsScreen extends ConsumerStatefulWidget {
  const AdminConsultationsScreen({super.key});

  @override
  ConsumerState<AdminConsultationsScreen> createState() =>
      _AdminConsultationsScreenState();
}

class _AdminConsultationsScreenState
    extends ConsumerState<AdminConsultationsScreen> {
  AdminSessionStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    final all = state.consultations;

    final filtered = _filter == null
        ? all
        : all.where((c) => c.status == _filter).toList();

    final activeLive =
        all.where((c) => c.status == AdminSessionStatus.active).length;

    ref.listen<AdminState>(adminProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.error!),
          backgroundColor: AppColors.error,
        ));
        ref.read(adminProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Consultations',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Live indicator
          if (activeLive > 0)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$activeLive session${activeLive > 1 ? 's' : ''} currently live',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Filter chips
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'All (${all.length})',
                  selected: _filter == null,
                  color: AppColors.textSecondary,
                  onTap: () => setState(() => _filter = null),
                ),
                ...AdminSessionStatus.values.map((s) {
                  final count = all.where((c) => c.status == s).length;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _FilterChip(
                      label: '${s.label} ($count)',
                      selected: _filter == s,
                      color: s.color,
                      onTap: () => setState(() => _filter = s),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // List
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No sessions found',
                        style: TextStyle(
                            color: AppColors.textSecondary)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 10),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _ConsultationRow(
                      session: filtered[i],
                      onEndSession: () =>
                          _confirmEndSession(context, ref, filtered[i]),
                      onRefund: () =>
                          _confirmRefund(context, ref, filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmEndSession(BuildContext context, WidgetRef ref,
      AdminConsultationRow session) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End session?'),
        content: Text(
          'This will forcefully terminate the live session between '
          '"${session.panditName}" and "${session.clientName}".',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ctx.pop();
              ref.read(adminProvider.notifier).endSession(session.id);
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }

  void _confirmRefund(BuildContext context, WidgetRef ref,
      AdminConsultationRow session) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refund Override'),
        content: Text(
          'Mark a manual refund of ${session.formattedAmount} for the session '
          'between "${session.panditName}" and "${session.clientName}"?\n\n'
          'This is a placeholder — actual refund processing will be handled '
          'by the payment gateway integration.',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ctx.pop();
              ref
                  .read(adminProvider.notifier)
                  .refundOverride(session.id);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Refund of ${session.formattedAmount} marked for processing.'),
                backgroundColor: AppColors.info,
              ));
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.info),
            child: const Text('Mark Refund'),
          ),
        ],
      ),
    );
  }
}

// ── Consultation row ──────────────────────────────────────────────────────────

class _ConsultationRow extends StatelessWidget {
  const _ConsultationRow({
    required this.session,
    required this.onEndSession,
    required this.onRefund,
  });

  final AdminConsultationRow session;
  final VoidCallback onEndSession;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context) {
    final statusColor = session.status.color;
    final isActive = session.status == AdminSessionStatus.active;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(
                color: AppColors.success.withValues(alpha: 0.4),
                width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Status
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActive)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      session.status.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                session.formattedAmount,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Participants
          Row(
            children: [
              const Icon(Icons.supervised_user_circle_outlined,
                  size: 13, color: AppColors.secondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  session.panditName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.swap_horiz,
                    size: 14, color: AppColors.textSecondary),
              ),
              const Icon(Icons.person_outline,
                  size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  session.clientName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.schedule,
                  size: 11, color: AppColors.textSecondary),
              const SizedBox(width: 3),
              Text(
                '${session.durationMinutes} min · ${session.formattedDate}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.tag,
                  size: 11, color: AppColors.textSecondary),
              Text(
                session.id,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textHint,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),

          // Actions
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 8),
          Row(
            children: [
              // End session (only for active)
              if (isActive) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEndSession,
                    icon: const Icon(Icons.stop_circle_outlined,
                        size: 14),
                    label: const Text('End Session',
                        style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(
                          color: AppColors.error),
                      minimumSize: const Size.fromHeight(34),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Refund override (for ended/expired)
              if (session.status == AdminSessionStatus.ended ||
                  session.status == AdminSessionStatus.expired)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRefund,
                    icon: const Icon(Icons.undo_rounded, size: 14),
                    label: const Text('Refund Override',
                        style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.info,
                      side: const BorderSide(color: AppColors.info),
                      minimumSize: const Size.fromHeight(34),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

              // Refunded badge
              if (session.status == AdminSessionStatus.refunded)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 12, color: AppColors.info),
                      SizedBox(width: 4),
                      Text('Refund Issued',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.info,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
            color:
                selected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
