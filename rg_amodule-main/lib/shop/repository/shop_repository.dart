// lib/shop/repository/shop_repository.dart

import '../models/product_model.dart';

// ── Abstract contract ─────────────────────────────────────────────────────────

abstract class IProductRepository {
  /// Returns all products (optionally filtered by category).
  Future<List<ProductModel>> fetchProducts({ProductCategory? category});

  /// Returns a single product by ID, or null if not found.
  Future<ProductModel?> fetchProduct(String id);
}

// ── Mock implementation ───────────────────────────────────────────────────────

class MockProductRepository implements IProductRepository {
  @override
  Future<List<ProductModel>> fetchProducts({ProductCategory? category}) async {
    // Simulate network latency
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (category == null || category == ProductCategory.all) {
      return List.unmodifiable(kMockProducts);
    }
    return List.unmodifiable(
      kMockProducts.where((p) => p.category == category).toList(),
    );
  }

  @override
  Future<ProductModel?> fetchProduct(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    try {
      return kMockProducts.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
