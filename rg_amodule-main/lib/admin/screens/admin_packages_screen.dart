import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/supabase_storage_upload_helper.dart';
import '../../packages/models/package_model.dart';
import '../providers/admin_package_catalog_provider.dart';

const _kMaxPackageImageBytes = 5 * 1024 * 1024;
const _kPackageImageGuidance =
    'Recommended size: 1600x900 px (16:9). Keep the deity or ritual centered for clean card cropping.';
class AdminPackagesScreen extends ConsumerStatefulWidget {
  const AdminPackagesScreen({super.key});

  @override
  ConsumerState<AdminPackagesScreen> createState() =>
      _AdminPackagesScreenState();
}

class _AdminPackagesScreenState extends ConsumerState<AdminPackagesScreen> {
  String _search = '';
  PackageCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminPackageCatalogProvider);

    ref.listen<AdminPackageCatalogState>(adminPackageCatalogProvider,
        (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ));
        ref.read(adminPackageCatalogProvider.notifier).clearError();
      }
    });

    final query = _search.trim().toLowerCase();
    final packages = state.packages.where((package) {
      final matchesCategory =
          _selectedCategory == null || package.category == _selectedCategory;
      final matchesSearch = query.isEmpty ||
          package.title.toLowerCase().contains(query) ||
          package.description.toLowerCase().contains(query) ||
          package.category.label.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Manage Poojas',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (state.loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () =>
                  ref.read(adminPackageCatalogProvider.notifier).load(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPackageSheet(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add Pooja'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                hintText: 'Search pooja packages…',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
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
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: PackageCategory.values.length + 1,
              itemBuilder: (_, index) {
                if (index == 0) {
                  return FilterChip(
                    label: Text('All (${state.packages.length})'),
                    selected: _selectedCategory == null,
                    onSelected: (_) => setState(() => _selectedCategory = null),
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      color: _selectedCategory == null
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: _selectedCategory == null
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                }

                final category = PackageCategory.values[index - 1];
                final selected = _selectedCategory == category;
                final count = state.packages
                    .where((package) => package.category == category)
                    .length;

                return FilterChip(
                  label: Text('${category.label} ($count)'),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _selectedCategory = category),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryPill(
                  label:
                      '${state.packages.where((package) => package.isActive).length} Active',
                  color: AppColors.success,
                ),
                _SummaryPill(
                  label:
                      '${state.packages.where((package) => !package.isActive).length} Inactive',
                  color: AppColors.warning,
                ),
                _SummaryPill(
                  label:
                      '${state.packages.where((package) => package.isFeatured).length} Featured',
                  color: AppColors.info,
                ),
                _SummaryPill(
                  label:
                      '${state.packages.where((package) => package.isPopular).length} Popular',
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: packages.isEmpty
                ? Center(
                    child: Text(
                      state.loading ? 'Loading pooja packages…' : 'No poojas found',
                      style:
                          const TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemCount: packages.length,
                    itemBuilder: (_, index) => _PackageCard(
                      package: packages[index],
                      onEdit: () =>
                          _showPackageSheet(context, ref, packages[index]),
                      onDelete: () =>
                          _confirmDelete(context, ref, packages[index]),
                      onToggle: (value) => ref
                          .read(adminPackageCatalogProvider.notifier)
                          .togglePackage(packages[index].id, isActive: value),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, PackageModel package) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete pooja?'),
        content: Text(
          '"${package.title}" will be permanently removed from the Poojas tab.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(dialogContext);
              ref
                  .read(adminPackageCatalogProvider.notifier)
                  .deletePackage(package.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showPackageSheet(
    BuildContext context,
    WidgetRef ref,
    PackageModel? existing,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PackageFormSheet(
        existing: existing,
        onSave: (package) {
          if (existing == null) {
            ref.read(adminPackageCatalogProvider.notifier).createPackage(package);
          } else {
            ref.read(adminPackageCatalogProvider.notifier).updatePackage(package);
          }
        },
        onUploadImage: _uploadPackageImage,
      ),
    );
  }

  Future<String> _uploadPackageImage(
    Uint8List bytes,
    String fileName,
    String contentType,
  ) async {
    if (bytes.isEmpty) {
      throw Exception('Selected file is empty. Please choose another image.');
    }

    if (bytes.lengthInBytes > _kMaxPackageImageBytes) {
      throw Exception(
        'Image is too large. Maximum allowed size is '
        '${_kMaxPackageImageBytes ~/ (1024 * 1024)} MB.',
      );
    }

    final client = ref.read(supabaseClientProvider);
    return SupabaseStorageUploadHelper.uploadImageWithFallback(
      client: client,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      folder: 'pooja-packages',
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final PackageModel package;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: package.isActive
              ? AppColors.divider
              : AppColors.warning.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((package.imageUrl ?? '').trim().isNotEmpty) ...[
            _PackageImagePreview(
              imageUrl: package.imageUrl!,
              category: package.category,
              height: 110,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _BadgeChip(
                      label: package.category.label,
                      color: AppColors.primary,
                    ),
                    _BadgeChip(
                      label: package.modeLabel,
                      color: AppColors.info,
                    ),
                    if (package.isFeatured)
                      const _BadgeChip(
                        label: 'Featured',
                        color: AppColors.success,
                      ),
                    if (package.isPopular)
                      const _BadgeChip(
                        label: 'Popular',
                        color: AppColors.warning,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: package.isActive,
                onChanged: onToggle,
                activeThumbColor: AppColors.success,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            package.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            package.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.currency_rupee_rounded,
                label: '₹${package.price.toStringAsFixed(0)}',
              ),
              if (package.hasDiscount)
                _MetaChip(
                  icon: Icons.discount_rounded,
                  label: '₹${package.discountPrice!.toStringAsFixed(0)} sale',
                  color: AppColors.success,
                ),
              _MetaChip(
                icon: Icons.schedule_rounded,
                label: package.durationLabel,
              ),
              _MetaChip(
                icon: Icons.list_alt_rounded,
                label: '${package.includes.length} includes',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ActionIcon(
                icon: Icons.edit_outlined,
                color: AppColors.secondary,
                onTap: onEdit,
              ),
              const SizedBox(width: 8),
              _ActionIcon(
                icon: Icons.delete_outline,
                color: AppColors.error,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

typedef _UploadPackageImage = Future<String> Function(
  Uint8List bytes,
  String fileName,
  String contentType,
);

class _PackageFormSheet extends StatefulWidget {
  const _PackageFormSheet({
    this.existing,
    required this.onSave,
    required this.onUploadImage,
  });

  final PackageModel? existing;
  final ValueChanged<PackageModel> onSave;
  final _UploadPackageImage onUploadImage;

  @override
  State<_PackageFormSheet> createState() => _PackageFormSheetState();
}

class _PackageFormSheetState extends State<_PackageFormSheet> {
  final _picker = ImagePicker();

  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _imageUrl;
  late final TextEditingController _price;
  late final TextEditingController _discountPrice;
  late final TextEditingController _duration;
  late final TextEditingController _includes;
  late PackageCategory _selectedCategory;
  late PackageMode _selectedMode;
  late bool _isActive;
  late bool _isPopular;
  late bool _isFeatured;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    final package = widget.existing;
    _title = TextEditingController(text: package?.title ?? '');
    _description = TextEditingController(text: package?.description ?? '');
    _imageUrl = TextEditingController(text: package?.imageUrl ?? '');
    _price = TextEditingController(
      text: package != null ? package.price.toStringAsFixed(0) : '',
    );
    _discountPrice = TextEditingController(
      text: package?.discountPrice != null
          ? package!.discountPrice!.toStringAsFixed(0)
          : '',
    );
    _duration = TextEditingController(
      text: package != null ? '${package.durationMinutes}' : '',
    );
    _includes = TextEditingController(
      text: package?.includes.join('\n') ?? '',
    );
    _selectedCategory = package?.category ?? PackageCategory.puja;
    _selectedMode = package?.mode ?? PackageMode.both;
    _isActive = package?.isActive ?? true;
    _isPopular = package?.isPopular ?? false;
    _isFeatured = package?.isFeatured ?? false;
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _description,
      _imageUrl,
      _price,
      _discountPrice,
      _duration,
      _includes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  isEdit ? 'Edit Pooja' : 'New Pooja',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _AdminTextField(controller: _title, label: 'Title'),
            const SizedBox(height: 12),
            DropdownButtonFormField<PackageCategory>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category',
                helperText: 'Shown in the customer Poojas tab filters.',
                helperMaxLines: 2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
              items: PackageCategory.values.map((category) {
                return DropdownMenuItem<PackageCategory>(
                  value: category,
                  child: Row(
                    children: [
                      Icon(category.icon, size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(category.label),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (category) {
                if (category != null) {
                  setState(() => _selectedCategory = category);
                }
              },
            ),
            const SizedBox(height: 12),
            _AdminTextField(
              controller: _description,
              label: 'Description',
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            _AdminTextField(
              controller: _imageUrl,
              label: 'Image URL',
              hintText: 'https://cdn.example.com/pooja.jpg',
              helperText: _kPackageImageGuidance,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _uploadingImage ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Upload From Gallery'),
                ),
                OutlinedButton.icon(
                  onPressed: _uploadingImage ? null : _pickFromFiles,
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  label: const Text('Upload From Files'),
                ),
                if (_uploadingImage)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _imageUrl,
              builder: (context, value, child) {
                final image = value.text.trim();
                if (image.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Card preview',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _PackageImagePreview(
                      imageUrl: image,
                      category: _selectedCategory,
                      height: 110,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AdminTextField(
                    controller: _price,
                    label: 'Price (₹)',
                    keyboard: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AdminTextField(
                    controller: _discountPrice,
                    label: 'Discount Price (₹)',
                    keyboard: TextInputType.number,
                    hintText: 'Optional',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AdminTextField(
                    controller: _duration,
                    label: 'Duration (min)',
                    keyboard: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AdminTextField(
                    controller: _includes,
                    label: 'Includes',
                    maxLines: 4,
                    hintText: 'One item per line or comma separated',
                    helperText:
                        'These bullet points are shown on the package detail screen.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ToggleTile(
                    label: 'Active listing',
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                ),
                Expanded(
                  child: _ToggleTile(
                    label: 'Featured on home',
                    value: _isFeatured,
                    onChanged: (value) => setState(() => _isFeatured = value),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _ToggleTile(
                    label: 'Popular tag',
                    value: _isPopular,
                    onChanged: (value) => setState(() => _isPopular = value),
                  ),
                ),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(isEdit ? 'Save Changes' : 'Create Pooja'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_title.text.trim().isEmpty || _description.text.trim().isEmpty) {
      _showError('Title and description are required.');
      return;
    }

    final price = double.tryParse(_price.text.trim());
    if (price == null || price <= 0) {
      _showError('Enter a valid pooja price greater than zero.');
      return;
    }

    double? discountPrice;
    final discountText = _discountPrice.text.trim();
    if (discountText.isNotEmpty) {
      discountPrice = double.tryParse(discountText);
      if (discountPrice == null || discountPrice <= 0) {
        _showError('Enter a valid discount price or leave it empty.');
        return;
      }
      if (discountPrice >= price) {
        _showError('Discount price must be lower than the base price.');
        return;
      }
    }

    final duration = int.tryParse(_duration.text.trim());
    if (duration == null || duration <= 0) {
      _showError('Enter a valid duration in minutes.');
      return;
    }

    final imageText = _imageUrl.text.trim();
    final imageUrl = imageText.isEmpty ? null : imageText;
    if (imageUrl != null && !_looksLikeValidImageSource(imageUrl)) {
      _showError('Enter a valid image URL (http/https) or an assets/ path.');
      return;
    }

    final package = PackageModel(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      description: _description.text.trim(),
      price: price,
      discountPrice: discountPrice,
      durationMinutes: duration,
      mode: _selectedMode,
      category: _selectedCategory,
      includes: _parseIncludes(_includes.text),
      reviews: widget.existing?.reviews ?? const [],
      rating: widget.existing?.rating ?? 0,
      reviewCount: widget.existing?.reviewCount ?? 0,
      bookingCount: widget.existing?.bookingCount ?? 0,
      isActive: _isActive,
      isPopular: _isPopular,
      isFeatured: _isFeatured,
      imageUrl: imageUrl,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    widget.onSave(package);
    Navigator.pop(context);
  }

  List<String> _parseIncludes(String raw) {
    return raw
        .split(RegExp(r'[\n,]+'))
        .map((item) => item.trim())
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
      final file =
          (result != null && result.files.isNotEmpty) ? result.files.first : null;
      if (file == null || file.bytes == null) return;

      await _uploadPickedImage(file.bytes!, file.name);
    } catch (e) {
      _showError('Could not pick image file: $e');
    }
  }

  Future<void> _uploadPickedImage(Uint8List bytes, String fileName) async {
    if (bytes.lengthInBytes > _kMaxPackageImageBytes) {
      _showError(
        'Image is too large. Max allowed size is '
        '${_kMaxPackageImageBytes ~/ (1024 * 1024)} MB.',
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

  String _modeLabel(PackageMode mode) {
    switch (mode) {
      case PackageMode.online:
        return 'Online only';
      case PackageMode.offline:
        return 'On-site only';
      case PackageMode.both:
        return 'Online and on-site';
    }
  }
}

class _PackageImagePreview extends StatelessWidget {
  const _PackageImagePreview({
    required this.imageUrl,
    required this.category,
    required this.height,
    required this.borderRadius,
  });

  final String imageUrl;
  final PackageCategory category;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final isLocal = imageUrl.startsWith('assets/');

    return ClipRRect(
      borderRadius: borderRadius,
      child: isLocal
          ? Image.asset(
              imageUrl,
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _fallback(),
            )
          : Image.network(
              imageUrl,
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _fallback(),
            ),
    );
  }

  Widget _fallback() {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.85),
            AppColors.secondary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          category.icon,
          size: 44,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.color = AppColors.textSecondary,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _AdminTextField extends StatelessWidget {
  const _AdminTextField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboard = TextInputType.text,
    this.hintText,
    this.helperText,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType keyboard;
  final String? hintText;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        helperMaxLines: 3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.success,
        ),
      ],
    );
  }
}