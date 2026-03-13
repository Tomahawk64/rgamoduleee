import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/package_filter.dart';
import '../models/package_model.dart';
import '../providers/packages_provider.dart';

/// Show the filter bottom-sheet.
Future<void> showPackageFilterSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _FilterSheet(),
  );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late PackageFilter _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(packageFilterProvider);
  }

  void _apply() {
    ref.read(packageFilterProvider.notifier).update(_draft);
    // reset pagination
    ref.read(packagePageProvider.notifier).state = kPackagePageSize;
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() => _draft = const PackageFilter());
    ref.read(packageFilterProvider.notifier).reset();
    ref.read(packagePageProvider.notifier).state = kPackagePageSize;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 10),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withAlpha(80),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),

            // Title bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text('Filters & Sort',
                      style: tt.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable body
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // ── Sort ────────────────────────────────────────────
                  _SectionTitle(label: 'Sort by'),
                  const SizedBox(height: 8),
                  _SortPicker(
                    value: _draft.sort,
                    onChange: (v) =>
                        setState(() => _draft = _draft.copyWith(sort: v)),
                  ),
                  const SizedBox(height: 20),

                  // ── Category ─────────────────────────────────────────
                  _SectionTitle(label: 'Category'),
                  const SizedBox(height: 8),
                  _CategoryPicker(
                    value: _draft.category,
                    onChange: (v) =>
                        setState(() => _draft = _draft.copyWith(category: v)),
                  ),
                  const SizedBox(height: 20),

                  // ── Mode ─────────────────────────────────────────────
                  _SectionTitle(label: 'Mode'),
                  const SizedBox(height: 8),
                  _ModePicker(
                    value: _draft.mode,
                    onChange: (v) =>
                        setState(() => _draft = _draft.copyWith(mode: v)),
                  ),
                  const SizedBox(height: 20),

                  // ── Price range ───────────────────────────────────────
                  _SectionTitle(label: 'Price Range'),
                  const SizedBox(height: 4),
                  _PriceRangePicker(
                    min: _draft.minPrice ?? 0,
                    max: _draft.maxPrice ?? 10000,
                    onChange: (lo, hi) => setState(() {
                      _draft = _draft.copyWith(
                          minPrice: lo == 0 ? null : lo,
                          maxPrice: hi == 10000 ? null : hi);
                    }),
                  ),
                  const SizedBox(height: 20),

                  // ── Duration range ────────────────────────────────────
                  _SectionTitle(label: 'Duration'),
                  const SizedBox(height: 4),
                  _DurationRangePicker(
                    min: _draft.minDuration ?? 0,
                    max: _draft.maxDuration ?? 300,
                    onChange: (lo, hi) => setState(() {
                      _draft = _draft.copyWith(
                          minDuration: lo == 0 ? null : lo,
                          maxDuration: hi == 300 ? null : hi);
                    }),
                  ),
                ],
              ),
            ),

            // ── Apply button ──────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                  onPressed: _apply,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Apply Filters',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _SortPicker extends StatelessWidget {
  const _SortPicker({required this.value, required this.onChange});
  final PackageSort value;
  final ValueChanged<PackageSort> onChange;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: PackageSort.values.map((s) {
        final selected = s == value;
        return ChoiceChip(
          label: Text(s.label),
          selected: selected,
          onSelected: (_) => onChange(s),
          selectedColor: cs.primaryContainer,
          labelStyle: TextStyle(
            color: selected ? cs.onPrimaryContainer : null,
            fontWeight: selected ? FontWeight.w700 : null,
          ),
        );
      }).toList(),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.value, required this.onChange});
  final PackageCategory? value;
  final ValueChanged<PackageCategory?> onChange;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        // 'All' chip
        ChoiceChip(
          label: const Text('All'),
          selected: value == null,
          onSelected: (_) => onChange(null),
          selectedColor: cs.primaryContainer,
          labelStyle: TextStyle(
            color: value == null ? cs.onPrimaryContainer : null,
            fontWeight: value == null ? FontWeight.w700 : null,
          ),
        ),
        ...PackageCategory.values.map((c) {
          final selected = c == value;
          return FilterChip(
            avatar: Icon(c.icon, size: 14),
            label: Text(c.label),
            selected: selected,
            onSelected: (_) => onChange(selected ? null : c),
            selectedColor: cs.primaryContainer,
            labelStyle: TextStyle(
              color: selected ? cs.onPrimaryContainer : null,
              fontWeight: selected ? FontWeight.w700 : null,
            ),
          );
        }),
      ],
    );
  }
}

class _ModePicker extends StatelessWidget {
  const _ModePicker({required this.value, required this.onChange});
  final PackageMode? value;
  final ValueChanged<PackageMode?> onChange;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const modes = [
      (null, 'All', Icons.apps_rounded),
      (PackageMode.online, 'Online', Icons.videocam_rounded),
      (PackageMode.offline, 'On-site', Icons.home_rounded),
      (PackageMode.both, 'Both', Icons.swap_horiz_rounded),
    ];
    return Wrap(
      spacing: 8,
      children: modes.map((m) {
        final selected = m.$1 == value;
        return ChoiceChip(
          avatar: Icon(m.$3, size: 14),
          label: Text(m.$2),
          selected: selected,
          onSelected: (_) => onChange(m.$1),
          selectedColor: cs.primaryContainer,
          labelStyle: TextStyle(
            color: selected ? cs.onPrimaryContainer : null,
            fontWeight: selected ? FontWeight.w700 : null,
          ),
        );
      }).toList(),
    );
  }
}

class _PriceRangePicker extends StatelessWidget {
  const _PriceRangePicker(
      {required this.min, required this.max, required this.onChange});
  final double min;
  final double max;
  final void Function(double, double) onChange;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('₹${min.toInt()}', style: tt.bodySmall),
            Text('₹${max.toInt()}', style: tt.bodySmall),
          ],
        ),
        RangeSlider(
          values: RangeValues(min, max),
          min: 0,
          max: 10000,
          divisions: 100,
          labels: RangeLabels('₹${min.toInt()}', '₹${max.toInt()}'),
          onChanged: (v) => onChange(v.start, v.end),
        ),
      ],
    );
  }
}

class _DurationRangePicker extends StatelessWidget {
  const _DurationRangePicker(
      {required this.min, required this.max, required this.onChange});
  final int min;
  final int max;
  final void Function(int, int) onChange;

  String _label(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '${h}h' : '${h}h ${rem}m';
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_label(min), style: tt.bodySmall),
            Text(_label(max), style: tt.bodySmall),
          ],
        ),
        RangeSlider(
          values: RangeValues(min.toDouble(), max.toDouble()),
          min: 0,
          max: 300,
          divisions: 30,
          labels: RangeLabels(_label(min), _label(max)),
          onChanged: (v) =>
              onChange(v.start.round(), v.end.round()),
        ),
      ],
    );
  }
}
