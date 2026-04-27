// lib/shop/repository/cart_repository.dart
// Manages persistent cart storage in Supabase

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart_item.dart';
import '../models/product_model.dart';

abstract class ICartRepository {
  /// Load user's cart from database
  Future<CartSummary> loadCart(String userId);

  /// Save cart to database
  Future<void> saveCart(String userId, CartSummary cart);

  /// Clear user's cart
  Future<void> clearCart(String userId);

  /// Get cart item count
  Future<int> getCartItemCount(String userId);
}

class SupabaseCartRepository implements ICartRepository {
  SupabaseCartRepository(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<CartSummary> loadCart(String userId) async {
    try {
      final response = await _supabase
          .from('shopping_carts')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return CartSummary.from([]);
      }

      // Parse items from JSONB
      final items = (response['items'] as List<dynamic>?)?.map((item) {
        final product = ProductModel.fromJson(item['product'] as Map<String, dynamic>);
        return CartItem(
          product: product,
          quantity: item['quantity'] as int,
        );
      }).toList() ?? [];

      return CartSummary.from(items);
    } catch (e) {
      print('Error loading cart: $e');
      return CartSummary.from([]);
    }
  }

  @override
  Future<void> saveCart(String userId, CartSummary cart) async {
    try {
      // Prepare items for JSONB storage
      final items = cart.items.map((item) {
        return {
          'product': item.product.toJson(),
          'quantity': item.quantity,
        };
      }).toList();

      // Check if cart exists for this user
      final existing = await _supabase
          .from('shopping_carts')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        // Insert new cart
        await _supabase.from('shopping_carts').insert({
          'user_id': userId,
          'items': items,
          'subtotal_paise': cart.subtotalPaise,
          'tax_paise': cart.taxPaise,
          'total_paise': cart.totalPaise,
        });
      } else {
        // Update existing cart
        await _supabase
            .from('shopping_carts')
            .update({
              'items': items,
              'subtotal_paise': cart.subtotalPaise,
              'tax_paise': cart.taxPaise,
              'total_paise': cart.totalPaise,
            })
            .eq('user_id', userId);
      }
    } catch (e) {
      print('Error saving cart: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearCart(String userId) async {
    try {
      await _supabase
          .from('shopping_carts')
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      print('Error clearing cart: $e');
      rethrow;
    }
  }

  @override
  Future<int> getCartItemCount(String userId) async {
    try {
      final response = await _supabase
          .from('shopping_carts')
          .select('items')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return 0;

      final items = response['items'] as List<dynamic>?;
      if (items == null) return 0;

      return items.fold<int>(0, (sum, item) => sum + (item['quantity'] as int? ?? 0));
    } catch (e) {
      print('Error getting cart count: $e');
      return 0;
    }
  }
}

/// Mock implementation for testing
class MockCartRepository implements ICartRepository {
  final Map<String, CartSummary> _carts = {};

  @override
  Future<CartSummary> loadCart(String userId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _carts[userId] ?? CartSummary.from([]);
  }

  @override
  Future<void> saveCart(String userId, CartSummary cart) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _carts[userId] = cart;
  }

  @override
  Future<void> clearCart(String userId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _carts.remove(userId);
  }

  @override
  Future<int> getCartItemCount(String userId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _carts[userId]?.itemCount ?? 0;
  }
}
