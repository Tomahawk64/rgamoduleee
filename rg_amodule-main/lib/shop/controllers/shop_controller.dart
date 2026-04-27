// lib/shop/controllers/shop_controller.dart



import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';



import '../models/cart_item.dart';

import '../models/product_model.dart';

import '../repository/shop_repository.dart';



// ── Shop / Product Listing ────────────────────────────────────────────────────



class ShopState {

  const ShopState({

    this.allProducts = const [],

    this.selectedCategory = ProductCategory.all,

    this.searchQuery = '',

    this.loading = false,

    this.error,

  });



  final List<ProductModel> allProducts;

  final ProductCategory selectedCategory;

  final String searchQuery;

  final bool loading;

  final String? error;



  List<ProductModel> get filteredProducts {

    var list = allProducts;



    // Category filter

    if (selectedCategory != ProductCategory.all) {

      list = list.where((p) => p.category == selectedCategory).toList();

    }



    // Search filter

    final q = searchQuery.toLowerCase().trim();

    if (q.isNotEmpty) {

      list = list

          .where((p) =>

              p.name.toLowerCase().contains(q) ||

              p.category.label.toLowerCase().contains(q))

          .toList();

    }



    return list;

  }



  ShopState copyWith({

    List<ProductModel>? allProducts,

    ProductCategory? selectedCategory,

    String? searchQuery,

    bool? loading,

    String? error,

    bool clearError = false,

  }) =>

      ShopState(

        allProducts: allProducts ?? this.allProducts,

        selectedCategory: selectedCategory ?? this.selectedCategory,

        searchQuery: searchQuery ?? this.searchQuery,

        loading: loading ?? this.loading,

        error: clearError ? null : error ?? this.error,

      );

}



class ShopController extends StateNotifier<ShopState> {

  ShopController(this._repo) : super(const ShopState()) {

    loadProducts();

  }



  final IProductRepository _repo;



  Future<void> loadProducts() async {

    state = state.copyWith(loading: true, clearError: true);

    try {

      final products = await _repo.fetchProducts();

      state = state.copyWith(allProducts: products, loading: false);

    } catch (e) {

      state = state.copyWith(

        loading: false,

        error: 'Failed to load products. Please try again.',

      );

    }

  }



  void selectCategory(ProductCategory category) {

    state = state.copyWith(selectedCategory: category);

  }



  void updateSearch(String query) {

    state = state.copyWith(searchQuery: query);

  }



  void clearSearch() {

    state = state.copyWith(searchQuery: '');

  }

}



// ── Order placement (ready for payment integration) ───────────────────────────



enum OrderStatus { idle, processing, success, failed }



class OrderState {

  const OrderState({

    this.status = OrderStatus.idle,

    this.orderId,

    this.error,

  });



  final OrderStatus status;

  final String? orderId;

  final String? error;



  OrderState copyWith({

    OrderStatus? status,

    String? orderId,

    String? error,

    bool clearError = false,

  }) =>

      OrderState(

        status: status ?? this.status,

        orderId: orderId ?? this.orderId,

        error: clearError ? null : error ?? this.error,

      );

}



class OrderController extends StateNotifier<OrderState> {

  OrderController() : super(const OrderState());



  Future<void> placeOrder({

    required CartSummary cart,

    required String deliveryName,

    required String deliveryAddress,

    required String paymentMethod,

  }) async {

    state = state.copyWith(status: OrderStatus.processing, clearError: true);

    try {

      final user = Supabase.instance.client.auth.currentUser;

      var orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}';



      // Persist order to Supabase (fire-and-forget if unauthenticated)

      if (user != null) {

        final response = await Supabase.instance.client

            .from('orders')

            .insert({

              'user_id': user.id,

              'total_paise': cart.totalPaise,

              'subtotal_paise': cart.totalPaise,

              'tax_paise': 0,

              'status': 'confirmed',

              'shipping_addr': {

                'name': deliveryName,

                'address': deliveryAddress,

                'payment_method': paymentMethod,

              },

              'items': cart.items

                  .map((i) => {

                        'product_id': i.product.id,

                        'name': i.product.name,

                        'quantity': i.quantity,

                        'unit_paise': i.product.pricePaise,

                      })

                  .toList(),

            })

            .select('id')

            .single();

        final dbId = response['id'] as String;

        orderId = 'ORD-${dbId.substring(0, 8).toUpperCase()}';

      }



      state = state.copyWith(status: OrderStatus.success, orderId: orderId);

    } catch (e) {

      state = state.copyWith(

        status: OrderStatus.failed,

        error: 'Order placement failed. Please try again.',

      );

    }

  }



  void reset() => state = const OrderState();

}

