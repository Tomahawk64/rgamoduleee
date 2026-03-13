// lib/shop/screens/shop_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/base_scaffold.dart';
import '../models/product_model.dart';
import '../providers/shop_provider.dart';
import '../controllers/shop_controller.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopState = ref.watch(shopProvider);
    final cartCount = ref.watch(cartItemCountProvider);

    return BaseScaffold(
      title: AppStrings.shop,
      showBackButton: false,
      actions: [
        _CartBadge(
          count: cartCount,
          onTap: () => context.push(Routes.cart),
        ),
        const SizedBox(width: 8),
      ],
      body: Column(
        children: [
          // ── Search ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) =>
                  ref.read(shopProvider.notifier).updateSearch(v),
              decoration: InputDecoration(
                hintText: 'Search kits…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: shopState.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(shopProvider.notifier).clearSearch();
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // ── Category chips ────────────────────────────────────────────────
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: ProductCategory.values.length,
              itemBuilder: (_, i) {
                final cat = ProductCategory.values[i];
                final selected = cat == shopState.selectedCategory;
                return _CategoryChip(
                  label: cat.shortLabel,
                  selected: selected,
                  onTap: () =>
                      ref.read(shopProvider.notifier).selectCategory(cat),
                );
              },
            ),
          ),

          // ── Product grid ──────────────────────────────────────────────────
          Expanded(
            child: _buildBody(shopState),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ShopState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return _ErrorState(
        message: state.error!,
        onRetry: () => ref.read(shopProvider.notifier).loadProducts(),
      );
    }
    final products = state.filteredProducts;
    if (products.isEmpty) {
      return _EmptyState(
        isSearch: state.searchQuery.isNotEmpty,
        onClear: () {
          _searchCtrl.clear();
          ref.read(shopProvider.notifier).clearSearch();
          ref
              .read(shopProvider.notifier)
              .selectCategory(ProductCategory.all);
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(shopProvider.notifier).loadProducts(),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        itemCount: products.length,
        itemBuilder: (ctx, i) => _ProductCard(product: products[i]),
      ),
    );
  }
}

// ── Category chip ─────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Product card ──────────────────────────────────────────────────────────────

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product});
  final ProductModel product;

  static const _categoryIcons = <ProductCategory, IconData>{
    ProductCategory.satyanarayanKit: Icons.brightness_5,
    ProductCategory.grihPraveshKit: Icons.home,
    ProductCategory.marriageKit: Icons.celebration,
    ProductCategory.navgrahaKit: Icons.public,
    ProductCategory.all: Icons.temple_hindu,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final inCart = cartState.containsProduct(product.id);
    final qty = cartState.quantityOf(product.id);
    final icon =
        _categoryIcons[product.category] ?? Icons.temple_hindu;

    return GestureDetector(
      onTap: () => context.push(
        Routes.productDetail.replaceFirst(':id', product.id),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                    ),
                    child: product.imageAsset != null
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14),
                            ),
                            child: Image.asset(
                              product.imageAsset!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Center(
                            child: Icon(
                              icon,
                              size: 52,
                              color: AppColors.primary.withValues(alpha: 0.45),
                            ),
                          ),
                  ),
                  if (product.isBestSeller)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Best Seller',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Info
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          product.formattedPrice,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.star,
                            size: 11, color: AppColors.warning),
                        const SizedBox(width: 2),
                        Text(
                          product.rating.toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Add to cart / qty selector
                    SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: inCart
                          ? _InlineQtySelector(
                              qty: qty,
                              onDecrement: () => ref
                                  .read(cartProvider.notifier)
                                  .decrement(product.id),
                              onIncrement: () => ref
                                  .read(cartProvider.notifier)
                                  .increment(product.id),
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                textStyle: const TextStyle(fontSize: 11),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => ref
                                  .read(cartProvider.notifier)
                                  .addItem(product),
                              child: const Text('Add to Cart'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Inline quantity selector (inside card) ────────────────────────────────────

class _InlineQtySelector extends StatelessWidget {
  const _InlineQtySelector({
    required this.qty,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int qty;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              width: 28,
              height: double.infinity,
              alignment: Alignment.center,
              child: Icon(
                qty == 1 ? Icons.delete_outline : Icons.remove,
                size: 14,
                color: AppColors.primary,
              ),
            ),
          ),
          Text(
            '$qty',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.primary,
            ),
          ),
          GestureDetector(
            onTap: onIncrement,
            child: Container(
              width: 28,
              height: double.infinity,
              alignment: Alignment.center,
              child: const Icon(Icons.add, size: 14, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cart badge (action icon) ──────────────────────────────────────────────────

class _CartBadge extends StatelessWidget {
  const _CartBadge({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.shopping_cart_outlined),
          if (count > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Empty / Error states ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isSearch, required this.onClear});
  final bool isSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearch ? Icons.search_off : Icons.store_outlined,
            size: 64,
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            isSearch ? 'No kits found' : 'No products available',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onClear,
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
