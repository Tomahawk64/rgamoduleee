// lib/packages/repository/supabase_package_repository.dart
// Production Supabase implementation for packages

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/package_filter.dart';
import '../models/package_model.dart';

/// Thrown when [fetchPackageById] cannot find the requested package
/// (PGRST116 — 0 rows returned by .single()).
class PackageNotFoundException implements Exception {
  const PackageNotFoundException(this.id);
  final String id;
  @override
  String toString() => 'PackageNotFoundException: no package with id $id';
}

abstract class IPackageRepository {
  Future<List<PackageModel>> fetchPackages({
    PackageFilter? filter,
    int page,
    int pageSize,
  });

  /// Throws [PackageNotFoundException] if the package does not exist.
  Future<PackageModel> fetchPackageById(String id);

  Future<List<PackageModel>> fetchFeaturedPackages({int limit});
}

class SupabasePackageRepository implements IPackageRepository {
  SupabasePackageRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'packages';

  static PackageModel _fromRow(Map<String, dynamic> row) {
    return PackageModel(
      id: row['id'] as String,
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      price: (row['price'] as num).toDouble(),
      discountPrice: (row['discount_price'] as num?)?.toDouble(),
      durationMinutes: row['duration_minutes'] as int? ?? 60,
      mode: _parseMode(row),
      category: PackageCategory.values.firstWhere(
        (c) => c.name == (row['category'] as String? ?? 'puja'),
        orElse: () => PackageCategory.puja,
      ),
      includes: List<String>.from(row['includes'] as List? ?? []),
      reviews: const [],
      rating: (row['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: row['review_count'] as int? ?? 0,
      bookingCount: row['booking_count'] as int? ?? 0,
      isActive: row['is_active'] as bool? ?? true,
      isPopular: row['is_popular'] as bool? ?? false,
      isFeatured: row['is_featured'] as bool? ?? false,
      imageUrl: row['image_url'] as String?,
    );
  }

  static PackageMode _parseMode(Map<String, dynamic> row) {
    final online = row['is_online'] as bool? ?? false;
    final offline = row['is_offline'] as bool? ?? true;
    if (online && offline) return PackageMode.both;
    if (online) return PackageMode.online;
    return PackageMode.offline;
  }

  @override
  Future<List<PackageModel>> fetchPackages({
    PackageFilter? filter,
    int page = 0,
    int pageSize = 20,
  }) async {
    var query = _client
        .from(_table)
        .select()
        .eq('is_active', true);

    // Apply filters
    if (filter != null) {
      if (filter.category != null) {
        query = query.eq('category', filter.category!.name);
      }
      if (filter.mode != null) {
        switch (filter.mode!) {
          case PackageMode.online:
            query = query.eq('is_online', true);
          case PackageMode.offline:
            query = query.eq('is_offline', true);
          case PackageMode.both:
            query = query.eq('is_online', true).eq('is_offline', true);
        }
      }
      if (filter.minPrice != null) {
        query = query.gte('price', filter.minPrice!);
      }
      if (filter.maxPrice != null) {
        query = query.lte('price', filter.maxPrice!);
      }
    }

    // Sort + paginate (returns PostgrestTransformBuilder so done last)
    final sort = filter?.sort ?? PackageSort.popularity;
    final sortCol = switch (sort) {
      PackageSort.popularity => 'booking_count',
      PackageSort.priceLow   => 'price',
      PackageSort.priceHigh  => 'price',
      PackageSort.rating     => 'rating',
      PackageSort.newest     => 'created_at',
    };
    final ascending = sort == PackageSort.priceLow;

    final rows = await query
        .order(sortCol, ascending: ascending)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return (rows as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PackageModel> fetchPackageById(String id) async {
    try {
      final row = await _client
          .from(_table)
          .select()
          .eq('id', id)
          .single();
      return _fromRow(row);
    } on PostgrestException catch (e) {
      // PGRST116 = "JSON object requested, multiple (or no) rows returned"
      if (e.code == 'PGRST116') throw PackageNotFoundException(id);
      rethrow;
    }
  }

  @override
  Future<List<PackageModel>> fetchFeaturedPackages({int limit = 6}) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('is_active', true)
        .eq('is_featured', true)
        .order('booking_count', ascending: false)
        .limit(limit);

    return (rows as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }
}
