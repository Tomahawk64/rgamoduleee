// lib/admin/screens/admin_products_screen.dart
// CRUD management for Shop Products — accessible only to admin.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/supabase_storage_upload_helper.dart';
import '../models/admin_models.dart';
import '../providers/admin_providers.dart';

const _kCategories = [
  'all',
  'rudraksh',
  'yantra',
  'kit',
  'spiritual',
];

const _kMaxProductImageBytes = 5 * 1024 * 1024;
const _kProductImageGuidance =
    'Recommended size: 1600x900 px (16:9). Keep the kit centered so it crops cleanly in product cards.';
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
        onUploadImage: _uploadProductImage,
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

  Future<String> _uploadProductImage(
    Uint8List bytes,
    String fileName,
    String contentType,
  ) async {
    if (bytes.isEmpty) {
      throw Exception('Selected file is empty. Please choose another image.');
    }

    if (bytes.lengthInBytes > _kMaxProductImageBytes) {
      throw Exception(
        'Image is too large. Maximum allowed size is '
        '${_kMaxProductImageBytes ~/ (1024 * 1024)} MB.',
      );
    }

    final client = ref.read(supabaseClientProvider);
    return SupabaseStorageUploadHelper.uploadImageWithFallback(
      client: client,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      folder: 'products',
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

typedef _UploadProductImage = Future<String> Function(
  Uint8List bytes,
  String fileName,
  String contentType,
);

class _ProductFormSheet extends StatefulWidget {
  const _ProductFormSheet(
      {required this.existing,
      required this.onSave,
      required this.onUploadImage});
  final AdminProduct? existing;
  final ValueChanged<AdminProduct> onSave;
  final _UploadProductImage onUploadImage;

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _includes;
  late final TextEditingController _imageUrl;
  late String _category;
  late bool _isBestSeller;
  late bool _isActive;
  bool _saving = false;
  bool _uploadingImage = false;

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
    _includes   = TextEditingController(text: p?.includes.join('\n') ?? '');
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
    _includes.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final imageText = _imageUrl.text.trim();
    final imageUrl = imageText.isEmpty ? null : imageText;
    if (imageUrl != null && !_looksLikeValidImageSource(imageUrl)) {
      _showError('Please upload a valid product image before saving.');
      return;
    }

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
      imageUrl: imageUrl,
      includes: _parseIncludes(_includes.text),
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
                      initialValue: _category,
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

                    // What's included
                    _label("What's Included"),
                    TextFormField(
                      controller: _includes,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _decor(
                        'One item per line, e.g.\nBrass Kalash\nMango Leaves\nRed Cloth Set',
                      ).copyWith(
                        helperText:
                            'These items are shown in the product details under "What\'s Included".',
                        helperMaxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Product image upload
                    _label('Product Image'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Upload the kit image directly instead of pasting a link.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            _kProductImageGuidance,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed:
                                    _uploadingImage ? null : _pickFromGallery,
                                icon: const Icon(
                                  Icons.photo_library_outlined,
                                  size: 18,
                                ),
                                label: const Text('Upload From Gallery'),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    _uploadingImage ? null : _pickFromFiles,
                                icon: const Icon(
                                  Icons.folder_open_outlined,
                                  size: 18,
                                ),
                                label: const Text('Upload From Files'),
                              ),
                              if (_uploadingImage)
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 10,
                                  ),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _imageUrl,
                            builder: (context, value, child) {
                              final image = value.text.trim();
                              if (image.isEmpty) {
                                return const Text(
                                  'No image selected yet.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Preview',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: _uploadingImage
                                            ? null
                                            : () => _imageUrl.clear(),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 16,
                                        ),
                                        label: const Text('Remove Image'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  _ProductImage(
                                    imageUrl: image,
                                    height: 110,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
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

  List<String> _parseIncludes(String raw) {
    return raw
        .split(RegExp(r'[,\n]+'))
        .map((item) => item.trim())
        .map((item) => item.replaceFirst(RegExp(r'^[-*\u2022]\s*'), ''))
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 2000,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      await _uploadPickedImage(bytes, picked.name);
    } catch (e) {
      _showError('Could not pick image from gallery: $e');
    }
  }

  Future<void> _pickFromFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      final file = (result != null && result.files.isNotEmpty)
          ? result.files.first
          : null;
      if (file == null || file.bytes == null) return;

      await _uploadPickedImage(file.bytes!, file.name);
    } catch (e) {
      _showError('Could not pick image file: $e');
    }
  }

  Future<void> _uploadPickedImage(Uint8List bytes, String fileName) async {
    if (bytes.lengthInBytes > _kMaxProductImageBytes) {
      _showError(
        'Image is too large. Max allowed size is '
        '${_kMaxProductImageBytes ~/ (1024 * 1024)} MB.',
      );
      return;
    }

    final contentType = _contentTypeFor(fileName);

    setState(() => _uploadingImage = true);
    try {
      final uploadedUrl =
          await widget.onUploadImage(bytes, fileName, contentType);
      if (!mounted) return;
      _imageUrl.text = uploadedUrl;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Image uploaded successfully.'),
          behavior: SnackBarBehavior.floating,
        ));
    } catch (e) {
      _showError('Image upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  String _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  bool _looksLikeValidImageSource(String value) {
    if (value.startsWith('assets/')) return true;
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    final validScheme = uri.scheme == 'http' || uri.scheme == 'https';
    return validScheme && uri.host.isNotEmpty;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.imageUrl,
    required this.height,
    required this.borderRadius,
  });

  final String imageUrl;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final source = imageUrl.trim();
    final isAsset = source.startsWith('assets/');

    Widget fallback() {
      return Container(
        color: AppColors.background,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: AppColors.textSecondary,
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: isAsset
            ? Image.asset(
                source,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback(),
              )
            : Image.network(
                source,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback(),
              ),
      ),
    );
  }
}
