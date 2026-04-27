// lib/shop/providers/cart_provider_v2.dart
// Enhanced cart provider with database persistence

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/demo_config.dart';
import '../../core/providers/supabase_provider.dart';
import '../models/cart_item.dart';
import '../repository/cart_repository.dart';

// ── Repository Provider ────────────────────────────────────────────────────────

final cartRepositoryProvider = Provider<ICartRepository>((ref) {
  if (DemoConfig.demoMode) return MockCartRepository();
  return SupabaseCartRepository(ref.watch(supabaseClientProvider));
});

// ── Cart State ─────────────────────────────────────────────────────────────────

class CartState {
  const CartState({
    this.summary = const CartSummary(
      items: [],
      subtotalPaise: 0,
      taxPaise: 0,
      totalPaise: 0,
    ),
    this.loading = false,
    this.error,
    this.isSaved = true,
  });

  final CartSummary summary;
  final bool loading;
  final String? error;
  final bool isSaved; // Indicates if cart is synced with database

  bool get isEmpty => summary.isEmpty;

  CartState copyWith({
    CartSummary? summary,
    bool? loading,
    String? error,
    bool? isSaved,
    bool clearError = false,
  }) =>
      CartState(
        summary: summary ?? this.summary,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        isSaved: isSaved ?? this.isSaved,
      );
}

// ── Cart Controller ───────────────────────────────────────────────────────────

class CartControllerV2 extends StateNotifier<CartState> {
  CartControllerV2(this._repo, this._supabase) : super(const CartState()) {
    _loadCartFromDatabase();
  }

  final ICartRepository _repo;
  final SupabaseClient _supabase;

  /// Load cart from database on initialization
  Future<void> _loadCartFromDatabase() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      state = state.copyWith(loading: true);
      final savedCart = await _repo.loadCart(userId);

      state = state.copyWith(
        summary: savedCart,
        loading: false,
        isSaved: true,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Failed to load cart: $e',
      );
    }
  }

  /// Add item to cart and mark as unsaved
  void addItem(CartItem item) {
    final existingIndex = state.summary.items.indexWhere(
      (i) => i.product.id == item.product.id,
    );

    List<CartItem> updatedItems;
    if (existingIndex >= 0) {
      // Item already in cart, increase quantity
      updatedItems = List.from(state.summary.items);
      updatedItems[existingIndex] =
          updatedItems[existingIndex].copyWith(
            quantity: updatedItems[existingIndex].quantity + item.quantity,
          );
    } else {
      // New item
      updatedItems = [...state.summary.items, item];
    }

    final newSummary = CartSummary.from(updatedItems);
    state = state.copyWith(
      summary: newSummary,
      isSaved: false, // Mark as unsaved
    );
  }

  /// Update item quantity
  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }

    final updatedItems = state.summary.items.map((item) {
      if (item.product.id == productId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    final newSummary = CartSummary.from(updatedItems);
    state = state.copyWith(
      summary: newSummary,
      isSaved: false,
    );
  }

  /// Remove item from cart
  void removeItem(String productId) {
    final updatedItems =
        state.summary.items.where((item) => item.product.id != productId).toList();

    final newSummary = CartSummary.from(updatedItems);
    state = state.copyWith(
      summary: newSummary,
      isSaved: false,
    );
  }

  /// Persist cart to database
  Future<bool> saveCartToDB() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        state = state.copyWith(error: 'Not authenticated');
        return false;
      }

      state = state.copyWith(loading: true, error: null);
      await _repo.saveCart(userId, state.summary);

      state = state.copyWith(
        loading: false,
        isSaved: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Failed to save cart: $e',
      );
      return false;
    }
  }

  /// Clear cart
  Future<void> clearCart() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _repo.clearCart(userId);
      }

      state = const CartState(isSaved: true);
    } catch (e) {
      state = state.copyWith(error: 'Failed to clear cart: $e');
    }
  }

  /// Create order from cart
  Future<String?> createOrderFromCart() async {
    try {
      if (state.summary.isEmpty) {
        state = state.copyWith(error: 'Cart is empty');
        return null;
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        state = state.copyWith(error: 'Not authenticated');
        return null;
      }

      state = state.copyWith(loading: true);

      // Prepare items for order
      final items = state.summary.items
          .map((item) => {
                'product_id': item.product.id,
                'name': item.product.name,
                'category': item.product.category.name,
                'price_paise': item.product.pricePaise,
                'quantity': item.quantity,
                'total_paise': item.totalPaise,
              })
          .toList();

      // Create order in database
      final response = await _supabase.from('orders').insert({
        'user_id': userId,
        'items': items,
        'subtotal_paise': state.summary.subtotalPaise,
        'tax_paise': state.summary.taxPaise,
        'total_paise': state.summary.totalPaise,
        'status': 'pending',
        'payment_status': 'pending',
      }).select().single();

      final orderId = response['id'] as String;

      // Clear cart after successful order creation
      await _repo.clearCart(userId);

      state = state.copyWith(
        loading: false,
        summary: CartSummary.from([]),
        isSaved: true,
      );

      return orderId;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Failed to create order: $e',
      );
      return null;
    }
  }
}

// ── Riverpod Providers ─────────────────────────────────────────────────────────

final cartProviderV2 = StateNotifierProvider<CartControllerV2, CartState>(
  (ref) => CartControllerV2(
    ref.watch(cartRepositoryProvider),
    ref.watch(supabaseClientProvider),
  ),
);

/// Convenience: pre-computed cart item count
final cartItemCountProviderV2 = Provider<int>(
  (ref) => ref.watch(cartProviderV2).summary.itemCount,
);

/// Convenience: pre-computed cart summary
final cartSummaryProviderV2 = Provider<CartSummary>(
  (ref) => ref.watch(cartProviderV2).summary,
);

/// Indicates if cart is synced with database
final cartSyncStatusProviderV2 = Provider<bool>(
  (ref) => ref.watch(cartProviderV2).isSaved,
);
