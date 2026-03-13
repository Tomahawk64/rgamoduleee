import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/package_filter.dart';
import '../providers/packages_provider.dart';
import '../widgets/package_filter_sheet.dart';
import '../widgets/package_list_card.dart';

class PackagesScreen extends ConsumerWidget {
  const PackagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(packageFilterProvider);
    final packages = ref.watch(paginatedPackagesProvider);
    final hasMore = ref.watch(hasMorePackagesProvider);
    final total = ref.watch(filteredPackagesProvider).length;
    final activeFilters = filter.activeFilterCount;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App bar ───────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            floating: true,
            title: const Text(
              'Puja Packages',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _SearchBar(
                  initial: filter.searchQuery,
                  onChanged: (q) {
                    ref.read(packageFilterProvider.notifier).setSearch(q);
                    ref.read(packagePageProvider.notifier).state =
                        kPackagePageSize;
                  },
                ),
              ),
            ),
          ),

          // ── Filter row ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _FilterRow(
              filter: filter,
              activeCount: activeFilters,
              total: total,
              onOpenFilter: () => showPackageFilterSheet(context),
              onClearFilter: () {
                ref.read(packageFilterProvider.notifier).reset();
                ref.read(packagePageProvider.notifier).state =
                    kPackagePageSize;
              },
              onSortChanged: (sort) {
                ref.read(packageFilterProvider.notifier).setSort(sort);
              },
            ),
          ),

          // ── Package list ──────────────────────────────────────────
          packages.isEmpty
              ? const SliverFillRemaining(child: _EmptyState())
              : SliverList.builder(
                  itemCount: packages.length + (hasMore ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i == packages.length) {
                      return _LoadMoreButton(
                        onTap: () {
                          ref.read(packagePageProvider.notifier).state +=
                              kPackagePageSize;
                        },
                      );
                    }
                    final pkg = packages[i];
                    return PackageListCard(
                      package: pkg,
                      onTap: () => context.push('/packages/${pkg.id}'),
                      onBook: () => context.push('/packages/${pkg.id}'),
                    );
                  },
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.initial, required this.onChanged});
  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: 'Search puja, havan, astrology…',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _ctrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _ctrl.clear();
                  widget.onChanged('');
                },
              )
            : null,
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filter,
    required this.activeCount,
    required this.total,
    required this.onOpenFilter,
    required this.onClearFilter,
    required this.onSortChanged,
  });

  final PackageFilter filter;
  final int activeCount;
  final int total;
  final VoidCallback onOpenFilter;
  final VoidCallback onClearFilter;
  final ValueChanged<PackageSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Text(
            '$total results',
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const Spacer(),
          if (activeCount > 0) ...[
            ActionChip(
              avatar: const Icon(Icons.close_rounded, size: 14),
              label: Text('Clear ($activeCount)'),
              onPressed: onClearFilter,
              backgroundColor: cs.errorContainer,
              labelStyle: TextStyle(color: cs.onErrorContainer),
            ),
            const SizedBox(width: 8),
          ],
          Badge(
            isLabelVisible: activeCount > 0,
            label: Text('$activeCount'),
            child: FilledButton.tonalIcon(
              onPressed: onOpenFilter,
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text('Filter'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Load more',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 64, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('No packages found',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Try adjusting your filters',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
