import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/demo_config.dart';
import '../../core/providers/supabase_provider.dart';
import '../models/package_filter.dart';
import '../models/package_mock_data.dart';
import '../models/package_model.dart';
import '../repository/supabase_package_repository.dart';

// ── Page size ─────────────────────────────────────────────────────────────────
const kPackagePageSize = 5;

// ── Mock Package Repository (for demo mode) ──────────────────────────────────

class _MockPackageRepository implements IPackageRepository {
  @override
  Future<List<PackageModel>> fetchPackages({
    PackageFilter? filter,
    int page = 0,
    int pageSize = kPackagePageSize,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return kMockPackageList;
  }

  @override
  Future<PackageModel> fetchPackageById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return kMockPackageList.firstWhere((p) => p.id == id);
  }

  @override
  Future<List<PackageModel>> fetchFeaturedPackages({int limit = 6}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return kMockPackageList.where((p) => p.isFeatured || p.isPopular).take(limit).toList();
  }
}

// ── Repository Provider ───────────────────────────────────────────────────────

/// Uses mock in demo mode, Supabase otherwise.
final packageRepositoryProvider = Provider<IPackageRepository>((ref) {
  if (DemoConfig.demoMode) return _MockPackageRepository();
  return SupabasePackageRepository(ref.watch(supabaseClientProvider));
});

// ── Supabase async packages fetch ─────────────────────────────────────────────

/// Async fetch for the full active package catalogue.
final packagesFetchProvider =
    FutureProvider.autoDispose<List<PackageModel>>((ref) async {
  final repo = ref.watch(packageRepositoryProvider);
  return repo.fetchPackages(
    filter: const PackageFilter(),
    page: 0,
    pageSize: 200,
  );
});

/// Synchronous list accessor used by UI filters.
/// In production this never falls back to mock data.
final allPackagesProvider = Provider<List<PackageModel>>((ref) {
  if (DemoConfig.demoMode) return kMockPackageList;
  final async = ref.watch(packagesFetchProvider);
  return async.maybeWhen(data: (list) => list, orElse: () => const []);
});

/// Featured packages for home screen carousel.
final featuredPackagesProvider =
    FutureProvider.autoDispose<List<PackageModel>>((ref) async {
  final repo = ref.watch(packageRepositoryProvider);
  return repo.fetchFeaturedPackages(limit: 6);
});

// ── Filter state ──────────────────────────────────────────────────────────────
final packageFilterProvider =
    StateNotifierProvider<PackageFilterNotifier, PackageFilter>(
  (_) => PackageFilterNotifier(),
);

class PackageFilterNotifier extends StateNotifier<PackageFilter> {
  PackageFilterNotifier() : super(const PackageFilter());

  void update(PackageFilter filter) => state = filter;
  void reset() => state = const PackageFilter();

  void setSearch(String q) =>
      state = state.copyWith(searchQuery: q);

  void setCategory(PackageCategory? c) =>
      state = state.copyWith(category: c);

  void setMode(PackageMode? m) =>
      state = state.copyWith(mode: m);

  void setPriceRange(double? min, double? max) =>
      state = state.copyWith(minPrice: min, maxPrice: max);

  void setDurationRange(int? min, int? max) =>
      state = state.copyWith(minDuration: min, maxDuration: max);

  void setSort(PackageSort sort) =>
      state = state.copyWith(sort: sort);
}

// ── Filtered + sorted list ────────────────────────────────────────────────────
/// Returns the full filtered list from the active data source.
final filteredPackagesProvider = Provider<List<PackageModel>>((ref) {
  final filter = ref.watch(packageFilterProvider);
  var list = List<PackageModel>.from(ref.watch(allPackagesProvider));

  // Search
  if (filter.searchQuery.isNotEmpty) {
    final q = filter.searchQuery.toLowerCase();
    list = list.where((p) =>
        p.title.toLowerCase().contains(q) ||
        p.description.toLowerCase().contains(q) ||
        (p.panditName?.toLowerCase().contains(q) ?? false)).toList();
  }

  // Category
  if (filter.category != null) {
    list = list.where((p) => p.category == filter.category).toList();
  }

  // Mode
  if (filter.mode != null) {
    list = list.where((p) {
      if (filter.mode == PackageMode.online) {
        return p.mode == PackageMode.online || p.mode == PackageMode.both;
      }
      if (filter.mode == PackageMode.offline) {
        return p.mode == PackageMode.offline || p.mode == PackageMode.both;
      }
      return true;
    }).toList();
  }

  // Price range
  if (filter.minPrice != null) {
    list = list.where((p) => p.effectivePrice >= filter.minPrice!).toList();
  }
  if (filter.maxPrice != null) {
    list = list.where((p) => p.effectivePrice <= filter.maxPrice!).toList();
  }

  // Duration range
  if (filter.minDuration != null) {
    list = list.where((p) => p.durationMinutes >= filter.minDuration!).toList();
  }
  if (filter.maxDuration != null) {
    list = list.where((p) => p.durationMinutes <= filter.maxDuration!).toList();
  }

  // Sort
  switch (filter.sort) {
    case PackageSort.popularity:
      list.sort((a, b) => b.bookingCount.compareTo(a.bookingCount));
    case PackageSort.priceLow:
      list.sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
    case PackageSort.priceHigh:
      list.sort((a, b) => b.effectivePrice.compareTo(a.effectivePrice));
    case PackageSort.rating:
      list.sort((a, b) => b.rating.compareTo(a.rating));
    case PackageSort.newest:
      list.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  }

  return list;
});

// ── Pagination provider ───────────────────────────────────────────────────────
/// Tracks how many items are currently visible (for load-more pagination).
final packagePageProvider = StateProvider<int>((_) => kPackagePageSize);

/// The currently visible page slice.
final paginatedPackagesProvider = Provider<List<PackageModel>>((ref) {
  final all  = ref.watch(filteredPackagesProvider);
  final page = ref.watch(packagePageProvider);
  return all.take(page).toList();
});

final hasMorePackagesProvider = Provider<bool>((ref) {
  final all  = ref.watch(filteredPackagesProvider).length;
  final page = ref.watch(packagePageProvider);
  return page < all;
});

// ── Single package by id ──────────────────────────────────────────────────────
final packageByIdProvider =
    FutureProvider.family<PackageModel?, String>((ref, id) async {
  if (DemoConfig.demoMode) {
    return kMockPackageList.where((p) => p.id == id).firstOrNull;
  }

  final repo = ref.watch(packageRepositoryProvider);
  try {
    return await repo.fetchPackageById(id);
  } on PackageNotFoundException {
    return null;
  } catch (_) {
    return null;
  }
});
