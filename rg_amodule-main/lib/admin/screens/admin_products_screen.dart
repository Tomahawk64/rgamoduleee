// lib/admin/screens/admin_products_screen.dart
// CRUD management for Shop Products — accessible only to admin.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../models/admin_models.dart';
import '../providers/admin_providers.dart';

const _kCategories = [
  'all',
  'rudraksh',
  'yantra',
  'kit',
  'spiritual',
];

String _normalizeProductCategory(String? raw) {
  final value = (raw ?? '').trim().toLowerCase();
  switch (value) {
    case 'puja-kit':
    case 'puja kit':
    case 'kit':
      return 'kit';
    case 'rudraksha':
    case 'rudraksh':
      return 'rudraksh';
    case 'spiritual':
    case 'yantra':
      return value;
    case '':
      return 'spiritual';
    default:
      return value;
  }
}

List<String> _formCategoriesForValue(String currentValue) {
  final categories = _kCategories.where((c) => c != 'all').toList();
  final normalized = _normalizeProductCategory(currentValue);
  if (!categories.contains(normalized)) {
    categories.add(normalized);
  }
  return categories.toSet().toList()..sort();
}

class AdminProductsScreen extends ConsumerStatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  ConsumerState<AdminProductsScreen> createState() =>
      _AdminProductsScreenState();
}

class _AdminProductsScreenState
    extends ConsumerState<AdminProductsScreen> {
  String _search = '';
  String _category = 'all';

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(adminProvider.notifier).loadProducts());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    final isLoading = state.isSectionLoading(AdminSection.products);

    ref.listen<AdminState>(adminProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.error!),
          backgroundColor: AppColors.error,
        ));
        ref.read(adminProvider.notifier).clearError();
      }
    });

    final q = _search.toLowerCase();
    final products = state.products.where((p) {
        final matchCat =
          _category == 'all' || _normalizeProductCategory(p.category) == _category;
      final matchSearch = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q);
      return matchCat && matchSearch;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Products',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  ref.read(adminProvider.notifier).loadProducts(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductSheet(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search products…',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),

          // Category chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: _kCategories.length,
              itemBuilder: (_, i) {
                final cat = _kCategories[i];
                final selected = _category == cat;
                return FilterChip(
                  label: Text(
                    cat == 'all'
                        ? 'All (${state.products.length})'
                        : '${cat[0].toUpperCase()}${cat.substring(1)} (${state.products.where((p) => _normalizeProductCategory(p.category) == cat).length})',
                  ),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = cat),
                  selectedColor:
                      AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: selected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Product list
          Expanded(
            child: products.isEmpty
                ? Center(
                    child: Text(
                      isLoading ? 'Loading products…' : 'No products found',
                      style: const TextStyle(
                          color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 10),
                    itemCount: products.length,
                    itemBuilder: (_, i) => _ProductCard(
                      product: products[i],
                      onEdit: () =>
                          _showProductSheet(context, ref, products[i]),
                      onDelete: () =>
                          _confirmDelete(context, ref, products[i]),
                      onToggle: (v) => ref
                          .read(adminProvider.notifier)
                          .toggleProduct(products[i].id, isActive: v),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, AdminProduct p) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${p.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((ok) {
      if (ok == true) {
        ref.read(adminProvider.notifier).deleteProduct(p.id);
      }
    });
  }

  void _showProductSheet(
      BuildContext context, WidgetRef ref, AdminProduct? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductFormSheet(
        existing: existing,
        onSave: (product) {
          if (existing == null) {
            ref.read(adminProvider.notifier).createProduct(product);
          } else {
            ref.read(adminProvider.notifier).updateProduct(product);
          }
        },
      ),
    );
  }
}

// ── Product card ───────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final AdminProduct product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
            child: Row(
              children: [
                // Category icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_categoryIcon(product.category),
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (product.isBestSeller)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(6),
                              ),
                              child: const Text('BEST SELLER',
                                  style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF59E0B))),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.formattedPrice,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Active toggle
                Switch(
                  value: product.isActive,
                  onChanged: onToggle,
                  activeThumbColor: AppColors.success,
                  materialTapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),

          // Description + meta
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.description.isNotEmpty)
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _MetaChip(
                      icon: Icons.inventory_2_outlined,
                      label: 'Stock: ${product.stock}',
                    ),
                    const SizedBox(width: 8),
                    _MetaChip(
                      icon: Icons.category_outlined,
                      label: product.category,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'rudraksh':  return Icons.blur_circular_outlined;
      case 'yantra':    return Icons.crop_square_outlined;
      case 'kit':       return Icons.inventory_outlined;
      case 'spiritual': return Icons.auto_awesome_outlined;
      default:          return Icons.shopping_bag_outlined;
    }
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 12,
                color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      );
}

