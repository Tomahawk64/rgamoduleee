// lib/pandit/screens/pandit_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/base_scaffold.dart';
import '../controllers/pandit_dashboard_controller.dart';
import '../models/pandit_dashboard_models.dart';
import '../providers/pandit_provider.dart';
import '../../booking/models/booking_status.dart';

class PanditScreen extends ConsumerStatefulWidget {
  const PanditScreen({super.key});

  @override
  ConsumerState<PanditScreen> createState() => _PanditScreenState();
}

class _PanditScreenState extends ConsumerState<PanditScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(panditDashboardProvider);
    final user = ref.watch(currentUserProvider);

    // Surface any error as a SnackBar
    ref.listen<PanditDashboardState>(panditDashboardProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () =>
                  ref.read(panditDashboardProvider.notifier).clearError(),
            ),
          ),
        );
      }
    });

    return BaseScaffold(
      title: 'Pandit Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: state.loading
              ? null
              : () => ref.read(panditDashboardProvider.notifier).load(),
        ),
      ],
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(panditDashboardProvider.notifier).load(),
              child: NestedScrollView(
                headerSliverBuilder: (ctx, _) => [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // ── Profile header ────────────────────────────────
                        _ProfileHeader(
                          state: state,
                          user: user,
                          onToggleConsultation: () => ref
                              .read(panditDashboardProvider.notifier)
                              .toggleConsultation(),
                        ),
                        const SizedBox(height: 16),

                        // ── Stats row ─────────────────────────────────────
                        _StatsRow(state: state),
                        const SizedBox(height: 16),

                        // ── Earnings card ─────────────────────────────────
                        if (state.earnings != null)
                          _EarningsCard(earnings: state.earnings!),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                  // ── Tab bar ───────────────────────────────────────────
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabHeaderDelegate(
                      tabController: _tab,
                      newCount: state.pendingCount,
                      activeCount: state.activeCount,
                      completedCount: state.completedCount,
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tab,
                  children: [
                    _AssignmentList(
                      assignments: state.newRequests,
                      emptyLabel: 'No new requests',
                      emptyIcon: Icons.notifications_none_rounded,
                    ),
                    _AssignmentList(
                      assignments: state.activeAssignments,
                      emptyLabel: 'No active bookings',
                      emptyIcon: Icons.event_available_outlined,
                    ),
                    _AssignmentList(
                      assignments: state.completedAssignments,
                      emptyLabel: 'No completed bookings yet',
                      emptyIcon: Icons.task_alt_outlined,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Profile Header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.state,
    required this.user,
    required this.onToggleConsultation,
  });

  final PanditDashboardState state;
  final dynamic user;
  final VoidCallback onToggleConsultation;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    final name = profile?.name ?? user?.name ?? 'Pandit';
    final initials =
        profile?.initials ?? (name.isNotEmpty ? name[0].toUpperCase() : 'P');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.secondary, AppColors.secondaryLight],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Name + details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (profile != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile.specialties.take(2).join(' · '),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 12, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text(
                            '${profile.rating}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Colors.white54,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${profile.yearsExperience} yrs exp.',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Verified badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded,
                        color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),

          // Consultation toggle
          Row(
            children: [
              const Icon(Icons.videocam_outlined,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Online Consultations',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Allow clients to book paid consultations',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (state.togglingConsultation)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Switch(
                  value: state.consultationEnabled,
                  onChanged: (_) => onToggleConsultation(),
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.success,
                  inactiveThumbColor: Colors.white70,
                  inactiveTrackColor: Colors.white24,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.state});
  final PanditDashboardState state;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(
        value: '${state.pendingCount}',
        label: 'New Requests',
        color: AppColors.warning,
        icon: Icons.notification_important_outlined,
      ),
      _StatItem(
        value: '${state.activeCount}',
        label: 'Active',
        color: AppColors.info,
        icon: Icons.event_available_outlined,
      ),
      _StatItem(
        value: '${state.completedCount}',
        label: 'Completed',
        color: AppColors.success,
        icon: Icons.task_alt_outlined,
      ),
      _StatItem(
        value: '${state.totalCount}',
        label: 'Total',
        color: AppColors.primary,
        icon: Icons.assignment_outlined,
      ),
    ];

    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemCount: items.length,
        itemBuilder: (_, i) => items[i],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  final String value;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Earnings Card ─────────────────────────────────────────────────────────────

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.earnings});
  final EarningsSummary earnings;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 16, color: AppColors.success),
              const SizedBox(width: 6),
              const Text(
                'Earnings Summary',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${earnings.completedCount} bookings total',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _EarningsTile(
                  label: 'Total Earned',
                  value: earnings.formattedTotal,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EarningsTile(
                  label: 'This Month',
                  value: earnings.formattedMonth,
                  color: AppColors.primary,
                  sub: '${earnings.thisMonthCount} services',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EarningsTile(
                  label: 'Pending Payout',
                  value: earnings.formattedPending,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 13, color: AppColors.info),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Payouts processed within 3 business days of service completion.',
                    style: TextStyle(fontSize: 11, color: AppColors.info),
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

class _EarningsTile extends StatelessWidget {
  const _EarningsTile({
    required this.label,
    required this.value,
    required this.color,
    this.sub,
  });

  final String label;
  final String value;
  final Color color;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
          if (sub != null)
            Text(
              sub!,
              style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7)),
            ),
        ],
      ),
    );
  }
}

