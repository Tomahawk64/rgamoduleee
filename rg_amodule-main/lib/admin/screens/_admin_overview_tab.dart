// lib/admin/screens/_admin_overview_tab.dart
// Visually-rich admin overview — charts via CustomPainter (zero extra deps).
// Entrance animations via flutter_animate (already in pubspec).
// NO auto-refresh — admin must press refresh button manually.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../booking/models/booking_status.dart';
import '../../core/constants/demo_config.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../models/admin_models.dart';
import '../providers/admin_package_catalog_provider.dart';
import 'admin_offline_bookings_screen.dart';

class AdminOverviewTab extends StatelessWidget {
  const AdminOverviewTab({
    super.key,
    required this.state,
    required this.catalogState,
    required this.userName,
  });

  final AdminState state;
  final AdminPackageCatalogState catalogState;
  final String userName;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final report = state.report;
    final bookings = state.bookings;

    // booking status counts
    final statusCounts = <BookingStatus, int>{};
    for (final b in bookings) {
      statusCounts[b.status] = (statusCounts[b.status] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // 1 – Hero banner
        _HeroBanner(userName: userName)
            .animate()
            .fadeIn(duration: 380.ms)
            .slideY(begin: -0.06, end: 0, duration: 380.ms, curve: Curves.easeOut),

        if (DemoConfig.demoMode) ...[
          const SizedBox(height: 10),
          _DemoBanner().animate().fadeIn(delay: 80.ms, duration: 300.ms),
        ],

        const SizedBox(height: 20),

        // 2 – KPI cards
        if (report != null) ...[
          _SectionHeader(icon: Icons.query_stats_rounded, title: 'Key Metrics'),
          const SizedBox(height: 10),
          _KpiGrid(report: report)
              .animate()
              .fadeIn(delay: 60.ms, duration: 340.ms)
              .slideY(begin: 0.05, end: 0, duration: 340.ms, curve: Curves.easeOut),
          const SizedBox(height: 22),
        ],

        // 3 – Revenue area chart
        if (report != null && report.revenueHistory.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.show_chart_rounded,
            title: 'Revenue Trend',
            trailing: _LegendDot(color: AppColors.primary, label: 'Revenue'),
          ),
          const SizedBox(height: 10),
          _RevenueAreaChart(history: report.revenueHistory)
              .animate().fadeIn(delay: 120.ms, duration: 380.ms),
          const SizedBox(height: 22),
        ],

        // 4 – Booking donut + monthly bars
        if (report != null) ...[
          _SectionHeader(icon: Icons.donut_large_rounded, title: 'Booking Breakdown'),
          const SizedBox(height: 10),
          _BookingInsightRow(
            statusCounts: statusCounts,
          ).animate().fadeIn(delay: 160.ms, duration: 380.ms),
          const SizedBox(height: 22),
        ],

        // 5 – Quick actions (4-col icon grid)
        _SectionHeader(icon: Icons.bolt_rounded, title: 'Quick Actions'),
        const SizedBox(height: 10),
        _QuickActionGrid(state: state, catalogState: catalogState)
            .animate().fadeIn(delay: 200.ms, duration: 380.ms),
        const SizedBox(height: 22),

        // 6 – Top pandits leaderboard
        if (report != null && report.topPandits.isNotEmpty) ...[
          _SectionHeader(icon: Icons.emoji_events_rounded, title: 'Top Pandits'),
          const SizedBox(height: 10),
          _TopPanditsCard(pandits: report.topPandits)
              .animate().fadeIn(delay: 240.ms, duration: 380.ms),
          const SizedBox(height: 22),
        ],

        // 7 – Pandit activity horizontal bars
        if (state.pandits.isNotEmpty) ...[
          _SectionHeader(icon: Icons.bar_chart_rounded, title: 'Pandit Activity'),
          const SizedBox(height: 10),
          _PanditActivityChart(pandits: state.pandits.take(6).toList())
              .animate().fadeIn(delay: 280.ms, duration: 380.ms),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// HERO BANNER
// ═══════════════════════════════════════════════════════════════════

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.userName});
  final String userName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6B1321), Color(0xFFB04E12), Color(0xFFD4611A)],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFD4611A),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -18,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white10,
              ),
            ),
          ),
          Positioned(
            right: 28,
            bottom: -28,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white10,
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.admin_panel_settings_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Dashboard',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (userName.isNotEmpty)
                      Text(
                        'Welcome back, $userName',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white38),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION HEADER helpers
// ═══════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.icon, required this.title, this.trailing});
  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 15, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// KPI GRID — gradient cards
// ═══════════════════════════════════════════════════════════════════

class _KpiGrid extends ConsumerWidget {
  const _KpiGrid({required this.report});
  final AdminReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Load offline bookings if not already loaded
    final offlineState = ref.watch(adminOfflineBookingsProvider);
    if (offlineState.bookings.isEmpty && !offlineState.loading) {
      Future.microtask(
          () => ref.read(adminOfflineBookingsProvider.notifier).loadAll());
    }
    final offlineCtrl = ref.read(adminOfflineBookingsProvider.notifier);

    final items = [
      _KpiData(
        value: '${report.totalBookings}',
        label: 'Total Bookings',
        sub: '+${report.monthlyBookings} this month',
        icon: Icons.calendar_today_rounded,
        gradient: const LinearGradient(
            colors: [Color(0xFFD4611A), Color(0xFFE87B2F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      _KpiData(
        value: '${report.totalConsultations}',
        label: 'Astrology Sessions',
        sub: '+${report.monthlyConsultations} this month',
        icon: Icons.videocam_rounded,
        gradient: const LinearGradient(
            colors: [Color(0xFF6B1321), Color(0xFF9E2E52)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      _KpiData(
        value: report.formattedTotalRevenue,
        label: 'Total Revenue',
        sub: offlineCtrl.refundedCount > 0
            ? '${report.formattedMonthlyRevenue}/mo • ${offlineCtrl.refundedCount} refunds'
            : '${report.formattedMonthlyRevenue}/month',
        icon: Icons.currency_rupee_rounded,
        gradient: const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      _KpiData(
        value: '${report.activeUsers}',
        label: 'Active Users',
        sub: '${report.totalUsers} registered',
        icon: Icons.people_rounded,
        gradient: const LinearGradient(
            colors: [Color(0xFF01579B), Color(0xFF0277BD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      _KpiData(
        value: '${report.activePandits}',
        label: 'Active Pandits',
        sub: 'Service providers',
        icon: Icons.person_pin_rounded,
        gradient: const LinearGradient(
            colors: [Color(0xFF4A148C), Color(0xFF6A1B9A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      _KpiData(
        value: '${offlineCtrl.totalBookings}',
        label: 'Offline Bookings',
        sub: offlineCtrl.refundedCount > 0
            ? '${offlineCtrl.activeBookings} active • ${offlineCtrl.refundedCount} refunded'
            : '${offlineCtrl.activeBookings} active',
        icon: Icons.location_on_rounded,
        gradient: const LinearGradient(
            colors: [Color(0xFF795548), Color(0xFF8D6E63)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
    ];

    return Column(
      children: [
        Row(children: [
          Expanded(child: _KpiCard(data: items[0])),
          const SizedBox(width: 10),
          Expanded(child: _KpiCard(data: items[1])),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _KpiCard(data: items[2])),
          const SizedBox(width: 10),
          Expanded(child: _KpiCard(data: items[3])),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _KpiCard(data: items[4])),
          const SizedBox(width: 10),
          Expanded(child: _KpiCard(data: items[5])),
        ]),
      ],
    );
  }
}

class _KpiData {
  const _KpiData(
      {required this.value,
      required this.label,
      required this.sub,
      required this.icon,
      required this.gradient});
  final String value, label, sub;
  final IconData icon;
  final LinearGradient gradient;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});
  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: data.gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: data.gradient.colors.first.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(data.icon, size: 17, color: Colors.white),
                    ),
                    const Icon(Icons.trending_up_rounded,
                        size: 14, color: Colors.white38),
                  ]),
              const SizedBox(height: 10),
              Text(data.value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: Colors.white,
                      height: 1.0),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(data.label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(data.sub,
                  style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// REVENUE AREA CHART  (CustomPainter — zero extra deps)
// ═══════════════════════════════════════════════════════════════════

class _RevenueAreaChart extends StatefulWidget {
  const _RevenueAreaChart({required this.history});
  final List<MonthlyPoint> history;

  @override
  State<_RevenueAreaChart> createState() => _RevenueAreaChartState();
}

class _RevenueAreaChartState extends State<_RevenueAreaChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: widget.history.map((p) {
                final isLast = p == widget.history.last;
                return Expanded(
                  child: isLast
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '₹${(p.revenuePaise / 100).toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      : const SizedBox(height: 18),
                );
              }).toList(),
            ),
          ),
          AnimatedBuilder(
            animation: _anim,
            builder: (_, _) => SizedBox(
              height: 100,
              child: CustomPaint(
                painter: _AreaChartPainter(
                  points: widget.history
                      .map((p) => p.revenuePaise.toDouble())
                      .toList(),
                  progress: _anim.value,
                  lineColor: AppColors.primary,
                  fillColor: AppColors.primary.withValues(alpha: 0.12),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Row(
              children: widget.history.map((p) {
                final isLast = p == widget.history.last;
                return Expanded(
                  child: Text(p.month,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight:
                              isLast ? FontWeight.bold : FontWeight.normal,
                          color: isLast
                              ? AppColors.primary
                              : AppColors.textSecondary)),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaChartPainter extends CustomPainter {
  _AreaChartPainter({
    required this.points,
    required this.progress,
    required this.lineColor,
    required this.fillColor,
  });
  final List<double> points;
  final double progress;
  final Color lineColor, fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final maxVal = points.reduce(math.max);
    if (maxVal <= 0) return;

    final xs = List.generate(
        points.length, (i) => i * size.width / (points.length - 1));
    final ys =
        points.map((v) => (1 - v / maxVal) * size.height * 0.85 + 4).toList();

    final linePath = Path()..moveTo(xs[0], ys[0]);
    for (int i = 1; i < xs.length; i++) {
      final cpX = (xs[i - 1] + xs[i]) / 2;
      linePath.cubicTo(cpX, ys[i - 1], cpX, ys[i], xs[i], ys[i]);
    }

    canvas.save();
    canvas.clipRect(
        Rect.fromLTWH(0, 0, size.width * progress, size.height));

    // fill
    final fillPath = Path.from(linePath)
      ..lineTo(xs.last, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        fillPath,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill);

    // line
    canvas.drawPath(
        linePath,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    // dots
    for (int i = 0; i < xs.length; i++) {
      canvas.drawCircle(Offset(xs[i], ys[i]), 3,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(xs[i], ys[i]), 3,
          Paint()
            ..color = lineColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_AreaChartPainter o) =>
      o.progress != progress || o.points != points;
}

// ═══════════════════════════════════════════════════════════════════
// BOOKING INSIGHT ROW — donut chart
// ═══════════════════════════════════════════════════════════════════

class _BookingInsightRow extends StatefulWidget {
  const _BookingInsightRow({required this.statusCounts});
  final Map<BookingStatus, int> statusCounts;

  @override
  State<_BookingInsightRow> createState() => _BookingInsightRowState();
}

class _BookingInsightRowState extends State<_BookingInsightRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.statusCounts.values.fold(0, (a, b) => a + b);
    final segments = BookingStatus.values
        .where((s) => (widget.statusCounts[s] ?? 0) > 0)
        .map((s) => _DonutSegment(
            label: s.label,
            value: widget.statusCounts[s]!,
            color: s.color))
        .toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Donut
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 14,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(children: [
              AnimatedBuilder(
                animation: _anim,
                builder: (_, _) => SizedBox(
                  width: 120,
                  height: 120,
                  child: CustomPaint(
                    painter: _DonutPainter(
                      segments: segments,
                      progress: _anim.value,
                      centerText: total > 0 ? '$total' : '0',
                      centerSub: 'bookings',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...segments.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: s.color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(s.label,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary))),
                      Text('${s.value}',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                    ]),
                  )),
            ]),
          ),
        ),

      ],
    );
  }
}

class _DonutSegment {
  const _DonutSegment(
      {required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.segments,
    required this.progress,
    required this.centerText,
    required this.centerSub,
  });
  final List<_DonutSegment> segments;
  final double progress;
  final String centerText, centerSub;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<int>(0, (s, e) => s + e.value);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeW = 18.0;
    const gap = 0.04;

    double start = -math.pi / 2;
    for (final seg in segments) {
      final sweep =
          (seg.value / total) * 2 * math.pi * progress - gap;
      if (sweep > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - strokeW / 2),
          start,
          sweep,
          false,
          Paint()
            ..color = seg.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..strokeCap = StrokeCap.round,
        );
      }
      start += (seg.value / total) * 2 * math.pi * progress;
    }

    if (progress >= 0.9) {
      final tp1 = TextPainter(
        text: TextSpan(
            text: centerText,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp1.paint(canvas, center - Offset(tp1.width / 2, tp1.height / 2 + 6));

      final tp2 = TextPainter(
        text: TextSpan(
            text: centerSub,
            style: const TextStyle(
                fontSize: 9, color: AppColors.textSecondary)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp2.paint(
          canvas, center + Offset(-tp2.width / 2, tp1.height / 2 - 4));
    }
  }

  @override
  bool shouldRepaint(_DonutPainter o) =>
      o.progress != progress || o.segments != segments;
}

// ═══════════════════════════════════════════════════════════════════
// QUICK ACTION GRID — 4-col icon tiles
// ═══════════════════════════════════════════════════════════════════

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid(
      {required this.state, required this.catalogState});
  final AdminState state;
  final AdminPackageCatalogState catalogState;

  @override
  Widget build(BuildContext context) {
    final pendingBookings =
        state.bookings.where((b) => b.status.isActive).length;
    final activeSessions = state.consultations
        .where((c) => c.status == AdminSessionStatus.active)
        .length;

    final items = [
      _ActionConfig(
          'Bookings',
          pendingBookings > 0
              ? '$pendingBookings active'
              : '${state.bookings.length} total',
          Icons.list_alt_rounded,
          const Color(0xFF2E7D32),
          Routes.adminBookings,
          badgeCount: pendingBookings),
      _ActionConfig('Pandits', '${state.pandits.length} registered',
          Icons.supervised_user_circle_rounded,
          const Color(0xFF0277BD), Routes.adminPandits),
      _ActionConfig('Packages', '${catalogState.packages.length} listings',
          Icons.temple_hindu_rounded, AppColors.primary, Routes.adminPackages),
      _ActionConfig('Sp. Poojas', '${state.poojas.length} listings',
          Icons.auto_awesome_rounded, const Color(0xFF6A1B9A),
          Routes.adminPoojas),
      _ActionConfig(
          'Astrology',
          activeSessions > 0
              ? '$activeSessions live'
              : '${state.consultations.length} total',
          Icons.video_call_rounded,
          AppColors.info,
          Routes.adminConsultations,
          badgeCount: activeSessions),
      _ActionConfig('Shop', '${state.products.length} products',
          Icons.shopping_bag_rounded, const Color(0xFFE65100),
          Routes.adminProducts),
      _ActionConfig('Users', '${state.users.length} accounts',
          Icons.people_rounded, const Color(0xFF00695C), Routes.adminUsers),
      _ActionConfig('Offline', 'Pandit bookings',
          Icons.location_on_rounded, const Color(0xFF795548),
          Routes.adminOfflineBookings),
      _ActionConfig('Reports', 'Analytics', Icons.bar_chart_rounded,
          const Color(0xFF6D4C41), Routes.adminReports),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _ActionTile(
        item: items[i],
        onTap: () => ctx.push(items[i].route),
      )
          .animate(delay: (i * 28).ms)
          .fadeIn(duration: 220.ms)
          .scale(
              begin: const Offset(0.88, 0.88),
              end: const Offset(1, 1),
              duration: 220.ms),
    );
  }
}

class _ActionConfig {
  const _ActionConfig(
      this.title, this.sub, this.icon, this.color, this.route,
      {this.badgeCount = 0});
  final String title, sub, route;
  final IconData icon;
  final Color color;
  final int badgeCount;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.item, required this.onTap});
  final _ActionConfig item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: item.color.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
                color: item.color.withValues(alpha: 0.07),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, size: 18, color: item.color),
                ),
                const SizedBox(height: 5),
                Text(item.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(item.sub,
                    style: TextStyle(
                        fontSize: 8,
                        color: item.badgeCount > 0
                            ? item.color
                            : AppColors.textSecondary,
                        fontWeight: item.badgeCount > 0
                            ? FontWeight.w600
                            : FontWeight.normal),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (item.badgeCount > 0)
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                    color: item.color, shape: BoxShape.circle),
                child: Center(
                    child: Text('${item.badgeCount}',
                        style: const TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.bold))),
              ),
            ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TOP PANDITS CARD  (ranked with progress bars)
// ═══════════════════════════════════════════════════════════════════

class _TopPanditsCard extends StatelessWidget {
  const _TopPanditsCard({required this.pandits});
  final List<TopPandit> pandits;

  static const _medals = ['🥇', '🥈', '🥉'];
  static const _medalColors = [
    Color(0xFFFFD700),
    Color(0xFFC0C0C0),
    Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context) {
    final top = pandits.take(3).toList();
    final maxB = top.map((p) => p.bookings).reduce(math.max).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: top.asMap().entries.map((e) {
          final i = e.key;
          final p = e.value;
          final frac = maxB > 0 ? p.bookings / maxB : 0.0;
          final mc = i < _medalColors.length
              ? _medalColors[i]
              : AppColors.textSecondary;

          return Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              border: i < top.length - 1
                  ? const Border(
                      bottom: BorderSide(
                          color: AppColors.divider, width: 0.5))
                  : null,
            ),
            child: Row(children: [
              Text(i < _medals.length ? _medals[i] : '${i + 1}',
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 16,
                backgroundColor: mc.withValues(alpha: 0.15),
                child: Text(
                  p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: mc),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: frac,
                      minHeight: 4,
                      backgroundColor: mc.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(mc),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                      '${p.bookings} bookings · ★ ${p.rating.toStringAsFixed(1)}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary)),
                ],
              )),
              const SizedBox(width: 10),
              Text(p.formattedRevenue,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                      fontSize: 12)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PANDIT ACTIVITY — animated horizontal bar chart
// ═══════════════════════════════════════════════════════════════════

class _PanditActivityChart extends StatefulWidget {
  const _PanditActivityChart({required this.pandits});
  final List<AdminPandit> pandits;

  @override
  State<_PanditActivityChart> createState() =>
      _PanditActivityChartState();
}

class _PanditActivityChartState extends State<_PanditActivityChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxB = widget.pandits
        .map((p) => p.totalBookings)
        .fold(0, math.max)
        .toDouble();

    const barColors = [
      AppColors.primary,
      Color(0xFF6B1321),
      AppColors.info,
      AppColors.success,
      Color(0xFF6A1B9A),
      Color(0xFFE65100),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, _) => Column(
          children: widget.pandits.asMap().entries.map((e) {
            final i = e.key;
            final p = e.value;
            final frac =
                maxB > 0 ? (p.totalBookings / maxB) * _anim.value : 0.0;
            final color = barColors[i % barColors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(
                  width: 58,
                  child: Text(
                    p.name.split(' ').first,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(children: [
                    Container(
                      height: 22,
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    FractionallySizedBox(
                      widthFactor: frac.clamp(0.0, 1.0),
                      child: Container(
                        height: 22,
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              color.withValues(alpha: 0.55),
                              color,
                            ]),
                            borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('${p.totalBookings} bookings',
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                Text('★${p.rating.toStringAsFixed(1)}',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ]),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// DEMO BANNER
// ═══════════════════════════════════════════════════════════════════

class _DemoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.28)),
      ),
      child: Row(children: [
        const Icon(Icons.science_rounded, size: 16, color: AppColors.info),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('Demo Mode — destructive actions are disabled.',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.info,
                  fontWeight: FontWeight.w500)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('DEMO',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppColors.info,
                  letterSpacing: 1)),
        ),
      ]),
    );
  }
}
