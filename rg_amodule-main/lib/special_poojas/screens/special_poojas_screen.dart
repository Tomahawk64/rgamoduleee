// lib/special_poojas/screens/special_poojas_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/extensions.dart';
import '../models/special_pooja_model.dart';
import '../providers/special_poojas_provider.dart';

class SpecialPoojasScreen extends ConsumerStatefulWidget {
  const SpecialPoojasScreen({super.key});

  @override
  ConsumerState<SpecialPoojasScreen> createState() => _SpecialPoojasScreenState();
}

class _SpecialPoojasScreenState extends ConsumerState<SpecialPoojasScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poojas = ref.watch(paginatedSpecialPoojasProvider);
    final hasMore = ref.watch(hasMoreSpecialPoojasProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Gradient App Bar ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.secondary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.secondary,
                      AppColors.secondary.withValues(alpha: 0.7),
                      AppColors.primary.withValues(alpha: 0.5),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome,
                                color: Colors.amber, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Special Poojas',
                              style: context.theme.textTheme.headlineSmall
                                  ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sacred rituals at divine temples',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              title: const Text(
                'Special Poojas',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              collapseMode: CollapseMode.parallax,
            ),
          ),

          // ── Search Bar ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) =>
                    ref.read(specialPoojasFilterProvider.notifier).setSearch(v),
                decoration: InputDecoration(
                  hintText: 'Search poojas, temples, cities…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(specialPoojasFilterProvider.notifier)
                                .setSearch('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          // ── Stats bar ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  _StatPill(
                    icon: Icons.temple_hindu,
                    label: '${poojas.length} Rituals',
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 8),
                  _StatPill(
                    icon: Icons.location_on,
                    label: 'Pan-India',
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _StatPill(
                    icon: Icons.verified,
                    label: 'Vedic Certified',
                    color: Colors.green,
                  ),
                ],
              ),
            ),
          ),

          // ── Pooja list ───────────────────────────────────────────────────
          if (poojas.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No special poojas found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: poojas.length,
              itemBuilder: (ctx, i) => _SpecialPoojaCard(pooja: poojas[i]),
            ),

          // ── Load more ────────────────────────────────────────────────────
          if (hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton(
                  onPressed: () => ref
                      .read(specialPoojasPageProvider.notifier)
                      .state++,
                  child: const Text('Load More'),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// ── Stat pill ─────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Special Pooja Card ────────────────────────────────────────────────────────

class _SpecialPoojaCard extends StatelessWidget {
  const _SpecialPoojaCard({required this.pooja});

  final SpecialPoojaModel pooja;

  static const _gradients = [
    [Color(0xFF667EEA), Color(0xFF764BA2)],
    [Color(0xFFFF6B35), Color(0xFFEE4B2B)],
    [Color(0xFF2D4A8A), Color(0xFF1a237e)],
    [Color(0xFF43a047), Color(0xFF1b5e20)],
    [Color(0xFFd4a017), Color(0xFF7B3F00)],
  ];

  List<Color> get _gradient {
    final idx = pooja.id.hashCode.abs() % _gradients.length;
    return _gradients[idx];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: InkWell(
        onTap: () => context.go('/special/${pooja.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Gradient banner ───────────────────────────────────────
              Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Stack(
                  children: [
                    if ((pooja.imageUrl ?? '').trim().isNotEmpty)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: pooja.imageUrl!.startsWith('assets/')
                              ? Image.asset(
                                  pooja.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.temple_hindu,
                                      color: Colors.white70,
                                      size: 42,
                                    ),
                                  ),
                                )
                              : Image.network(
                                  pooja.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.temple_hindu,
                                      color: Colors.white70,
                                      size: 42,
                                    ),
                                  ),
                                ),
                        ),
                      )
                    else
                      Positioned(
                        right: -20,
                        top: -20,
                        child: Opacity(
                          opacity: 0.15,
                          child: Icon(
                            Icons.temple_hindu,
                            size: 100,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (pooja.templeName != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                pooja.templeName!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Content ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pooja.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pooja.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Location + duration row
                    Row(
                      children: [
                        if (pooja.location != null) ...[
                          const Icon(Icons.location_on,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              pooja.location!.shortAddress,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else
                          const Expanded(child: SizedBox()),
                        const Icon(Icons.schedule, size: 14, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text(
                          pooja.durationLabel,
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Highlights chips
                    if (pooja.highlights.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: pooja.highlights
                            .take(3)
                            .map(
                              (h) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  h,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),

                    const SizedBox(height: 12),

                    // Price + Book CTA
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Starting from',
                              style:
                                  TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                            Text(
                              pooja.priceLabel,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => context.go('/special/${pooja.id}'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Book Now'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

