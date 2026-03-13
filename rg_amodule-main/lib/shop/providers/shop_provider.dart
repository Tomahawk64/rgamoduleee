// lib/shop/providers/shop_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/demo_config.dart';
import '../../core/providers/supabase_provider.dart';
import '../controllers/shop_controller.dart';
import '../models/cart_item.dart';
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

// ── Cart ──────────────────────────────────────────────────────────────────────

/// Single global cart — persists across navigation.
final cartProvider = StateNotifierProvider<CartController, CartState>(
  (ref) => CartController(),
);

/// Total number of line items (sum of quantities).
final cartItemCountProvider = Provider<int>(
  (ref) => ref.watch(cartProvider).summary.itemCount,
);

/// Cart summary (subtotal, tax, total).
final cartSummaryProvider = Provider<CartSummary>(
  (ref) => ref.watch(cartProvider).summary,
);

// ── Order ─────────────────────────────────────────────────────────────────────

final orderProvider = StateNotifierProvider<OrderController, OrderState>(
  (ref) => OrderController(),
);
