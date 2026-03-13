// lib/special_poojas/providers/special_poojas_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../models/special_pooja_model.dart';

// ── Pagination params ─────────────────────────────────────────────────────────

class SpecialPoojasParams {
  const SpecialPoojasParams({this.page = 0, this.pageSize = 10});
  final int page;
  final int pageSize;
}

// ── Search / filter state ─────────────────────────────────────────────────────

class SpecialPoojasFilter {
  const SpecialPoojasFilter({this.searchQuery = '', this.cityFilter = ''});
  final String searchQuery;
  final String cityFilter;

  SpecialPoojasFilter copyWith({String? searchQuery, String? cityFilter}) =>
      SpecialPoojasFilter(
        searchQuery: searchQuery ?? this.searchQuery,
        cityFilter: cityFilter ?? this.cityFilter,
      );
}

class SpecialPoojasFilterNotifier extends StateNotifier<SpecialPoojasFilter> {
  SpecialPoojasFilterNotifier() : super(const SpecialPoojasFilter());

  void setSearch(String q) => state = state.copyWith(searchQuery: q);
  void setCity(String c) => state = state.copyWith(cityFilter: c);
  void reset() => state = const SpecialPoojasFilter();
}

final specialPoojasFilterProvider =
    StateNotifierProvider<SpecialPoojasFilterNotifier, SpecialPoojasFilter>(
  (ref) => SpecialPoojasFilterNotifier(),
);

// ── Master list provider (Supabase with mock fallback) ───────────────────────

final _supabaseSpecialPoojasProvider =
    FutureProvider<List<SpecialPoojaModel>>((ref) async {
  try {
    final client = ref.watch(supabaseClientProvider);
    final data = await client
        .from('special_poojas')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false);
    if (data.isEmpty) return kMockSpecialPoojas;
    return (data as List)
        .map((j) => SpecialPoojaModel.fromJson(j as Map<String, dynamic>))
        .toList();
  } catch (_) {
    // Graceful fallback to mock data when Supabase is unreachable or
    // the table has no rows yet.
    return kMockSpecialPoojas;
  }
});

/// Synchronous accessor used by all downstream providers.
/// Returns data when loaded, mock data while loading or on error.
final allSpecialPoojasProvider = Provider<List<SpecialPoojaModel>>((ref) {
  final async = ref.watch(_supabaseSpecialPoojasProvider);
  return async.when(
    data: (list) => list,
    loading: () => kMockSpecialPoojas,
    error: (_, _) => kMockSpecialPoojas,
  );
});

// ── Filtered list ─────────────────────────────────────────────────────────────

final filteredSpecialPoojasProvider = Provider<List<SpecialPoojaModel>>((ref) {
  final all = ref.watch(allSpecialPoojasProvider);
  final filter = ref.watch(specialPoojasFilterProvider);

  return all.where((p) {
    final q = filter.searchQuery.toLowerCase();
    final cityMatch = filter.cityFilter.isEmpty ||
        (p.location?.city.toLowerCase().contains(
                  filter.cityFilter.toLowerCase(),
                ) ??
            false);
    final searchMatch = q.isEmpty ||
        p.title.toLowerCase().contains(q) ||
        (p.description.toLowerCase().contains(q)) ||
        (p.templeName?.toLowerCase().contains(q) ?? false);
    return searchMatch && cityMatch && p.isActive;
  }).toList();
});

// ── Paginated ─────────────────────────────────────────────────────────────────

final specialPoojasPageProvider = StateProvider<int>((ref) => 0);

final paginatedSpecialPoojasProvider = Provider<List<SpecialPoojaModel>>((ref) {
  const pageSize = 10;
  final page = ref.watch(specialPoojasPageProvider);
  final filtered = ref.watch(filteredSpecialPoojasProvider);
  final end = ((page + 1) * pageSize).clamp(0, filtered.length);
  return filtered.sublist(0, end);
});

final hasMoreSpecialPoojasProvider = Provider<bool>((ref) {
  const pageSize = 10;
  final page = ref.watch(specialPoojasPageProvider);
  final filtered = ref.watch(filteredSpecialPoojasProvider);
  return filtered.length > (page + 1) * pageSize;
});

// ── By-id lookup ─────────────────────────────────────────────────────────────

final specialPoojaByIdProvider =
    Provider.family<SpecialPoojaModel?, String>((ref, id) {
  final all = ref.watch(allSpecialPoojasProvider);
  try {
    return all.firstWhere((p) => p.id == id);
  } catch (_) {
    return null;
  }
});
