// lib/admin/screens/admin_offline_bookings_screen.dart
// Admin panel for managing offline pandit bookings — fully functional.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../offline_booking/models/offline_booking_models.dart';
import '../../offline_booking/providers/offline_booking_provider.dart';
import '../../offline_booking/repository/offline_booking_repository.dart';

// ── Provider for admin-level offline bookings ────────────────────────────────

class AdminOfflineBookingsState {
  const AdminOfflineBookingsState({
    this.bookings = const [],
    this.loading = false,
    this.error,
  });
  final List<OfflineBooking> bookings;
  final bool loading;
  final String? error;

  AdminOfflineBookingsState copyWith({
    List<OfflineBooking>? bookings,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      AdminOfflineBookingsState(
        bookings: bookings ?? this.bookings,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

class AdminOfflineBookingsController
    extends StateNotifier<AdminOfflineBookingsState> {
  AdminOfflineBookingsController(this._repo)
      : super(const AdminOfflineBookingsState());
  final IOfflineBookingRepository _repo;

  Future<void> loadAll() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final bookings = await _repo.getAllBookings();
      state = state.copyWith(bookings: bookings, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<bool> cancelBooking(String bookingId, String reason) async {
    try {
      final ok = await _repo.adminCancelBooking(bookingId, reason);
      if (ok) await loadAll();
      return ok;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> processRefund(String bookingId, String reason) async {
    try {
      final ok = await _repo.adminProcessRefund(bookingId, reason);
      if (ok) await loadAll();
      return ok;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> processPayout(String bookingId) async {
    try {
      final ok = await _repo.adminProcessPayout(bookingId);
      if (ok) await loadAll();
      return ok;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateStatus(
      String bookingId, OfflineBookingStatus newStatus, String? notes) async {
    try {
      final ok =
          await _repo.adminUpdateBookingStatus(bookingId, newStatus, notes);
      if (ok) await loadAll();
      return ok;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // ── Computed stats (refund-aware) ──────────────────────────────────────────
  int get totalBookings => state.bookings.length;
  int get activeBookings => state.bookings
      .where((b) =>
          b.status != OfflineBookingStatus.cancelled &&
          b.status != OfflineBookingStatus.rejected &&
          b.status != OfflineBookingStatus.refunded)
      .length;
  int get refundedCount =>
      state.bookings
          .where((b) => b.status == OfflineBookingStatus.refunded)
          .length;
  double get totalRevenue => state.bookings
      .where((b) => b.isPaid && b.status != OfflineBookingStatus.refunded)
      .fold(0.0, (sum, b) => sum + b.amount);
  double get refundedRevenue => state.bookings
      .where((b) => b.status == OfflineBookingStatus.refunded)
      .fold(0.0, (sum, b) => sum + b.amount);
  double get netRevenue => totalRevenue - refundedRevenue;
}

final adminOfflineBookingsProvider = StateNotifierProvider<
    AdminOfflineBookingsController, AdminOfflineBookingsState>((ref) {
  final repo = ref.watch(offlineBookingRepositoryProvider);
  return AdminOfflineBookingsController(repo);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class AdminOfflineBookingsScreen extends ConsumerStatefulWidget {
  const AdminOfflineBookingsScreen({super.key});

  @override
  ConsumerState<AdminOfflineBookingsScreen> createState() =>
      _AdminOfflineBookingsScreenState();
}

class _AdminOfflineBookingsScreenState
    extends ConsumerState<AdminOfflineBookingsScreen> {
  OfflineBookingStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(adminOfflineBookingsProvider.notifier).loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminOfflineBookingsProvider);
    final ctrl = ref.read(adminOfflineBookingsProvider.notifier);

    ref.listen<AdminOfflineBookingsState>(adminOfflineBookingsProvider,
        (_, next) {
      if (next.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.error!),
          backgroundColor: AppColors.error,
        ));
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Offline Pandit Bookings'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ctrl.loadAll(),
          ),
        ],
      ),
      body: state.loading && state.bookings.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _StatSummaryBar(ctrl: ctrl),
                _buildFilterBar(),
                Expanded(child: _buildBookingsList(state, ctrl)),
              ],
            ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip(null, 'All'),
            ...[
              OfflineBookingStatus.pending,
              OfflineBookingStatus.accepted,
              OfflineBookingStatus.paid,
              OfflineBookingStatus.confirmed,
              OfflineBookingStatus.inProgress,
              OfflineBookingStatus.completed,
              OfflineBookingStatus.cancelled,
              OfflineBookingStatus.refunded,
              OfflineBookingStatus.rejected,
            ].map((s) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _chip(s, s.label),
                )),
          ],
        ),
      ),
    );
  }

  Widget _chip(OfflineBookingStatus? status, String label) {
    final isSelected = _selectedStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (sel) =>
          setState(() => _selectedStatus = sel ? status : null),
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  Widget _buildBookingsList(
      AdminOfflineBookingsState state, AdminOfflineBookingsController ctrl) {
    final filtered = _selectedStatus == null
        ? state.bookings
        : state.bookings.where((b) => b.status == _selectedStatus).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox,
                size: 64,
                color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              _selectedStatus == null
                  ? 'No offline bookings yet'
                  : 'No ${_selectedStatus!.label} bookings',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ctrl.loadAll(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, i) {
          final booking = filtered[i];
          return _AdminBookingCard(
            booking: booking,
            onAction: (action) => _handleAction(booking, action, ctrl),
          );
        },
      ),
    );
  }

  Future<void> _handleAction(OfflineBooking booking, String action,
      AdminOfflineBookingsController ctrl) async {
    switch (action) {
      case 'cancel':
        final reason = await _askReason(
            context, 'Cancel Booking', 'Cancellation reason:', Colors.red);
        if (reason == null) return;
        final ok = await ctrl.cancelBooking(booking.id, reason);
        if (ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Booking cancelled'),
              backgroundColor: Colors.red));
        }
        break;
      case 'refund':
        final reason = await _askReason(
            context, 'Process Refund', 'Refund reason:', Colors.purple);
        if (reason == null) return;
        final ok = await ctrl.processRefund(booking.id, reason);
        if (ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Refund processed — stats updated'),
              backgroundColor: Colors.purple));
        }
        break;
      case 'payout':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Process Payout'),
            content: Text(
                'Release ₹${booking.amount.toStringAsFixed(0)} to pandit?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('No')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Yes, Payout'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          final ok = await ctrl.processPayout(booking.id);
          if (ok && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Payout processed'),
                backgroundColor: Colors.green));
          }
        }
        break;
      case 'mark_completed':
        final ok = await ctrl.updateStatus(
            booking.id, OfflineBookingStatus.completed, null);
        if (ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Marked as completed'),
              backgroundColor: Colors.green));
        }
        break;
    }
  }

  Future<String?> _askReason(BuildContext context, String title,
      String hintText, Color accentColor) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hintText),
          maxLines: 2,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: accentColor, foregroundColor: Colors.white),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

