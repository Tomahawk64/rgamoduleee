import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../models/package_model.dart';
import '../providers/packages_provider.dart';

class PackageDetailScreen extends ConsumerWidget {
  const PackageDetailScreen({super.key, required this.packageId});

  final String packageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pkgAsync = ref.watch(packageByIdProvider(packageId));

    return pkgAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Unable to load package details')),
      ),
      data: (pkg) {
        if (pkg == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Package not found')),
          );
        }
        return _DetailView(package: pkg);
      },
    );
  }
}

// ── Main detail view ──────────────────────────────────────────────────────────
class _DetailView extends StatelessWidget {
  const _DetailView({required this.package});
  final PackageModel package;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Hero header ───────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroBackground(package: package),
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Text(
                package.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  shadows: [
                    Shadow(
                        color: Colors.black45,
                        blurRadius: 4,
                        offset: Offset(0, 1)),
                  ],
                ),
              ),
            ),
          ),

          // ── Quick stats bar ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: cs.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatItem(
                    icon: Icons.star_rounded,
                    iconColor: Colors.amber[700]!,
                    label: package.rating.toStringAsFixed(1),
                    sublabel: '${package.reviewCount} reviews',
                  ),
                  _Divider(),
                  _StatItem(
                    icon: Icons.schedule_rounded,
                    iconColor: cs.primary,
                    label: package.durationLabel,
                    sublabel: 'Duration',
                  ),
                  _Divider(),
                  _StatItem(
                    icon: Icons.bookmark_rounded,
                    iconColor: cs.primary,
                    label: '${package.bookingCount}+',
                    sublabel: 'Bookings',
                  ),
                ],
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            sliver: SliverList.list(
              children: [
                // Price + mode
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${package.effectivePrice.toStringAsFixed(0)}',
                              style: tt.headlineMedium?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (package.hasDiscount) ...[
                              const SizedBox(width: 8),
                              Text(
                                '₹${package.price.toStringAsFixed(0)}',
                                style: tt.titleMedium?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red[700],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${package.discountPercent}% OFF',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Pandit info
                if (package.panditName != null &&
                    package.panditName!.isNotEmpty) ...[
                  _SectionHeader('Performed by'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                          package.panditName![0],
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        package.panditName!,
                        style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // Description
                _SectionHeader('About this Package'),
                const SizedBox(height: 8),
                Text(
                  package.description,
                  style: tt.bodyMedium?.copyWith(height: 1.6),
                ),
                const SizedBox(height: 20),

                // What's included
                if (package.includes.isNotEmpty) ...[
                  _SectionHeader('What\'s Included'),
                  const SizedBox(height: 10),
                  ...package.includes.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 18, color: Colors.green[700]),
                          const SizedBox(width: 10),
                          Expanded(
                              child:
                                  Text(item, style: tt.bodyMedium)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Reviews
                _SectionHeader(
                    'Reviews (${package.reviews.length})'),
                const SizedBox(height: 10),
                _RatingBreakdown(reviews: package.reviews),
                const SizedBox(height: 16),
                ...package.reviews
                    .map((r) => _ReviewCard(review: r)),
              ],
            ),
          ),
        ],
      ),

      // ── Sticky book button ────────────────────────────────────────
      bottomNavigationBar: _BookBar(package: package),
    );
  }
}

// ── Helpers / sub-widgets ─────────────────────────────────────────────────────

class _HeroBackground extends StatelessWidget {
  const _HeroBackground({required this.package});
  final PackageModel package;

  static const _gradients = {
    PackageCategory.puja: [Color(0xFFFF6B35), Color(0xFFFF8C69)],
    PackageCategory.astrology: [Color(0xFF2D4A8A), Color(0xFF5C7BC4)],
    PackageCategory.vastu: [Color(0xFF1B5E20), Color(0xFF43A047)],
    PackageCategory.havan: [Color(0xFFBF360C), Color(0xFFE64A19)],
    PackageCategory.katha: [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
    PackageCategory.remedies: [Color(0xFF00838F), Color(0xFF4DD0E1)],
    PackageCategory.other: [Color(0xFF37474F), Color(0xFF78909C)],
  };

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[package.category] ??
        _gradients[PackageCategory.other]!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          if (package.imageUrl != null)
            Positioned.fill(
              child: package.imageUrl!.startsWith('assets/')
                  ? Image.asset(
                      package.imageUrl!,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      package.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
            ),
          // Dark scrim for text legibility
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sublabel,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String sublabel;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(label,
                style: tt.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 2),
        Text(sublabel,
            style: tt.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 36, width: 1, color: Colors.grey[300]);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _RatingBreakdown extends StatelessWidget {
  const _RatingBreakdown({required this.reviews});
  final List<ReviewModel> reviews;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const Text('No reviews yet.');
    final cs = Theme.of(context).colorScheme;

    // Compute bucket counts
    final buckets = List.filled(5, 0);
    for (final r in reviews) {
      final star = (r.rating.clamp(1, 5).round() - 1);
      buckets[star]++;
    }
    final avg =
        reviews.fold(0.0, (s, r) => s + r.rating) / reviews.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Average score
        Column(
          children: [
            Text(
              avg.toStringAsFixed(1),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: cs.primary,
                  ),
            ),
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < avg.round()
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 14,
                  color: Colors.amber[700],
                ),
              ),
            ),
            Text('${reviews.length} reviews',
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        const SizedBox(width: 20),
        // Bars
        Expanded(
          child: Column(
            children: List.generate(5, (i) {
              final idx = 4 - i; // show 5★ first
              final count = buckets[idx];
              final frac =
                  reviews.isEmpty ? 0.0 : count / reviews.length;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text('${idx + 1}',
                        style:
                            const TextStyle(fontSize: 10)),
                    const SizedBox(width: 4),
                    Icon(Icons.star_rounded,
                        size: 10, color: Colors.amber[700]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 7,
                          backgroundColor:
                              cs.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.amber[700]!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('$count',
                        style:
                            const TextStyle(fontSize: 10)),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final ReviewModel review;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      review.avatarColor ?? cs.primaryContainer,
                  child: Text(
                    review.userInitials ?? '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child:
                      Text(review.userName, style: tt.labelLarge),
                ),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < review.rating.round()
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 13,
                      color: Colors.amber[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(review.comment, style: tt.bodySmall),
            const SizedBox(height: 6),
            Text(
              _formatDate(review.createdAt),
              style: tt.labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _BookBar extends StatelessWidget {
  const _BookBar({required this.package});
  final PackageModel package;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Price snapshot
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '₹${package.effectivePrice.toStringAsFixed(0)}',
                style: tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: cs.primary,
                ),
              ),
              if (package.hasDiscount)
                Text(
                  '₹${package.price.toStringAsFixed(0)} MRP',
                  style: tt.labelSmall?.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 20),
          // Book button
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                context.push(Routes.bookingWizard, extra: package);
              },
              icon: const Icon(Icons.calendar_month_rounded),
              label: const Text(
                'Book Now',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
