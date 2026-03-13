// lib/shop/models/cart_item.dart

import 'product_model.dart';

class CartItem {
  CartItem({required this.product, this.quantity = 1})
      : assert(quantity > 0, 'quantity must be > 0');

  final ProductModel product;
  int quantity;

  int get totalPaise => product.pricePaise * quantity;

  String get formattedTotal {
    final rupees = totalPaise ~/ 100;
    final str = rupees.toString();
    if (str.length > 3) {
      final pre = str.substring(0, str.length - 3);
      final post = str.substring(str.length - 3);
      return '₹$pre,$post';
    }
    return '₹$str';
  }

  CartItem copyWith({int? quantity}) =>
      CartItem(product: product, quantity: quantity ?? this.quantity);
}

// ── Cart Summary ──────────────────────────────────────────────────────────────

class CartSummary {
  const CartSummary({
    required this.items,
    required this.subtotalPaise,
    required this.taxPaise,
    required this.totalPaise,
  });

  final List<CartItem> items;
  final int subtotalPaise;

  /// GST @ 5 %
  final int taxPaise;
  final int totalPaise;

  int get itemCount => items.fold(0, (sum, e) => sum + e.quantity);
  bool get isEmpty => items.isEmpty;

  String get formattedSubtotal => _fmt(subtotalPaise);
  String get formattedTax => _fmt(taxPaise);
  String get formattedTotal => _fmt(totalPaise);

  static String _fmt(int paise) {
    final rupees = paise ~/ 100;
    final str = rupees.toString();
    if (str.length > 3) {
      final pre = str.substring(0, str.length - 3);
      final post = str.substring(str.length - 3);
      return '₹$pre,$post';
    }
    return '₹$str';
  }

  static CartSummary from(List<CartItem> items) {
    final subtotal = items.fold<int>(0, (s, e) => s + e.totalPaise);
    final tax = (subtotal * 0.05).round();
    return CartSummary(
      items: items,
      subtotalPaise: subtotal,
      taxPaise: tax,
      totalPaise: subtotal + tax,
    );
  }
}
