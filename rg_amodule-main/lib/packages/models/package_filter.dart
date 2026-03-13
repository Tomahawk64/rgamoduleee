import 'package_model.dart';

/// Immutable filter + sort state for the packages list.
class PackageFilter {
  const PackageFilter({
    this.category,
    this.mode,
    this.minPrice,
    this.maxPrice,
    this.minDuration,
    this.maxDuration,
    this.sort = PackageSort.popularity,
    this.searchQuery = '',
  });

  final PackageCategory? category;
  final PackageMode? mode;
  final double? minPrice;
  final double? maxPrice;
  final int? minDuration;   // minutes
  final int? maxDuration;   // minutes
  final PackageSort sort;
  final String searchQuery;

  bool get isDefault =>
      category == null &&
      mode == null &&
      minPrice == null &&
      maxPrice == null &&
      minDuration == null &&
      maxDuration == null &&
      sort == PackageSort.popularity &&
      searchQuery.isEmpty;

  int get activeFilterCount {
    int count = 0;
    if (category != null) count++;
    if (mode != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (minDuration != null || maxDuration != null) count++;
    if (sort != PackageSort.popularity) count++;
    return count;
  }

  PackageFilter copyWith({
    Object? category = _sentinel,
    Object? mode = _sentinel,
    Object? minPrice = _sentinel,
    Object? maxPrice = _sentinel,
    Object? minDuration = _sentinel,
    Object? maxDuration = _sentinel,
    PackageSort? sort,
    String? searchQuery,
  }) =>
      PackageFilter(
        category: category == _sentinel
            ? this.category
            : category as PackageCategory?,
        mode:        mode == _sentinel ? this.mode : mode as PackageMode?,
        minPrice:    minPrice == _sentinel ? this.minPrice : minPrice as double?,
        maxPrice:    maxPrice == _sentinel ? this.maxPrice : maxPrice as double?,
        minDuration: minDuration == _sentinel ? this.minDuration : minDuration as int?,
        maxDuration: maxDuration == _sentinel ? this.maxDuration : maxDuration as int?,
        sort:        sort ?? this.sort,
        searchQuery: searchQuery ?? this.searchQuery,
      );

  PackageFilter reset() => const PackageFilter();
}

// Sentinel to distinguish "not provided" from null in copyWith
const _sentinel = Object();

enum PackageSort {
  popularity,
  priceLow,
  priceHigh,
  rating,
  newest,
}

extension PackageSortX on PackageSort {
  String get label {
    switch (this) {
      case PackageSort.popularity: return 'Most Popular';
      case PackageSort.priceLow:   return 'Price: Low to High';
      case PackageSort.priceHigh:  return 'Price: High to Low';
      case PackageSort.rating:     return 'Top Rated';
      case PackageSort.newest:     return 'Newest First';
    }
  }
}
