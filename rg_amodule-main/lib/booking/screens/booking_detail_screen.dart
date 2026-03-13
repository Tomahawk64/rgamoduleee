import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/models/auth_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../models/role_enum.dart';
import '../models/booking_model.dart';
import '../models/booking_status.dart';
import '../models/proof_model.dart';
import '../providers/booking_provider.dart';
import '../providers/proof_provider.dart';
import '../widgets/stream_video_player.dart';

class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingByIdProvider(bookingId));

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Booking not found')),
      );
    }

    return _DetailView(booking: booking);
  }
}

class _DetailView extends ConsumerWidget {
  const _DetailView({required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (booking.status.isActive)
            TextButton(
              onPressed: () => _confirmCancel(context, ref),
              style:
                  TextButton.styleFrom(foregroundColor: cs.error),
              child: const Text('Cancel'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status header ───────────────────────────────────────
            _StatusHeader(booking: booking),
            const SizedBox(height: 20),

            // ── Package details ─────────────────────────────────────
            _SectionCard(
              title: 'Service',
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.temple_hindu_rounded,
                        color: cs.onPrimaryContainer, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(booking.packageTitle,
                            style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700)),
                        Text(booking.category,
                            style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Text(
                    '₹${booking.amount.toStringAsFixed(0)}',
                    style: tt.titleMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Date & time ─────────────────────────────────────────
            _SectionCard(
              title: 'Schedule',
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.event_rounded,
                    label: 'Date',
                    value: booking.formattedDate,
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    icon: Icons.schedule_rounded,
                    label: 'Time Slot',
                    value: booking.slot.label,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Location ────────────────────────────────────────────
            _SectionCard(
              title: booking.location.isOnline ? 'Session' : 'Location',
              child: _DetailRow(
                icon: booking.location.isOnline
                    ? Icons.videocam_rounded
                    : Icons.location_on_rounded,
                label: booking.location.isOnline ? 'Mode' : 'Address',
                value: booking.location.isOnline
                    ? booking.location.meetLink != null
                        ? 'Online — ${booking.location.meetLink}'
                        : 'Online — link will be shared after confirmation'
                    : booking.location.displayAddress,
              ),
            ),
            const SizedBox(height: 12),

            // ── Pandit ──────────────────────────────────────────────
            _SectionCard(
              title: 'Pandit',
              child: _DetailRow(
                icon: Icons.person_rounded,
                label: booking.isAutoAssigned ? 'Assignment' : 'Requested',
                value: booking.isAutoAssigned
                    ? (booking.panditName != null
                        ? '${booking.panditName!} (auto-assigned)'
                        : 'Awaiting auto-assignment')
                    : (booking.panditName ?? 'Awaiting confirmation'),
              ),
            ),
            const SizedBox(height: 12),

            // ── Payment ─────────────────────────────────────────────
            _SectionCard(
              title: 'Payment',
              child: Column(
                children: [
                  _DetailRow(
                    icon: booking.isPaid
                        ? Icons.check_circle_rounded
                        : Icons.pending_rounded,
                    label: 'Status',
                    value: booking.isPaid ? 'Paid' : 'Pending',
                    valueColor:
                        booking.isPaid ? Colors.green[700] : Colors.orange[800],
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    icon: Icons.currency_rupee_rounded,
                    label: 'Amount',
                    value: '₹${booking.amount.toStringAsFixed(0)}',
                  ),
                  if (booking.paymentId != null) ...[
                    const SizedBox(height: 10),
                    _DetailRow(
                      icon: Icons.tag_rounded,
                      label: 'Transaction ID',
                      value: booking.paymentId!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Booking metadata ────────────────────────────────────
            _SectionCard(
              title: 'Reference',
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.confirmation_number_rounded,
                    label: 'Booking ID',
                    value: booking.id,
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    icon: Icons.access_time_rounded,
                    label: 'Booked On',
                    value: _fmtDateTime(booking.createdAt),
                  ),
                ],
              ),
            ),            // ── Video proof (only when completed) ────────────────────────────────
            if (booking.status == BookingStatus.completed) ...[              
              const SizedBox(height: 12),
              _ProofSection(booking: booking),
            ],
            const SizedBox(height: 24),

            // ── Book again ──────────────────────────────────────────
            if (booking.status.isFinal)
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('/booking/wizard?packageId=${booking.packageId}'),
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Book Again'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final cs = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text(
            'Are you sure? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await ref
          .read(bookingListProvider.notifier)
          .cancelBooking(booking.id);
      if (context.mounted) context.pop();
    }
  }

  static String _fmtDateTime(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final m = d.minute.toString().padLeft(2, '0');
    final period = d.hour < 12 ? 'AM' : 'PM';
    return '${d.day} ${months[d.month - 1]} ${d.year}, $h:$m $period';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final status = booking.status;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: status.color.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status.color.withAlpha(80), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: status.color.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: Icon(status.icon, color: status.color, size: 28),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.label,
                style: TextStyle(
                  color: status.color,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              Text(
                _statusDescription(status),
                style: TextStyle(
                  color: status.color.withAlpha(190),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _statusDescription(BookingStatus s) {
    switch (s) {
      case BookingStatus.pending:
        return 'Awaiting review by our team';
      case BookingStatus.confirmed:
        return 'Booking accepted — pandit being assigned';
      case BookingStatus.assigned:
        return 'Pandit will reach you on scheduled time';
      case BookingStatus.completed:
        return 'Service completed successfully';
      case BookingStatus.cancelled:
        return 'This booking has been cancelled';
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: cs.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500)),
              Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: valueColor)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Video Proof Section ───────────────────────────────────────────────────────

class _ProofSection extends ConsumerWidget {
  const _ProofSection({required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proofState = ref.watch(proofViewProvider(booking.id));
    final authState = ref.watch(authProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final isPanditOrAdmin =
        user?.role.isPandit == true || user?.role.isAdmin == true;

    return _SectionCard(
      title: 'Service Proof',
      child: proofState.loading
          ? const Center(
              heightFactor: 2,
              child: CircularProgressIndicator(),
            )
          : proofState.error != null
              ? _ProofError(message: proofState.error!)
              : proofState.hasProof
                  ? _ProofCard(proof: proofState.proof!)
                  : _ProofPending(
                      canUpload: isPanditOrAdmin,
                      onUpload: () => context.push(
                        '/booking/${booking.id}/upload-proof',
                        extra: {
                          'panditId': user?.id ?? 'pandit_mock',
                          'title': booking.packageTitle,
                        },
                      ),
                    ),
    );
  }
}

class _ProofCard extends StatelessWidget {
  const _ProofCard({required this.proof});
  final ProofModel proof;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (proof.hasVideo) ...[
          StreamVideoPlayer(videoUrl: proof.videoUrl!),
          const SizedBox(height: 12),
        ],
        if (proof.isVerified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withAlpha(80)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.verified_rounded, size: 14, color: Colors.green),
              SizedBox(width: 6),
              Text(
                'Verified by admin',
                style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        if (proof.hasImages) ...[
          const SizedBox(height: 14),
          Text('Photo Proof',
              style: tt.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _ProofImageGrid(imageUrls: proof.imageUrls),
        ],
        const SizedBox(height: 8),
        Text(
          'Uploaded ${_fmtAgo(proof.uploadedAt)}',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  static String _fmtAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}

class _ProofPending extends StatelessWidget {
  const _ProofPending({required this.canUpload, required this.onUpload});
  final bool canUpload;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(Icons.video_camera_back_outlined,
            size: 40, color: cs.onSurfaceVariant),
        const SizedBox(height: 8),
        Text(
          canUpload
              ? 'No proof uploaded yet. Upload video and photo proof for this booking.'
              : 'Service proof has not been uploaded yet.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        if (canUpload) ...[
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_rounded),
            label: const Text('Upload Proof'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProofError extends StatelessWidget {
  const _ProofError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(Icons.error_outline_rounded,
          color: Theme.of(context).colorScheme.error, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
    ]);
  }
}

class _ProofImageGrid extends StatelessWidget {
  const _ProofImageGrid({required this.imageUrls});
  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < imageUrls.length; i++)
          GestureDetector(
            onTap: () => _showFullImage(context, imageUrls, i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: imageUrls[i],
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  width: 90,
                  height: 90,
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  child: const Center(
                      child:
                          CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (_, _, _) => Container(
                  width: 90,
                  height: 90,
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_rounded),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showFullImage(
      BuildContext context, List<String> urls, int index) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(children: [
          InteractiveViewer(
            child: CachedNetworkImage(
                imageUrl: urls[index], fit: BoxFit.contain),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon:
                  const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ]),
      ),
    );
  }
}
