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
import '../../packages/widgets/package_list_card.dart';
import '../../packages/models/package_model.dart';
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
                    if (cat.route != null) context.push(cat.route!);
                  },
                ),
                const SizedBox(height: 18),
                const _SectionHeader(
                  title: 'Live Consultants Available',
                  padding: EdgeInsets.only(left: 16, right: 16, bottom: 12),
                ),
                const _LiveConsultantsSection(),
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
          'Unable to load consultants right now.',
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
          'No consultants available currently.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return SizedBox(
      height: 228,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _LiveConsultantCard(pandit: list[i]),
      ),
    );
  }
}

class _LiveConsultantCard extends StatelessWidget {
  const _LiveConsultantCard({required this.pandit});

  final PanditModel pandit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 206,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(
          Routes.consultationProfile.replaceFirst(':id', pandit.id),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.10),
                AppColors.secondary.withValues(alpha: 0.10),
              ],
            ),
            border: Border.all(color: AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      backgroundImage: (pandit.avatarUrl ?? '').startsWith('assets/')
                          ? AssetImage(pandit.avatarUrl!)
                          : null,
                      child: (pandit.avatarUrl ?? '').startsWith('assets/')
                          ? null
                          : Text(
                              pandit.initials,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (pandit.isOnline ? AppColors.success : AppColors.warning)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        pandit.isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          color:
                              pandit.isOnline ? AppColors.success : AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  pandit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  pandit.specialty,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                    const SizedBox(width: 3),
                    Text(
                      pandit.rating.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${pandit.totalSessions} sessions',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      pandit.rates.isNotEmpty ? pandit.rates.first.priceLabel : '₹—',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 18, color: AppColors.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
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

