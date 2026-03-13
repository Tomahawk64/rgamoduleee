// lib/admin/screens/admin_reports_screen.dart
// Analytics, revenue, top pandits, booking/session KPIs.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../models/admin_models.dart';
import '../providers/admin_providers.dart';

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(adminReportProvider);
    final loading = ref.watch(adminLoadingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reports & Analytics',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: loading || report == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── KPI summary ─────────────────────────────────────────
                const _SectionHeader(
                  icon: Icons.speed_rounded,
                  title: 'Key Performance Indicators',
                ),
                const SizedBox(height: 12),
                _KpiGrid(report: report),
                const SizedBox(height: 24),

                // ── Revenue chart ───────────────────────────────────────
                const _SectionHeader(
                  icon: Icons.show_chart_rounded,
                  title: 'Revenue Trend',
                  subtitle: 'Last 6 months',
                ),
                const SizedBox(height: 12),
                _RevenueChart(report: report),
                const SizedBox(height: 24),

                // ── Booking distribution ────────────────────────────────
                const _SectionHeader(
                  icon: Icons.donut_large_rounded,
                  title: 'Platform Overview',
                ),
                const SizedBox(height: 12),
                _PlatformOverview(report: report),
                const SizedBox(height: 24),

                // ── Top pandits ─────────────────────────────────────────
                const _SectionHeader(
                  icon: Icons.emoji_events_rounded,
                  title: 'Top Pandits',
                  subtitle: 'By total bookings',
                ),
                const SizedBox(height: 12),
                _TopPanditsCard(report: report),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

// ── KPI grid ──────────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.report});
  final AdminReport report;

  @override
  Widget build(BuildContext context) {
    final kpis = [
      _KpiItem(
        label: 'Total Bookings',
        value: '${report.totalBookings}',
        sub: '+${report.monthlyBookings} MTD',
        icon: Icons.calendar_today_rounded,
        color: AppColors.primary,
      ),
      _KpiItem(
        label: 'Total Consultations',
        value: '${report.totalConsultations}',
        sub: '+${report.monthlyConsultations} MTD',
        icon: Icons.videocam_rounded,
        color: AppColors.secondary,
      ),
      _KpiItem(
        label: 'Monthly Revenue',
        value: report.formattedMonthlyRevenue,
        sub: 'Total: ${report.formattedTotalRevenue}',
        icon: Icons.currency_rupee_rounded,
        color: AppColors.success,
      ),
      _KpiItem(
        label: 'Active Users',
        value: '${report.activeUsers}',
        sub: '${report.totalUsers} total',
        icon: Icons.people_rounded,
        color: AppColors.info,
      ),
      _KpiItem(
        label: 'Active Pandits',
        value: '${report.activePandits}',
        sub: 'On platform',
        icon: Icons.person_pin_rounded,
        color: AppColors.warning,
      ),
      _KpiItem(
        label: 'Avg. Revenue/Booking',
        value: report.totalBookings > 0
            ? '₹${(report.totalRevenueRupees / report.totalBookings).toStringAsFixed(0)}'
            : '—',
        sub: 'All time',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF8B5CF6),
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: kpis.map((k) => _KpiCard(kpi: k)).toList(),
    );
  }
}

