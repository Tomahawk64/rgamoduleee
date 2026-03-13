// lib/admin/screens/admin_screen.dart
// Main Admin Dashboard hub — role-protected, accessed via /admin

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../../booking/models/booking_status.dart';
import '../../core/constants/demo_config.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/base_scaffold.dart';
import '../models/admin_models.dart';
import '../providers/admin_providers.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminProvider);
    final user = ref.watch(currentUserProvider);

    // Error snackbar
    ref.listen<AdminState>(adminProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.error!),
          backgroundColor: AppColors.error,
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () =>
                ref.read(adminProvider.notifier).clearError(),
          ),
        ));
      }
    });

    return BaseScaffold(
      title: 'Admin Panel',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
          onPressed: state.loading
              ? null
              : () => ref.read(adminProvider.notifier).load(),
        ),
      ],
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(adminProvider.notifier).load(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Admin identity badge ──────────────────────────────────
                  _AdminBadge(userName: user?.name ?? ''),
                  const SizedBox(height: 12),

                  // ── Demo mode indicator ───────────────────────────────────
                  if (DemoConfig.demoMode) const _DemoModeBanner(),
                  const SizedBox(height: 20),

                  // ── Stats grid ────────────────────────────────────────────
                  if (state.report != null)
                    _StatsGrid(report: state.report!),
                  const SizedBox(height: 20),

                  // ── Section label ─────────────────────────────────────────
                  const _SectionLabel(
                    icon: Icons.dashboard_rounded,
                    title: 'Management Modules',
                  ),
                  const SizedBox(height: 12),

                  // ── Module grid ───────────────────────────────────────────
                  _ModuleGrid(state: state),
                  const SizedBox(height: 20),

                  // ── Quick report preview ──────────────────────────────────
                  if (state.report != null)
                    _ReportPreview(
                      report: state.report!,
                      onViewFull: () =>
                          context.push(Routes.adminReports),
                    ),
                ],
              ),
            ),
    );
  }
}

// ── Admin badge ───────────────────────────────────────────────────────────────

