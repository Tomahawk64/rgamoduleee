// lib/shop/providers/shop_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/demo_config.dart';
import '../../core/providers/supabase_provider.dart';
import '../controllers/shop_controller.dart';
import '../models/product_model.dart';
import '../repository/shop_repository.dart';
import '../repository/supabase_shop_repository.dart';

// ── Repository ────────────────────────────────────────────────────────────────

/// Uses [MockProductRepository] in demo mode, Supabase otherwise.
final productRepositoryProvider = Provider<IProductRepository>((ref) {
  if (DemoConfig.demoMode) return MockProductRepository();
  return SupabaseShopRepository(ref.watch(supabaseClientProvider));
});

// ── Shop (product listing) ────────────────────────────────────────────────────

final shopProvider = StateNotifierProvider<ShopController, ShopState>(
  (ref) => ShopController(ref.watch(productRepositoryProvider)),
);

/// Convenience: pre-filtered product list.
final filteredProductsProvider = Provider<List<ProductModel>>(
  (ref) => ref.watch(shopProvider).filteredProducts,
);

// ── Order ─────────────────────────────────────────────────────────────────────

final orderProvider = StateNotifierProvider<OrderController, OrderState>(
  (ref) => OrderController(),
);