class _KpiItem {
  const _KpiItem({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });
  final String label, value, sub;
  final IconData icon;
  final Color color;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});
  final _KpiItem kpi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(kpi.icon, size: 14, color: kpi.color),
              const Spacer(),
              Text(
                kpi.value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: kpi.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            kpi.label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            kpi.sub,
            style: TextStyle(
              fontSize: 9,
              color: kpi.color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Revenue chart ─────────────────────────────────────────────────────────────

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.report});
  final AdminReport report;

  @override
  Widget build(BuildContext context) {
    final points = report.revenueHistory;
    if (points.isEmpty) return const SizedBox.shrink();

    final maxRevenue =
        points.fold<int>(0, (m, p) => p.revenuePaise > m ? p.revenuePaise : m);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Revenue',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${report.formattedTotalRevenue} total',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bar chart
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: points.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              final frac =
                  maxRevenue > 0 ? p.revenuePaise / maxRevenue : 0.0;
              final isLast = i == points.length - 1;

              return Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Revenue label on hover-equivalent
                    Text(
                      p.revenueRupees >= 1000
                          ? '₹${(p.revenueRupees / 1000).toStringAsFixed(0)}K'
                          : '₹${p.revenueRupees.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 8,
                        color: isLast
                            ? AppColors.primary
                            : AppColors.textHint,
                        fontWeight: isLast
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Bar
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: (frac * 80).clamp(4.0, 80.0),
                      decoration: BoxDecoration(
                        color: isLast
                            ? AppColors.primary
                            : AppColors.primary
                                .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Month label
                    Text(
                      p.month,
                      style: TextStyle(
                        fontSize: 10,
                        color: isLast
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: isLast
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    // Bookings count
                    Text(
                      '${p.bookings} bk',
                      style: const TextStyle(
                        fontSize: 8,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 10),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              const Text('Current month',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textSecondary)),
              const SizedBox(width: 16),
              Container(
                width: 12,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              const Text('Past months',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Platform overview ─────────────────────────────────────────────────────────

class _PlatformOverview extends StatelessWidget {
  const _PlatformOverview({required this.report});
  final AdminReport report;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _OverviewRow(
        label: 'Total Registered Users',
        value: '${report.totalUsers}',
        frac: 1.0,
        color: AppColors.primary,
      ),
      _OverviewRow(
        label: 'Active Users (Monthly)',
        value: '${report.activeUsers}',
        frac: report.totalUsers > 0
            ? report.activeUsers / report.totalUsers
            : 0,
        color: AppColors.success,
      ),
      _OverviewRow(
        label: 'Total Bookings',
        value: '${report.totalBookings}',
        frac: 1.0,
        color: AppColors.secondary,
      ),
      _OverviewRow(
        label: 'Bookings This Month',
        value: '${report.monthlyBookings}',
        frac: report.totalBookings > 0
            ? report.monthlyBookings / report.totalBookings
            : 0,
        color: AppColors.info,
      ),
      _OverviewRow(
        label: 'Total Consultations',
        value: '${report.totalConsultations}',
        frac: 1.0,
        color: const Color(0xFF8B5CF6),
      ),
      _OverviewRow(
        label: 'Sessions This Month',
        value: '${report.monthlyConsultations}',
        frac: report.totalConsultations > 0
            ? report.monthlyConsultations / report.totalConsultations
            : 0,
        color: AppColors.warning,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: rows
            .map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _BarRow(row: r),
                ))
            .toList(),
      ),
    );
  }
}

class _OverviewRow {
  const _OverviewRow({
    required this.label,
    required this.value,
    required this.frac,
    required this.color,
  });
  final String label, value;
  final double frac;
  final Color color;
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.row});
  final _OverviewRow row;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                row.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              row.value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: row.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: row.frac.clamp(0.01, 1.0),
            backgroundColor:
                row.color.withValues(alpha: 0.12),
            valueColor:
                AlwaysStoppedAnimation<Color>(row.color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// ── Top pandits card ──────────────────────────────────────────────────────────

class _TopPanditsCard extends StatelessWidget {
  const _TopPanditsCard({required this.report});
  final AdminReport report;

  @override
  Widget build(BuildContext context) {
    if (report.topPandits.isEmpty) {
      return const Center(
          child: Text('No pandit data available'));
    }

    final maxBookings = report.topPandits
        .fold<int>(0, (m, p) => p.bookings > m ? p.bookings : m);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: report.topPandits.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final p = entry.value;
          final frac =
              maxBookings > 0 ? p.bookings / maxBookings : 0.0;
          final rankColors = [
            Colors.amber,
            Colors.grey.shade400,
            const Color(0xFFCD7F32), // bronze
            AppColors.textHint,
            AppColors.textHint,
          ];
          final rankColor =
              rank <= rankColors.length ? rankColors[rank - 1] : AppColors.textHint;

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                // Rank badge
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: rankColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            p.formattedRevenue,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: frac,
                              backgroundColor: AppColors.primary
                                  .withValues(alpha: 0.1),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                      AppColors.primary),
                              minHeight: 5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${p.bookings} bk',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.star,
                              size: 10, color: Colors.amber),
                          Text(
                            '${p.rating}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;

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
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
