// lib/admin/screens/admin_statistics_screen.dart
// Admin panel for viewing booking statistics

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../offline_booking/providers/offline_booking_provider.dart';
import '../models/booking_statistics_models.dart';

class AdminStatisticsScreen extends ConsumerStatefulWidget {
  const AdminStatisticsScreen({super.key});

  @override
  ConsumerState<AdminStatisticsScreen> createState() =>
      _AdminStatisticsScreenState();
}

class _AdminStatisticsScreenState extends ConsumerState<AdminStatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PanditBookingStats> _panditStats = [];
  List<UserBookingStats> _userStats = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final pandits = await ref.read(offlineBookingRepositoryProvider).getAllPanditsStats();
      final users = await ref.read(offlineBookingRepositoryProvider).getAllUsersStats();
      
      setState(() {
        _panditStats = pandits;
        _userStats = users;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Booking Statistics'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Pandits'),
            Tab(text: 'Users'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadStatistics,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _PanditsStatsTab(panditStats: _panditStats),
                    _UsersStatsTab(userStats: _userStats),
                  ],
                ),
    );
  }
}

class _PanditsStatsTab extends StatelessWidget {
  const _PanditsStatsTab({required this.panditStats});

  final List<PanditBookingStats> panditStats;

  @override
  Widget build(BuildContext context) {
    if (panditStats.isEmpty) {
      return const Center(
        child: Text('No pandit statistics available'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: panditStats.length,
      itemBuilder: (context, index) {
        final stats = panditStats[index];
        return _PanditStatsCard(stats: stats);
      },
    );
  }
}

class _UsersStatsTab extends StatelessWidget {
  const _UsersStatsTab({required this.userStats});

  final List<UserBookingStats> userStats;

  @override
  Widget build(BuildContext context) {
    if (userStats.isEmpty) {
      return const Center(
        child: Text('No user statistics available'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: userStats.length,
      itemBuilder: (context, index) {
        final stats = userStats[index];
        return _UserStatsCard(stats: stats);
      },
    );
  }
}

class _PanditStatsCard extends StatelessWidget {
  const _PanditStatsCard({required this.stats});

  final PanditBookingStats stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stats.panditName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ID: ${stats.panditId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _StatsOverview(statistics: stats.statistics),
            const SizedBox(height: 16),
            _MonthlyStatsCard(monthlyStats: stats.statistics.monthlyStats),
            const SizedBox(height: 12),
            _WeeklyStatsCard(weeklyStats: stats.statistics.weeklyStats),
          ],
        ),
      ),
    );
  }
}

class _UserStatsCard extends StatelessWidget {
  const _UserStatsCard({required this.stats});

  final UserBookingStats stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.info,
                  child: Icon(Icons.account_circle, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stats.userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ID: ${stats.userId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _StatsOverview(statistics: stats.statistics),
            const SizedBox(height: 16),
            _MonthlyStatsCard(monthlyStats: stats.statistics.monthlyStats),
            const SizedBox(height: 12),
            _WeeklyStatsCard(weeklyStats: stats.statistics.weeklyStats),
          ],
        ),
      ),
    );
  }
}

class _StatsOverview extends StatelessWidget {
  const _StatsOverview({required this.statistics});

  final BookingStatistics statistics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Total',
            value: '${statistics.totalBookings}',
            color: AppColors.primary,
          ),
        ),
        Expanded(
          child: _StatTile(
            label: 'Completed',
            value: '${statistics.completedBookings}',
            color: AppColors.success,
          ),
        ),
        Expanded(
          child: _StatTile(
            label: 'Cancelled',
            value: '${statistics.cancelledBookings}',
            color: AppColors.error,
          ),
        ),
        Expanded(
          child: _StatTile(
            label: 'Pending',
            value: '${statistics.pendingBookings}',
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyStatsCard extends StatelessWidget {
  const _MonthlyStatsCard({required this.monthlyStats});

  final MonthlyStatistics monthlyStats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                '${monthlyStats.monthName} ${monthlyStats.year}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SmallStatTile(
                  label: 'Total',
                  value: '${monthlyStats.totalBookings}',
                ),
              ),
              Expanded(
                child: _SmallStatTile(
                  label: 'Completed',
                  value: '${monthlyStats.completedBookings}',
                  color: AppColors.success,
                ),
              ),
              Expanded(
                child: _SmallStatTile(
                  label: 'Cancelled',
                  value: '${monthlyStats.cancelledBookings}',
                  color: AppColors.error,
                ),
              ),
              Expanded(
                child: _SmallStatTile(
                  label: 'Pending',
                  value: '${monthlyStats.pendingBookings}',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyStatsCard extends StatelessWidget {
  const _WeeklyStatsCard({required this.weeklyStats});

  final WeeklyStatistics weeklyStats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.date_range, size: 16, color: AppColors.info),
              const SizedBox(width: 8),
              Text(
                'Week ${weeklyStats.weekNumber}, ${weeklyStats.year}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SmallStatTile(
                  label: 'Total',
                  value: '${weeklyStats.totalBookings}',
                ),
              ),
              Expanded(
                child: _SmallStatTile(
                  label: 'Completed',
                  value: '${weeklyStats.completedBookings}',
                  color: AppColors.success,
                ),
              ),
              Expanded(
                child: _SmallStatTile(
                  label: 'Cancelled',
                  value: '${weeklyStats.cancelledBookings}',
                  color: AppColors.error,
                ),
              ),
              Expanded(
                child: _SmallStatTile(
                  label: 'Pending',
                  value: '${weeklyStats.pendingBookings}',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallStatTile extends StatelessWidget {
  const _SmallStatTile({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color ?? AppColors.textPrimary,
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
      ],
    );
  }
}
