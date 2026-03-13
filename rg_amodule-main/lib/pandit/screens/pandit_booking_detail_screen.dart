// lib/pandit/screens/pandit_booking_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../booking/models/booking_model.dart';
import '../../booking/models/booking_status.dart';
import '../../core/theme/app_colors.dart';
import '../controllers/pandit_dashboard_controller.dart';
import '../models/pandit_dashboard_models.dart';
import '../providers/pandit_provider.dart';

class PanditBookingDetailScreen extends ConsumerWidget {
  const PanditBookingDetailScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignment =
        ref.watch(panditDashboardProvider.notifier).findById(bookingId);

    if (assignment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Detail')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              SizedBox(height: 16),
              Text('Booking not found'),
            ],
          ),
        ),
      );
    }

    final booking = assignment.booking;
    final isNew = assignment.isPendingAction;
    final isActive = assignment.isActive;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Booking Detail',
            style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status banner ──────────────────────────────────────────────
            _StatusBanner(assignment: assignment),
            const SizedBox(height: 16),

            // ── Ceremony card ──────────────────────────────────────────────
            _DetailCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailCardHeader(
                    icon: Icons.temple_hindu,
                    title: booking.packageTitle,
                    trailing: Text(
                      '₹${booking.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _TagRow(tags: [
                    booking.category,
                    booking.isPaid ? '✓ Paid' : 'Payment Pending',
                  ]),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Date',
                    value: booking.formattedDate,
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.access_time_outlined,
                    label: 'Time',
                    value: booking.slot.label,
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: booking.location.isOnline
                        ? Icons.videocam_outlined
                        : Icons.location_on_outlined,
                    label: 'Location',
                    value: booking.location.isOnline
                        ? 'Online / Virtual'
                        : booking.location.displayAddress,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Client card ────────────────────────────────────────────────
            _DetailCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(
                      icon: Icons.person_outline, title: 'Client'),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.tag,
                    label: 'Booking ID',
                    value: booking.id,
                    mono: true,
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.receipt_outlined,
                    label: 'Package ID',
                    value: booking.packageId,
                    mono: true,
                  ),
                  if (booking.notes != null && booking.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _InfoRow(
                      icon: Icons.notes_outlined,
                      label: 'Notes',
                      value: booking.notes!,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Payment card ───────────────────────────────────────────────
            _DetailCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Payment'),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.currency_rupee,
                    label: 'Amount',
                    value: '₹${booking.amount.toStringAsFixed(0)}',
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: booking.isPaid
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_outlined,
                    label: 'Status',
                    value: booking.isPaid ? 'Paid' : 'Payment Pending',
                    valueColor:
                        booking.isPaid ? AppColors.success : AppColors.warning,
                  ),
                  if (booking.paymentId != null) ...[
                    const SizedBox(height: 6),
                    _InfoRow(
                      icon: Icons.receipt_long_outlined,
                      label: 'Payment ID',
                      value: booking.paymentId!,
                      mono: true,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Actions ────────────────────────────────────────────────────
            if (isNew) _NewRequestActions(booking: booking),
            if (isActive) _ActiveActions(booking: booking, assignment: assignment),
            if (assignment.isCompleted) _CompletedActions(booking: booking),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Status Banner ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.assignment});
  final PanditAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final booking = assignment.booking;
    final color = booking.status.color;

    String title;
    String subtitle;
    if (assignment.isPendingAction) {
      title = 'New Request';
      subtitle = 'Review and respond to this booking assignment';
    } else if (assignment.isActive) {
      title = 'Accepted · Upcoming';
      subtitle =
          'This booking is confirmed. Prepare for ${booking.formattedDate}';
    } else if (assignment.isCompleted) {
      title = 'Completed';
      subtitle = 'Service rendered on ${booking.formattedDate}';
    } else {
      title = booking.status.label;
      subtitle = '';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(booking.status.icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action sections ───────────────────────────────────────────────────────────

class _NewRequestActions extends ConsumerWidget {
  const _NewRequestActions({required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(panditDashboardProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionDivider(title: 'Respond to this request'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            await ctrl.acceptAssignment(booking.id);
            if (context.mounted) context.pop();
          },
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Accept Booking',
              style: TextStyle(fontWeight: FontWeight.bold)),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: AppColors.success,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _confirmReject(context, ref),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Reject Booking',
              style: TextStyle(fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  void _confirmReject(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject booking?'),
        content: Text(
          '"${booking.packageTitle}" will be returned to the pending pool '
          'for reassignment.',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              ctx.pop();
              await ref
                  .read(panditDashboardProvider.notifier)
                  .rejectAssignment(booking.id);
              if (context.mounted) context.pop();
            },
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Yes, Reject'),
          ),
        ],
      ),
    );
  }
}

class _ActiveActions extends ConsumerWidget {
  const _ActiveActions({
    required this.booking,
    required this.assignment,
  });

  final BookingModel booking;
  final PanditAssignment assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(panditDashboardProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionDivider(title: 'Actions'),
        const SizedBox(height: 12),

        // Upload proof
        OutlinedButton.icon(
          onPressed: () => context.push(
            '/booking/${booking.id}/upload-proof',
            extra: {
              'panditId': booking.panditId ?? 'mock_pandit',
              'title': booking.packageTitle,
            },
          ),
          icon: const Icon(Icons.video_camera_front_outlined),
          label: const Text('Upload Video Proof',
              style: TextStyle(fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            foregroundColor: AppColors.info,
            side: const BorderSide(color: AppColors.info),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Mark complete
        FilledButton.icon(
          onPressed: () => _confirmComplete(context, ref, ctrl),
          icon: const Icon(Icons.task_alt_rounded),
          label: const Text('Mark as Completed',
              style: TextStyle(fontWeight: FontWeight.bold)),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmComplete(BuildContext context, WidgetRef ref,
      PanditDashboardController ctrl) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as completed?'),
        content: Text(
          'Confirm that "${booking.packageTitle}" service has been rendered '
          'successfully.',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              ctx.pop();
              await ctrl.updateStatus(
                  booking.id, BookingStatus.completed);
              if (context.mounted) context.pop();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

class _CompletedActions extends StatelessWidget {
  const _CompletedActions({required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionDivider(title: 'Actions'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.push(
            '/booking/${booking.id}/upload-proof',
            extra: {
              'panditId': booking.panditId ?? 'mock_pandit',
              'title': booking.packageTitle,
            },
          ),
          icon: const Icon(Icons.video_camera_front_outlined),
          label: const Text('View / Update Proof',
              style: TextStyle(fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DetailCardHeader extends StatelessWidget {
  const _DetailCardHeader({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.mono = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: valueColor ?? AppColors.textPrimary,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.tags});
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: tags.map((tag) {
        final isPositive = tag.startsWith('✓');
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isPositive
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            tag,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isPositive ? AppColors.success : AppColors.primary,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.divider)),
      ],
    );
  }
}
