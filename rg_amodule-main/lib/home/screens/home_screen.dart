import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../auth/providers/auth_provider.dart';
import '../../account/providers/notifications_provider.dart';
import '../../consultation/models/pandit_model.dart';
import '../../consultation/providers/consultation_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../packages/providers/packages_provider.dart';
import '../../packages/models/package_model.dart';
import '../models/home_mock_data.dart';
import '../widgets/category_grid.dart';
import '../widgets/hero_slider.dart';

// ── Home Screen ────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ─────────────────────────────────────────────────────────
          _HomeAppBar(userName: user?.name ?? 'Guest'),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // 1. Hero Slider
                HeroSlider(
                  slides: kHeroSlides,
                  height: 190,
                    onActionTap: (route) {
                      final uri = Uri.parse(route);
                      final catName = uri.queryParameters['category'];
                      if (catName != null) {
                        final cat = PackageCategory.values.firstWhere(
                          (c) => c.name == catName,
                          orElse: () => PackageCategory.puja,
                        );
                        ref.read(packageFilterProvider.notifier).setCategory(cat);
                        ref.read(packagePageProvider.notifier).state =
                            kPackagePageSize;
                        context.push(uri.path);
                      } else {
                        context.push(route);
                      }
                    },
                ),
                const SizedBox(height: 24),

                // 2. Quick Categories
                const _SectionHeader(
                  title: 'Browse Categories',
                  padding: EdgeInsets.only(left: 16, right: 16, bottom: 12),
                ),
                CategoryGrid(
                  categories: kCategories,
                  onCategoryTap: (cat) {
                    if (cat.route == null) return;
                    if (cat.route == Routes.packages) {
                      context.go(cat.route!);
                      return;
                    }
                    context.push(cat.route!);
                  },
                ),
                const SizedBox(height: 18),
                const _SectionHeader(
                  title: 'Astrology',
                  padding: EdgeInsets.only(left: 16, right: 16, bottom: 12),
                ),
                const _LiveConsultantsSection(),
                const SizedBox(height: 24),
                const _SectionHeader(
                  title: 'Offline Pandit Booking',
                  padding: EdgeInsets.only(left: 16, right: 16, bottom: 12),
                ),
                const _OfflineBookingMarketplaceSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _LiveConsultantsSection extends ConsumerWidget {
  const _LiveConsultantsSection();

  // Max pandits shown on home screen before "More" button
  static const _kPreviewCount = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(panditsProvider);
    if (state.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (state.error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Unable to load astrologers right now.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final online = state.pandits.where((p) => p.isOnline).toList();
    final list = online.isNotEmpty ? online : state.pandits;
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'No astrologers available currently.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final preview = list.take(_kPreviewCount).toList();
    final hasMore = list.length > _kPreviewCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ...preview.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AstrologerCard(pandit: p),
              )),
          if (hasMore)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push(Routes.consultation),
                icon: const Icon(Icons.people_rounded, size: 18),
                label: Text(
                  'View All Astrologers (${list.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact rectangular card for an astrologer/pandit on the home screen.
class _AstrologerCard extends StatelessWidget {
  const _AstrologerCard({required this.pandit});

  final PanditModel pandit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push(
        Routes.consultationProfile.replaceFirst(':id', pandit.id),
      ),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // ── Avatar ────────────────────────────────────────────────
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    AppColors.primary.withValues(alpha: 0.15),
                backgroundImage:
                    (pandit.avatarUrl ?? '').startsWith('assets/')
                        ? AssetImage(pandit.avatarUrl!)
                        : null,
                child: (pandit.avatarUrl ?? '').startsWith('assets/')
                    ? null
                    : Text(
                        pandit.initials,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
              const SizedBox(width: 12),

              // ── Name + specialty + rating ─────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pandit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pandit.specialty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.warning, size: 13),
                        const SizedBox(width: 3),
                        Text(
                          pandit.rating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${pandit.totalSessions} sessions',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Status + Price ────────────────────────────────────────
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (pandit.isOnline
                              ? AppColors.success
                              : AppColors.warning)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      pandit.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: pandit.isOnline
                            ? AppColors.success
                            : AppColors.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pandit.rates.isNotEmpty
                        ? pandit.rates.first.priceLabel
                        : '₹—',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Offline Booking Marketplace Section ────────────────────────────────────────────────
class _OfflineBookingMarketplaceSection extends StatelessWidget {
  const _OfflineBookingMarketplaceSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.secondary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/offline-pandits'),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.temple_hindu_rounded,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Book Pandits Offline',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Find verified pandits for home ceremonies',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildFeatureChip('Verified'),
                      const SizedBox(width: 6),
                      _buildFeatureChip('Flexible Timing'),
                      const SizedBox(width: 6),
                      _buildFeatureChip('Secure Payment'),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ── App Bar ────────────────────────────────────────────────────────────────────
class _HomeAppBar extends ConsumerWidget {
  const _HomeAppBar({required this.userName});

  final String userName;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    return SliverAppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      pinned: true,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_greeting,',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  userName,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppColors.textPrimary),
            onPressed: () => showSearch(
              context: context,
              delegate: _PoojaSearchDelegate(),
            ),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.textPrimary),
                onPressed: () => context.push(Routes.notifications),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.divider),
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.padding});

  final String title;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: GoogleFonts.playfairDisplay(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

// ── Search ────────────────────────────────────────────────────────────────────

class _PoojaSearchDelegate extends SearchDelegate<String> {
  @override
  String get searchFieldLabel => 'Search poojas, pandits, packages…';

  static const _suggestions = [
    'Satyanarayan Puja',
    'Griha Pravesh',
    'Navgraha Shanti',
    'Kundali Making',
    'Vastu Shastra',
    'Marriage Muhurta',
    'Ganesh Puja',
    'Havan',
    'Online Puja',
  ];

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, ''),
      );

  @override
  Widget buildResults(BuildContext context) {
    final results = _suggestions
        .where((item) => item.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return _buildList(context, results);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final filtered = query.isEmpty
        ? _suggestions
        : _suggestions
            .where((item) => item.toLowerCase().contains(query.toLowerCase()))
            .toList();
    return _buildList(context, filtered);
  }

  Widget _buildList(BuildContext context, List<String> items) {
    if (items.isEmpty) {
      return const Center(child: Text('No results found'));
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (ctx, index) => ListTile(
        leading: const Icon(Icons.search, color: AppColors.primary),
        title: Text(items[index]),
        onTap: () {
          query = items[index];
          close(ctx, items[index]);
          ctx.push('/booking/wizard', extra: {'search': items[index]});
        },
      ),
    );
  }
}

