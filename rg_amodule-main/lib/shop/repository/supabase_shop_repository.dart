// lib/shop/repository/supabase_shop_repository.dart
// Production Supabase implementation of IProductRepository.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_model.dart';
import 'shop_repository.dart';

class SupabaseShopRepository implements IProductRepository {
  const SupabaseShopRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'products';

  static ProductModel _fromRow(Map<String, dynamic> row) {
    final cat = ProductCategory.values.firstWhere(
      (c) => c.name == (row['category'] as String? ?? 'all'),
      orElse: () => ProductCategory.all,
    );
    return ProductModel(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String? ?? '',
      pricePaise: row['price_paise'] as int? ?? 0,
      category: cat,
      rating: (row['rating'] as num?)?.toDouble() ?? 4.0,
      reviewCount: row['review_count'] as int? ?? 0,
      stock: row['stock'] as int? ?? 0,
      includes: List<String>.from(row['includes'] as List? ?? []),
      isBestSeller: row['is_best_seller'] as bool? ?? false,
    );
  }

  @override
  Future<List<ProductModel>> fetchProducts({ProductCategory? category}) async {
    try {
      var query = _client.from(_table).select().eq('is_active', true);

      if (category != null && category != ProductCategory.all) {
        query = query.eq('category', category.name);
      }

      final rows = await query.order('is_best_seller',
          ascending: false);

      return (rows as List).map((r) => _fromRow(r as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch products: ${e.message}');
    }
  }

  @override
  Future<ProductModel?> fetchProduct(String id) async {
    try {
      final row = await _client
          .from(_table)
          .select()
          .eq('id', id)
          .single();
      return _fromRow(row);
    } on PostgrestException {
      return null;
    }
  }
}