// ── Stat Summary Bar ─────────────────────────────────────────────────────────

class _StatSummaryBar extends StatelessWidget {
  const _StatSummaryBar({required this.ctrl});
  final AdminOfflineBookingsController ctrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          _miniStat('Total', '${ctrl.totalBookings}', Colors.blue),
          _miniStat('Active', '${ctrl.activeBookings}', Colors.green),
          _miniStat('Refunds', '${ctrl.refundedCount}', Colors.purple),
          _miniStat('Net Rev.', _fmtRupees(ctrl.netRevenue), Colors.teal),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  String _fmtRupees(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }
}

// ── Booking Card ─────────────────────────────────────────────────────────────

class _AdminBookingCard extends StatelessWidget {
  const _AdminBookingCard({required this.booking, required this.onAction});
  final OfflineBooking booking;
  final Function(String) onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _statusColor(booking.status).withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(_statusIcon(booking.status),
                    color: _statusColor(booking.status)),
                const SizedBox(width: 8),
                Text(booking.status.label,
                    style: TextStyle(
                        color: _statusColor(booking.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const Spacer(),
                Text(booking.createdAt.toString().split(' ')[0],
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(
                    'Booking ID',
                    booking.id.length > 8
                        ? '${booking.id.substring(0, 8)}…'
                        : booking.id),
                _row('Pandit', booking.panditName ?? 'N/A'),
                _row('Service', booking.serviceName),
                _row('Date', booking.formattedDate),
                _row('Time', booking.bookingTime),
                _row('Amount', booking.amountLabel),
                if (booking.isPaid)
                  _row('Payment', booking.paymentId ?? 'Paid',
                      color: Colors.green),
                if (booking.status == OfflineBookingStatus.refunded)
                  _row('Status', 'REFUNDED — Revenue deducted',
                      color: Colors.purple),
                const SizedBox(height: 12),
                _buildActions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
          const Text(': '),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: color))),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final canCancel = booking.status == OfflineBookingStatus.pending ||
        booking.status == OfflineBookingStatus.accepted;
    final canRefund = booking.status == OfflineBookingStatus.paid ||
        booking.status == OfflineBookingStatus.confirmed ||
        booking.status == OfflineBookingStatus.completed;
    final canPayout =
        booking.status == OfflineBookingStatus.completed && booking.isPaid;
    final canComplete = booking.status == OfflineBookingStatus.confirmed ||
        booking.status == OfflineBookingStatus.inProgress;

    if (!canCancel && !canRefund && !canPayout && !canComplete) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (canComplete)
          _actionBtn('Mark Done', Icons.done_all, Colors.green,
              () => onAction('mark_completed')),
        if (canCancel)
          _actionBtn(
              'Cancel', Icons.cancel, Colors.red, () => onAction('cancel')),
        if (canRefund)
          _actionBtn('Refund', Icons.currency_exchange, Colors.purple,
              () => onAction('refund')),
        if (canPayout)
          _actionBtn('Payout', Icons.account_balance_wallet, Colors.teal,
              () => onAction('payout')),
      ],
    );
  }

  Widget _actionBtn(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
          foregroundColor: color, side: BorderSide(color: color)),
    );
  }

  Color _statusColor(OfflineBookingStatus s) {
    switch (s) {
      case OfflineBookingStatus.pending:
        return Colors.orange;
      case OfflineBookingStatus.accepted:
        return Colors.blue;
      case OfflineBookingStatus.paid:
      case OfflineBookingStatus.confirmed:
      case OfflineBookingStatus.completed:
        return Colors.green;
      case OfflineBookingStatus.inProgress:
        return AppColors.primary;
      case OfflineBookingStatus.rejected:
      case OfflineBookingStatus.cancelled:
        return Colors.red;
      case OfflineBookingStatus.refunded:
        return Colors.purple;
    }
  }

  IconData _statusIcon(OfflineBookingStatus s) {
    switch (s) {
      case OfflineBookingStatus.pending:
        return Icons.pending;
      case OfflineBookingStatus.accepted:
        return Icons.check_circle_outline;
      case OfflineBookingStatus.paid:
      case OfflineBookingStatus.confirmed:
        return Icons.verified;
      case OfflineBookingStatus.inProgress:
        return Icons.play_circle_outline;
      case OfflineBookingStatus.completed:
        return Icons.done_all;
      case OfflineBookingStatus.rejected:
        return Icons.cancel;
      case OfflineBookingStatus.cancelled:
        return Icons.cancel_outlined;
      case OfflineBookingStatus.refunded:
        return Icons.currency_exchange;
    }
  }
}