// ── Tab header delegate ───────────────────────────────────────────────────────

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TabHeaderDelegate({
    required this.tabController,
    required this.newCount,
    required this.activeCount,
    required this.completedCount,
  });

  final TabController tabController;
  final int newCount;
  final int activeCount;
  final int completedCount;

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  bool shouldRebuild(_TabHeaderDelegate old) =>
      old.newCount != newCount ||
      old.activeCount != activeCount ||
      old.completedCount != completedCount;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: TabBar(
        controller: tabController,
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        tabs: [
          _CountTab(label: 'New Requests', count: newCount),
          _CountTab(label: 'Active', count: activeCount),
          const Tab(text: 'Completed'),
        ],
      ),
    );
  }
}

class _CountTab extends StatelessWidget {
  const _CountTab({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Assignment list ───────────────────────────────────────────────────────────

class _AssignmentList extends StatelessWidget {
  const _AssignmentList({
    required this.assignments,
    required this.emptyLabel,
    required this.emptyIcon,
  });

  final List<PanditAssignment> assignments;
  final String emptyLabel;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon,
                size: 64,
                color: AppColors.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              emptyLabel,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemCount: assignments.length,
      itemBuilder: (ctx, i) => _BookingCard(assignment: assignments[i]),
    );
  }
}

// ── Booking card ──────────────────────────────────────────────────────────────

class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.assignment});
  final PanditAssignment assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = assignment.booking;
    final isNew = assignment.isPendingAction;
    final statusColor = booking.status.color;

    return GestureDetector(
      onTap: () => context.push(
        Routes.panditBookingDetail.replaceFirst(':id', booking.id),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isNew
              ? Border.all(color: AppColors.warning, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.temple_hindu,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.packageTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        booking.category,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(booking.status.icon,
                          size: 10, color: statusColor),
                      const SizedBox(width: 3),
                      Text(
                        isNew ? 'New' : booking.status.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Info row
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  booking.formattedDate,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.access_time,
                    size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  booking.slot.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '₹${booking.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  booking.location.isOnline
                      ? Icons.videocam_outlined
                      : Icons.location_on_outlined,
                  size: 12,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    booking.location.isOnline
                        ? 'Online'
                        : (booking.location.city ?? 'Location TBD'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!booking.isPaid)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Unpaid',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            // Quick actions for new requests
            if (isNew) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmReject(context, ref),
                      icon: const Icon(Icons.close, size: 14),
                      label: const Text('Reject',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        minimumSize: const Size.fromHeight(34),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => ref
                          .read(panditDashboardProvider.notifier)
                          .acceptAssignment(booking.id),
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text('Accept',
                          style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(34),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmReject(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject booking?'),
        content: Text(
          'Are you sure you want to reject "${assignment.booking.packageTitle}"? '
          'It will be returned to the pending pool.',
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
                  .read(panditDashboardProvider.notifier)
                  .rejectAssignment(assignment.booking.id);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}
