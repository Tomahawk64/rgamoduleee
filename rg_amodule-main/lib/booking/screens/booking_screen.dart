import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/booking_model.dart';
import '../models/booking_status.dart';
import '../providers/booking_provider.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(currentUserProvider)?.id ?? '';
      ref.read(bookingListProvider.notifier).loadBookings(userId);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingListProvider);
    final userId = ref.watch(currentUserProvider)?.id ?? '';

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, _) => [
          SliverAppBar(
            pinned: true,
            title: const Text('My Bookings',
                style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => ref
                    .read(bookingListProvider.notifier)
                    .refresh(userId),
              ),
            ],
            bottom: TabBar(
              controller: _tabCtrl,
              tabs: [
                Tab(text: 'Upcoming (${state.upcoming.length})'),
                Tab(text: 'Past (${state.past.length})'),
              ],
            ),
          ),
        ],
        body: state.loading
            ? const Center(child: CircularProgressIndicator())
            : state.error != null
                ? _ErrorView(
                    error: state.error!,
                    onRetry: () => ref
                        .read(bookingListProvider.notifier)
                        .refresh(userId),
                  )
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _BookingList(
                          bookings: state.upcoming,
                          emptyMessage:
                              'No upcoming bookings.\nTap + to start one!'),
                      _BookingList(
                          bookings: state.past,
                          emptyMessage: 'No past bookings yet.'),
                    ],
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/booking/wizard'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Booking',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Booking list ──────────────────────────────────────────────────────────────

class _BookingList extends ConsumerWidget {
  const _BookingList(
      {required this.bookings, required this.emptyMessage});
  final List<BookingModel> bookings;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bookings.isEmpty) return _EmptyBookings(message: emptyMessage);
    return RefreshIndicator(
      onRefresh: () {
        final uid = ref.read(currentUserProvider)?.id ?? '';
        return ref.read(bookingListProvider.notifier).loadBookings(uid);
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: bookings.length,
        itemBuilder: (_, i) => _BookingCard(booking: bookings[i]),
      ),
    );
  }
}

// ── Booking card ──────────────────────────────────────────────────────────────

class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        onTap: () => context.push('/booking/${booking.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.temple_hindu_rounded,
                        color: cs.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(booking.packageTitle,
                            style: tt.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        Text(booking.category,
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  _StatusChip(status: booking.status),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  _InfoItem(
                      icon: Icons.event_rounded,
                      text: booking.formattedDate),
                  const SizedBox(width: 16),
                  _InfoItem(
                      icon: Icons.schedule_rounded,
                      text: booking.slot.label),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _InfoItem(
                    icon: booking.location.isOnline
                        ? Icons.videocam_rounded
                        : Icons.location_on_rounded,
                    text: booking.location.isOnline
                        ? 'Online'
                        : (booking.location.city ?? 'On-site'),
                  ),
                  if (booking.panditName != null) ...[
                    const SizedBox(width: 16),
                    _InfoItem(
                        icon: Icons.person_rounded,
                        text: booking.panditName!),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '₹${booking.amount.toStringAsFixed(0)}',
                    style: tt.titleSmall?.copyWith(
                        color: cs.primary, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  if (booking.status.isActive)
                    TextButton(
                      onPressed: () => _confirmCancel(context, ref),
                      style: TextButton.styleFrom(
                          foregroundColor: cs.error,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12)),
                      child: const Text('Cancel'),
                    ),
                  const SizedBox(width: 4),
                  OutlinedButton(
                    onPressed: () => context.push('/booking/${booking.id}'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('View'),
                  ),
                ],
              ),
            ],
          ),
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
            'Are you sure you want to cancel this booking? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await ref
          .read(bookingListProvider.notifier)
          .cancelBooking(booking.id);
    }
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 12, color: status.color),
          const SizedBox(width: 4),
          Text(status.label,
              style: TextStyle(
                  color: status.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Info item ─────────────────────────────────────────────────────────────────

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 60, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry')),
        ],
      ),
    );
  }
}

