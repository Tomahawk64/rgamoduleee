import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/base_scaffold.dart';
import '../models/pandit_model.dart';
import '../providers/consultation_provider.dart';

class ConsultationScreen extends ConsumerWidget {
  const ConsultationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(consultationRealtimeTickProvider, (_, __) {
      ref.read(panditsProvider.notifier).refresh();
    });

    final panditsState = ref.watch(panditsProvider);
    final onlinePandits = panditsState.pandits.where((p) => p.isOnline).toList();

    return BaseScaffold(
      title: 'Astrology',
      showBackButton: true,
      body: RefreshIndicator(
        onRefresh: () => ref.read(panditsProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeroBanner(),
            const SizedBox(height: 20),
            _SectionHeader(
              title: 'Available Consultants',
              subtitle: panditsState.loading
                  ? 'Loading...'
              : '${onlinePandits.length} online now',
            ),
            const SizedBox(height: 12),
            if (panditsState.loading)
              const _LoadingCards()
            else if (panditsState.error != null)
              _ErrorView(
                message: panditsState.error!,
                onRetry: () => ref.read(panditsProvider.notifier).refresh(),
              )
            else ...[
              ...onlinePandits.map(
                (p) => _PanditCard(
                  pandit: p,
                  onConnect: () => context.push(
                    Routes.consultationProfile.replaceFirst(':id', p.id),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.secondary, AppColors.secondaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withAlpha(60),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Get Expert Guidance',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Book a slot with certified pandits.\nPandit can accept or propose a new time.',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
      ],
    );
  }
}

class _PanditCard extends StatelessWidget {
  const _PanditCard({required this.pandit, this.onConnect});
  final PanditModel pandit;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    final live10 = _live10MinuteRate(pandit);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary.withAlpha(20),
                      backgroundImage: pandit.avatarUrl != null &&
                              pandit.avatarUrl!.startsWith('assets/')
                          ? AssetImage(pandit.avatarUrl!)
                          : null,
                      child: pandit.avatarUrl != null &&
                              pandit.avatarUrl!.startsWith('assets/')
                          ? null
                          : Text(
                              pandit.initials,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    if (pandit.isOnline)
                      Positioned(
                        bottom: 1,
                        right: 1,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pandit.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pandit.specialty,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Icon(Icons.star_rounded,
                              color: AppColors.warning, size: 14),
                          Text(
                            pandit.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${pandit.totalSessions} sessions',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${pandit.experienceYears}y exp',
                            style: const TextStyle(
                              fontSize: 12,
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
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: pandit.languagesSpoken.map((l) => _Chip(label: l)).toList(),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Price',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    Text(
                      live10.priceLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.primary,
                      ),
                    ),
                    const Text(
                      '10 min fixed',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: onConnect,
                  icon: const Icon(Icons.event_available_rounded, size: 16),
                  label: const Text('Request Slot',
                      style: TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

ConsultationRate _live10MinuteRate(PanditModel pandit) {
  final exact = pandit.rates.where((r) => r.duration == 10).firstOrNull;
  if (exact != null) return exact;
  final first = pandit.rates.firstOrNull;
  if (first == null) {
    return const ConsultationRate(duration: 10, totalPaise: 9900);
  }
  final perMinute = (first.totalPaise / first.duration).round();
  return ConsultationRate(duration: 10, totalPaise: perMinute * 10);
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.secondary.withAlpha(18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          color: AppColors.secondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _LoadingCards extends StatelessWidget {
  const _LoadingCards();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                _ShimmerBox(width: 60, height: 60, radius: 30),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShimmerBox(width: 150, height: 14),
                      SizedBox(height: 6),
                      _ShimmerBox(width: 100, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({required this.width, required this.height, this.radius = 6});
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(40),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
