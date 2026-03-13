import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../auth/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../packages/providers/packages_provider.dart';
import '../../packages/widgets/package_list_card.dart';
import '../../widgets/loading_shimmer.dart';
import '../models/home_mock_data.dart';
import '../models/home_models.dart';
import '../widgets/category_grid.dart';
import '../widgets/hero_slider.dart';
import '../widgets/pandit_card.dart';

// ── Online / Offline filter state ─────────────────────────────────────────────
enum PanditFilter { all, online, offline }

final _panditFilterProvider =
    StateProvider<PanditFilter>((_) => PanditFilter.all);

// ── Home Screen ────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final filter = ref.watch(_panditFilterProvider);

    final pandits = kMockPandits.where((p) {
      switch (filter) {
        case PanditFilter.online:
          return p.isOnline;
        case PanditFilter.offline:
          return !p.isOnline;
        case PanditFilter.all:
          return true;
      }
    }).toList();

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
                  onActionTap: (route) => context.push(route),
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
                    if (cat.route != null) context.push(cat.route!);
                  },
                ),
                const SizedBox(height: 28),

                // 3. Featured Pandits header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: _SectionHeader(
                          title: 'Featured Pandits',
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/services'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: AppColors.primary,
                        ),
                        child: const Text('See all',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Online / Offline toggle
                _PanditFilterToggle(
                  selected: filter,
                  onChanged: (v) =>
                      ref.read(_panditFilterProvider.notifier).state = v,
                ),
                const SizedBox(height: 14),

                // Pandit horizontal list
                _PanditList(pandits: pandits),
                const SizedBox(height: 28),

                // 4. Popular Packages header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: _SectionHeader(
                          title: 'Popular Packages',
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/packages'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: AppColors.primary,
                        ),
                        child: const Text('See all',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),

          // 5. Packages as sliver list (Supabase-driven featured packages)
          _FeaturedPackagesSliver(),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Featured Packages (Supabase-driven) ───────────────────────────────────────

class _FeaturedPackagesSliver extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(featuredPackagesProvider);

    return async.when(
      loading: () => const SliverToBoxAdapter(child: ListShimmer(itemCount: 3)),
      error: (_, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Unable to load packages. Check your connection.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (packages) {
        if (packages.isEmpty) {
          // Graceful fallback to mock data while DB is empty
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text(
                'No featured packages yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }
        return SliverList.builder(
          itemCount: packages.length,
          itemBuilder: (_, i) => PackageListCard(
            package: packages[i],
            onTap: () => context.push('/booking/wizard'),
          ),
        );
      },
    );
  }
}

// ── App Bar ────────────────────────────────────────────────────────────────────
class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar({required this.userName});

  final String userName;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
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
                onPressed: () => _showNotificationsSheet(context),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
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

// ── Online/Offline toggle ──────────────────────────────────────────────────────
class _PanditFilterToggle extends StatelessWidget {
  const _PanditFilterToggle({
    required this.selected,
    required this.onChanged,
  });

  final PanditFilter selected;
  final ValueChanged<PanditFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: PanditFilter.values.map((f) {
            final isSelected = selected == f;
            return GestureDetector(
              onTap: () => onChanged(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (f == PanditFilter.online)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      )
                    else if (f == PanditFilter.offline)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: const BoxDecoration(
                          color: AppColors.textHint,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      _label(f),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _label(PanditFilter f) {
    switch (f) {
      case PanditFilter.all:
        return 'All';
      case PanditFilter.online:
        return 'Online';
      case PanditFilter.offline:
        return 'Offline';
    }
  }
}

// ── Pandit horizontal list ─────────────────────────────────────────────────────
class _PanditList extends StatelessWidget {
  const _PanditList({required this.pandits});

  final List<MockPandit> pandits;

  @override
  Widget build(BuildContext context) {
    if (pandits.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(
          child: Text(
            'No pandits available right now.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return SizedBox(
      height: 228,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: pandits.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => PanditCard(
          pandit: pandits[i],
          onTap: () => context.push('/booking/wizard'),
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
        .where((s) => s.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return _buildList(context, results);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final filtered = query.isEmpty
        ? _suggestions
        : _suggestions
            .where((s) => s.toLowerCase().contains(query.toLowerCase()))
            .toList();
    return _buildList(context, filtered);
  }

  Widget _buildList(BuildContext context, List<String> items) {
    if (items.isEmpty) {
      return const Center(child: Text('No results found'));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (ctx, i) => ListTile(
        leading: const Icon(Icons.search, color: AppColors.primary),
        title: Text(items[i]),
        onTap: () {
          query = items[i];
          close(ctx, items[i]);
          ctx.push('/booking/wizard', extra: {'search': items[i]});
        },
      ),
    );
  }
}

// ── Notifications Sheet ───────────────────────────────────────────────────────

void _showNotificationsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (scrollCtx, ctrl) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Notifications',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: ctrl,
              children: const [
                _NotificationTile(
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                  title: 'Booking Confirmed',
                  subtitle: 'Your Satyanarayan Puja is confirmed for tomorrow.',
                  time: '2 hrs ago',
                ),
                _NotificationTile(
                  icon: Icons.payment,
                  color: AppColors.primary,
                  title: 'Payment Successful',
                  subtitle: 'Payment of ₹2,100 received for booking #BK001.',
                  time: '3 hrs ago',
                ),
                _NotificationTile(
                  icon: Icons.person,
                  color: AppColors.secondary,
                  title: 'Pandit Assigned',
                  subtitle: 'Pt. Ramesh Sharma has been assigned to your booking.',
                  time: 'Yesterday',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style:
              const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: Text(time,
          style:
              const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    );
  }
}