class _AdminBadge extends StatelessWidget {
  const _AdminBadge({required this.userName});
  final String userName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: AppColors.error, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Administrator Access',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (userName.isNotEmpty)
                  Text(
                    'Signed in as $userName',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'ADMIN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.error,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats grid ────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.report});
  final AdminReport report;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(
        value: '${report.totalBookings}',
        label: 'Total Bookings',
        icon: Icons.calendar_today_rounded,
        color: AppColors.primary,
        sub: '+${report.monthlyBookings} this month',
      ),
      _StatItem(
        value: '${report.totalConsultations}',
        label: 'Consultations',
        icon: Icons.videocam_rounded,
        color: AppColors.secondary,
        sub: '+${report.monthlyConsultations} this month',
      ),
      _StatItem(
        value: report.formattedMonthlyRevenue,
        label: 'Monthly Revenue',
        icon: Icons.currency_rupee_rounded,
        color: AppColors.success,
        sub: 'Total: ${report.formattedTotalRevenue}',
      ),
      _StatItem(
        value: '${report.activeUsers}',
        label: 'Active Users',
        icon: Icons.people_rounded,
        color: AppColors.info,
        sub: '${report.totalUsers} total',
      ),
      _StatItem(
        value: '${report.activePandits}',
        label: 'Active Pandits',
        icon: Icons.person_pin_rounded,
        color: AppColors.warning,
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        ...items.take(4).map((i) => _StatCard(item: i)),
        // Last card spans full width using a different approach
        Container(
          decoration: BoxDecoration(
            color: items.last.color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: items.last.color.withValues(alpha: 0.2),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(items.last.icon,
                  size: 18, color: items.last.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      items.last.value,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: items.last.color,
                      ),
                    ),
                    Text(
                      items.last.label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatItem {
  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.sub,
  });
  final String value, label;
  final IconData icon;
  final Color color;
  final String? sub;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});
  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 14, color: item.color),
              const Spacer(),
              Text(
                item.value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: item.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          if (item.sub != null)
            Text(
              item.sub!,
              style: TextStyle(
                fontSize: 9,
                color: item.color.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Module grid ───────────────────────────────────────────────────────────────

class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid({required this.state});
  final AdminState state;

  @override
  Widget build(BuildContext context) {
    final pendingBookings =
        state.bookings.where((b) => b.status.isActive).length;
    final activeSessions =
        state.consultations
            .where((c) => c.status == AdminSessionStatus.active)
            .length;

    final modules = [
      _ModuleItem(
        title: 'Manage Poojas',
        subtitle: '${state.poojas.length} listings',
        icon: Icons.temple_hindu_rounded,
        color: AppColors.primary,
        badge: state.poojas.where((p) => !p.isActive).isNotEmpty
            ? '${state.poojas.where((p) => !p.isActive).length} inactive'
            : null,
        route: Routes.adminPoojas,
      ),
      _ModuleItem(
        title: 'Manage Pandits',
        subtitle: '${state.pandits.length} registered',
        icon: Icons.supervised_user_circle_rounded,
        color: AppColors.secondary,
        badge: state.pandits.where((p) => !p.isActive).isNotEmpty
            ? '${state.pandits.where((p) => !p.isActive).length} inactive'
            : null,
        route: Routes.adminPandits,
      ),
      _ModuleItem(
        title: 'All Bookings',
        subtitle: '${state.bookings.length} total',
        icon: Icons.list_alt_rounded,
        color: AppColors.success,
        badge: pendingBookings > 0 ? '$pendingBookings active' : null,
        badgeColor: AppColors.warning,
        route: Routes.adminBookings,
      ),
      _ModuleItem(
        title: 'Consultations',
        subtitle: '${state.consultations.length} sessions',
        icon: Icons.video_call_rounded,
        color: AppColors.info,
        badge: activeSessions > 0 ? '$activeSessions live' : null,
        badgeColor: AppColors.success,
        route: Routes.adminConsultations,
      ),
      _ModuleItem(
        title: 'Reports',
        subtitle: 'Analytics & Revenue',
        icon: Icons.bar_chart_rounded,
        color: const Color(0xFF8B5CF6),
        route: Routes.adminReports,
      ),
      _ModuleItem(
        title: 'Users',
        subtitle: '${state.users.length} registered',
        icon: Icons.people_rounded,
        color: AppColors.info,
        route: Routes.adminUsers,
      ),
      _ModuleItem(
        title: 'Products',
        subtitle: '${state.products.length} products',
        icon: Icons.shopping_bag_rounded,
        color: const Color(0xFFF59E0B),
        route: Routes.adminProducts,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.3,
      ),
      itemCount: modules.length,
      itemBuilder: (ctx, i) => _ModuleCard(
        item: modules[i],
        onTap: () => ctx.push(modules[i].route),
      ),
    );
  }
}

class _ModuleItem {
  const _ModuleItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.badge,
    this.badgeColor,
  });

  final String title, subtitle, route;
  final IconData icon;
  final Color color;
  final String? badge;
  final Color? badgeColor;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.item, required this.onTap});
  final _ModuleItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
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
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      Icon(item.icon, size: 18, color: item.color),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios,
                    size: 12, color: AppColors.textHint),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              item.subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            if (item.badge != null) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (item.badgeColor ?? item.color)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.badge!,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: item.badgeColor ?? item.color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Report preview ────────────────────────────────────────────────────────────

class _ReportPreview extends StatelessWidget {
  const _ReportPreview(
      {required this.report, required this.onViewFull});
  final AdminReport report;
  final VoidCallback onViewFull;

  @override
  Widget build(BuildContext context) {
    final maxRevenue = report.revenueHistory
        .fold<int>(0, (m, p) => p.revenuePaise > m ? p.revenuePaise : m);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              const Icon(Icons.bar_chart_rounded,
                  size: 16, color: AppColors.secondary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Revenue Trend (6 months)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: onViewFull,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Full Report',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: report.revenueHistory.map((p) {
              final frac =
                  maxRevenue > 0 ? p.revenuePaise / maxRevenue : 0.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 60,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height:
                                (frac * 56).clamp(4.0, 56.0),
                            decoration: BoxDecoration(
                              color: p.month ==
                                      report.revenueHistory
                                          .last
                                          .month
                                  ? AppColors.primary
                                  : AppColors.primary
                                      .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.month,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Top Pandit',
                  value: report.topPandits.isNotEmpty
                      ? report.topPandits.first.name
                          .split(' ')
                          .take(2)
                          .join(' ')
                      : '—',
                  color: AppColors.secondary,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Bookings MTD',
                  value: '${report.monthlyBookings}',
                  color: AppColors.success,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Sessions MTD',
                  value: '${report.monthlyConsultations}',
                  color: AppColors.info,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Demo mode banner ──────────────────────────────────────────────────────────

class _DemoModeBanner extends StatelessWidget {
  const _DemoModeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.science_rounded,
              size: 18, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Demo Mode Active',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.info,
                  ),
                ),
                const Text(
                  'Destructive actions are disabled. Data is pre-seeded.',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'DEMO',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppColors.info,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.secondary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