// ── Product form sheet ─────────────────────────────────────────────────────────

class _ProductFormSheet extends StatefulWidget {
  const _ProductFormSheet(
      {required this.existing, required this.onSave});
  final AdminProduct? existing;
  final ValueChanged<AdminProduct> onSave;

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _imageUrl;
  late String _category;
  late bool _isBestSeller;
  late bool _isActive;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _name       = TextEditingController(text: p?.name ?? '');
    _desc       = TextEditingController(text: p?.description ?? '');
    _price      = TextEditingController(
        text: p != null ? (p.pricePaise / 100).toStringAsFixed(2) : '');
    _stock      = TextEditingController(
        text: p != null ? p.stock.toString() : '');
    _imageUrl   = TextEditingController(text: p?.imageUrl ?? '');
    _category   = _normalizeProductCategory(p?.category);
    _isBestSeller = p?.isBestSeller ?? false;
    _isActive   = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    _stock.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final pricePaise = (double.tryParse(_price.text) ?? 0) * 100;
    final stock = int.tryParse(_stock.text) ?? 0;

    final product = AdminProduct(
      id: widget.existing?.id ?? '',
      name: _name.text.trim(),
      description: _desc.text.trim(),
      pricePaise: pricePaise.round(),
      category: _category,
      stock: stock,
      imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
      includes: widget.existing?.includes ?? const [],
      isBestSeller: _isBestSeller,
      isActive: _isActive,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    widget.onSave(product);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final categoryItems = _formCategoriesForValue(_category);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Row(
                children: [
                  Text(
                    isEdit ? 'Edit Product' : 'Add Product',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    // Name
                    _label('Product Name'),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'Required'
                          : null,
                      decoration: _decor('e.g. 5 Mukhi Rudraksha'),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    _label('Description'),
                    TextFormField(
                      controller: _desc,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _decor('Short product description…'),
                    ),
                    const SizedBox(height: 16),

                    // Price + Stock (side by side)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _label('Price (₹)'),
                              TextFormField(
                                controller: _price,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d{0,2}')),
                                ],
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Required';
                                  }
                                  if ((double.tryParse(v) ?? -1) <= 0) {
                                    return 'Must be > 0';
                                  }
                                  return null;
                                },
                                decoration: _decor('0.00'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _label('Stock'),
                              TextFormField(
                                controller: _stock,
                                keyboardType:
                                    TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter
                                      .digitsOnly,
                                ],
                                validator: (v) =>
                                    (v?.trim().isEmpty ?? true)
                                        ? 'Required'
                                        : null,
                                decoration: _decor('0'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Category
                    _label('Category'),
                    DropdownButtonFormField<String>(
                      value: _category,
                      items: categoryItems
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                  '${c[0].toUpperCase()}${c.substring(1)}')))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _category = v ?? _category),
                      decoration: _decor(null),
                    ),
                    const SizedBox(height: 16),

                    // Image URL
                    _label('Image URL (optional)'),
                    TextFormField(
                      controller: _imageUrl,
                      keyboardType: TextInputType.url,
                      decoration: _decor(
                          'https://example.com/product.jpg'),
                    ),
                    const SizedBox(height: 16),

                    // Toggles
                    SwitchListTile(
                      value: _isBestSeller,
                      onChanged: (v) =>
                          setState(() => _isBestSeller = v),
                      title: const Text('Best Seller',
                          style: TextStyle(fontSize: 14)),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: const Color(0xFFF59E0B),
                    ),
                    SwitchListTile(
                      value: _isActive,
                      onChanged: (v) =>
                          setState(() => _isActive = v),
                      title: const Text('Active (visible to users)',
                          style: TextStyle(fontSize: 14)),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.success,
                    ),
                    const SizedBox(height: 24),

                    // Save button
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              isEdit ? 'Update Product' : 'Create Product',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      );

  InputDecoration _decor(String? hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      );
}
