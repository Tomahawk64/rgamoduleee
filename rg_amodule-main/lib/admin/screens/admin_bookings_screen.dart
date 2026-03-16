// lib/admin/screens/admin_bookings_screen.dart
// View all bookings, filter by status, update booking status, assign pandits.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../booking/models/booking_status.dart';
import '../../core/theme/app_colors.dart';
import '../models/admin_models.dart';
import '../providers/admin_providers.dart';

class AdminBookingsScreen extends ConsumerStatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  ConsumerState<AdminBookingsScreen> createState() =>
      _AdminBookingsScreenState();
}

class _AdminBookingsScreenState
    extends ConsumerState<AdminBookingsScreen> {
  BookingStatus? _filter;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    final all = state.bookings;

    final filtered = all.where((b) {
      final matchStatus = _filter == null || b.status == _filter;
      final matchSearch = _search.isEmpty ||
          b.packageTitle
              .toLowerCase()
              .contains(_search.toLowerCase()) ||
          b.clientName.toLowerCase().contains(_search.toLowerCase()) ||
          (b.panditName?.toLowerCase().contains(_search.toLowerCase()) ??
              false);
      return matchStatus && matchSearch;
    }).toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

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
        title: const Text('All Bookings',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search by ceremony, client, pandit…',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),

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
                ...BookingStatus.values.map((s) {
                  final count = all.where((b) => b.status == s).length;
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
                    child: Text('No bookings found',
                        style: TextStyle(
                            color: AppColors.textSecondary)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 10),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _BookingRow(
                      booking: filtered[i],
                      pandits: state.pandits,
                      onUpdateStatus: (status) => ref
                          .read(adminProvider.notifier)
                          .updateBookingStatus(filtered[i].id, status),
                      onAssignPandit: (panditId) => ref
                          .read(adminProvider.notifier)
                          .assignPandit(filtered[i].id, panditId),
                      onMarkAsPaid: () => ref
                          .read(adminProvider.notifier)
                          .markAsPaid(filtered[i].id),
                    ),
                  ),
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
          color: selected ? color.withValues(alpha: 0.15) : Colors.white,
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
            color: selected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Booking row ───────────────────────────────────────────────────────────────

class _BookingRow extends StatefulWidget {
  const _BookingRow({
    required this.booking,
    required this.pandits,
    required this.onUpdateStatus,
    required this.onAssignPandit,
    required this.onMarkAsPaid,
  });
  final AdminBookingRow booking;
  final List<AdminPandit> pandits;
  final ValueChanged<BookingStatus> onUpdateStatus;
  final ValueChanged<String> onAssignPandit;
  final VoidCallback onMarkAsPaid;

  @override
  State<_BookingRow> createState() => _BookingRowState();
}

class _BookingRowState extends State<_BookingRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final statusColor = booking.status.color;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          // ── Header row: status chip + amount ──────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(booking.status.icon, size: 10, color: statusColor),
                    const SizedBox(width: 3),
                    Text(
                      booking.status.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Payment chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: booking.isPaid
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  booking.isPaid ? 'Paid' : 'Unpaid',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: booking.isPaid ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '₹${booking.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Package title ─────────────────────────────────────────────────
          Text(
            booking.packageTitle,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),

          // ── Client info (name + phone) ────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 3),
              Text(
                booking.clientName,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              if (booking.clientPhone != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.phone_outlined,
                    size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 3),
                Text(
                  booking.clientPhone!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),

          if (booking.clientEmail != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.email_outlined,
                    size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 3),
                Text(
                  booking.clientEmail!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),

          // ── Date + time slot ──────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  size: 11, color: AppColors.textSecondary),
              const SizedBox(width: 3),
              Text(
                booking.formattedDate,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
              if (booking.timeSlot != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.schedule_outlined,
                    size: 11, color: AppColors.textSecondary),
                const SizedBox(width: 3),
                Text(
                  booking.timeSlot!,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),

          // ── Location / Address ────────────────────────────────────────────
          if (booking.address != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(
                  booking.isOnline
                      ? Icons.videocam_outlined
                      : Icons.location_on_outlined,
                  size: 12,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    booking.address!,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // ── Pandit ────────────────────────────────────────────────────────
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.supervised_user_circle_outlined,
                  size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 3),
              Text(
                booking.panditName ?? 'Not yet assigned',
                style: TextStyle(
                  fontSize: 12,
                  color: booking.panditName != null
                      ? AppColors.textSecondary
                      : AppColors.error,
                  fontStyle: booking.panditName == null
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
            ],
          ),

          // ── User notes (expandable) ───────────────────────────────────────
          if (booking.userNotes != null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  const Icon(Icons.notes_outlined,
                      size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 3),
                  const Text(
                    'User note',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 16),
                child: Text(
                  booking.userNotes!,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic),
                ),
              ),
          ],

          // ── Payment actions for unpaid bookings ───────────────────────────
          if (!booking.isPaid && !booking.status.isFinal) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onMarkAsPaid,
                    icon: const Icon(Icons.check_circle_outline, size: 14),
                    label: const Text('Mark as Paid',
                        style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showPaymentReminderDialog(context),
                    icon: const Icon(
                        Icons.notifications_active_outlined,
                        size: 14),
                    label: const Text('Remind',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // ── Status update ─────────────────────────────────────────────────
          if (!booking.status.isFinal) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Update Status:',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: BookingStatus.values
                          .where((s) =>
                              s != booking.status &&
                              s.index > booking.status.index)
                          .map((s) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: GestureDetector(
                                  onTap: () => widget.onUpdateStatus(s),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          s.color.withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                          color: s.color
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      s.label,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: s.color,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // ── Assign Pandit ─────────────────────────────────────────────────
          if (widget.pandits.isNotEmpty && !booking.status.isFinal) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showAssignPanditSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_add_outlined,
                            size: 13, color: AppColors.secondary),
                        const SizedBox(width: 6),
                        Text(
                          booking.panditId != null
                              ? 'Reassign Pandit'
                              : 'Assign Pandit',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Assign at least 24 hours before the booking date',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showPaymentReminderDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Payment Reminder'),
        content: Text(
          'Send a payment reminder to ${widget.booking.clientName} for '
          '${widget.booking.packageTitle} (₹${widget.booking.amount.toStringAsFixed(0)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Payment reminder sent to ${widget.booking.clientName}.'),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            child: const Text('Send Reminder'),
          ),
        ],
      ),
    );
  }

  void _showAssignPanditSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        builder: (ctx, scroll) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Assign Pandit — ${widget.booking.packageTitle}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Please assign the pandit at least 24 hours before the booking date.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: widget.pandits.length,
                itemBuilder: (_, i) {
                  final p = widget.pandits[i];
                  final isCurrentlyAssigned =
                      widget.booking.panditId == p.id;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.secondary.withValues(alpha: 0.1),
                      child: Text(
                        p.initials,
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    title: Text(
                      p.name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      p.specialties.take(2).join(' · '),
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isCurrentlyAssigned
                        ? const Icon(Icons.check_circle,
                            color: AppColors.success)
                        : const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onAssignPandit(p.id);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
