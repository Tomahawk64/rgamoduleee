// lib/admin/screens/admin_poojas_screen.dart
// CRUD management for Poojas — accessible only to admin.

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/constants/demo_config.dart';
import '../../core/providers/supabase_provider.dart';
import '../models/admin_models.dart';
import '../../packages/models/package_model.dart';
import '../providers/admin_providers.dart';

const _kPoojaImageBucket = 'special-pooja-images';
const _kMaxPoojaImageBytes = 5 * 1024 * 1024;
const _kPoojaImageGuidance =
  'Recommended size: 1600x900 px (16:9). Keep key subject centered so it crops cleanly in cards.';

class AdminPoojasScreen extends ConsumerStatefulWidget {
  const AdminPoojasScreen({super.key});

  @override
  ConsumerState<AdminPoojasScreen> createState() =>
      _AdminPoojasScreenState();
}

class _AdminPoojasScreenState extends ConsumerState<AdminPoojasScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    final poojas = state.poojas
        .where((p) =>
            _search.isEmpty ||
            p.title.toLowerCase().contains(_search.toLowerCase()) ||
            p.category.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    final loading = state.isSectionLoading(AdminSection.poojas);

    ref.listen<AdminState>(adminProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.error!),
          backgroundColor: AppColors.error,
        ));
        ref.read(adminProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Poojas',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPoojaDialog(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add Pooja'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search poojas…',
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

          // Summary chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _PillChip(
                    label:
                        '${state.poojas.where((p) => p.isActive).length} Active',
                    color: AppColors.success),
                const SizedBox(width: 8),
                _PillChip(
                    label:
                        '${state.poojas.where((p) => !p.isActive).length} Inactive',
                    color: AppColors.warning),
                const SizedBox(width: 8),
                _PillChip(
                    label:
                        '${state.poojas.where((p) => p.isOnlineAvailable).length} Online-ready',
                    color: AppColors.info),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: poojas.isEmpty
                ? const Center(
                    child: Text('No poojas found',
                        style:
                            TextStyle(color: AppColors.textSecondary)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 10),
                    itemCount: poojas.length,
                    itemBuilder: (_, i) => _PoojaCard(
                      pooja: poojas[i],
                      onEdit: () =>
                          _showPoojaDialog(context, ref, poojas[i]),
                      onDelete: () =>
                          _confirmDelete(context, ref, poojas[i]),
                      onToggle: (v) => ref
                          .read(adminProvider.notifier)
                          .togglePooja(poojas[i].id, isActive: v),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, AdminPooja pooja) {
    if (DemoConfig.demoMode) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Delete is disabled in demo mode.'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete pooja?'),
        content: Text(
            '"${pooja.title}" will be permanently removed from listings.'),
        actions: [
          TextButton(
              onPressed: () => ctx.pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              ctx.pop();
              ref
                  .read(adminProvider.notifier)
                  .deletePooja(pooja.id);
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showPoojaDialog(
      BuildContext context, WidgetRef ref, AdminPooja? existing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PoojaFormSheet(
        existing: existing,
        onUploadImage: _uploadPoojaImage,
        onSave: (p) {
          if (existing == null) {
            ref.read(adminProvider.notifier).createPooja(p);
          } else {
            ref.read(adminProvider.notifier).updatePooja(p);
          }
        },
      ),
    );
  }

  Future<String> _uploadPoojaImage(
    Uint8List bytes,
    String fileName,
    String contentType,
  ) async {
    if (bytes.isEmpty) {
      throw Exception('Selected file is empty. Please choose another image.');
    }

    if (bytes.lengthInBytes > _kMaxPoojaImageBytes) {
      throw Exception(
        'Image is too large. Maximum allowed size is '
        '${_kMaxPoojaImageBytes ~/ (1024 * 1024)} MB.',
      );
    }

    final client = ref.read(supabaseClientProvider);
    final ext = _fileExtension(fileName);
    final objectPath =
        'special-poojas/${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}.$ext';

    await client.storage.from(_kPoojaImageBucket).uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );

    return client.storage.from(_kPoojaImageBucket).getPublicUrl(objectPath);
  }

  String _fileExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return 'jpg';
    return fileName.substring(dot + 1).toLowerCase();
  }
}

// ── Pooja card ────────────────────────────────────────────────────────────────

class _PoojaCard extends StatelessWidget {
  const _PoojaCard({
    required this.pooja,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final AdminPooja pooja;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final cardImage = pooja.imageUrl?.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: pooja.isActive
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
          if (cardImage != null && cardImage.isNotEmpty) ...[
            _PoojaImage(
              imageUrl: cardImage,
              height: 100,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    pooja.category.trim().isEmpty ? 'General' : pooja.category,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: pooja.isActive,
                onChanged: onToggle,
                activeThumbColor: AppColors.success,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pooja.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pooja.description,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _InfoChip(
                      icon: Icons.currency_rupee,
                      label: '₹${pooja.basePrice.toStringAsFixed(0)}',
                    ),
                    _InfoChip(
                      icon: Icons.schedule,
                      label: pooja.durationLabel,
                    ),
                    if (pooja.isOnlineAvailable)
                      const _InfoChip(
                        icon: Icons.wifi,
                        label: 'Online',
                        color: AppColors.info,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionIcon(
                    icon: Icons.edit_outlined,
                    color: AppColors.secondary,
                    onTap: onEdit,
                  ),
                  const SizedBox(width: 6),
                  _ActionIcon(
                    icon: Icons.delete_outline,
                    color: AppColors.error,
                    onTap: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Pooja form sheet ──────────────────────────────────────────────────────────

typedef _UploadPoojaImage = Future<String> Function(
  Uint8List bytes,
  String fileName,
  String contentType,
);

class _PoojaFormSheet extends StatefulWidget {
  const _PoojaFormSheet({
    this.existing,
    required this.onSave,
    required this.onUploadImage,
  });
  final AdminPooja? existing;
  final ValueChanged<AdminPooja> onSave;
  final _UploadPoojaImage onUploadImage;

  @override
  State<_PoojaFormSheet> createState() => _PoojaFormSheetState();
}

class _PoojaFormSheetState extends State<_PoojaFormSheet> {
  final _picker = ImagePicker();

  late final TextEditingController _title;
  PackageCategory _selectedCategory = PackageCategory.puja;
  late final TextEditingController _description;
  late final TextEditingController _imageUrl;
  late final TextEditingController _price;
  late final TextEditingController _duration;
  late bool _isActive;
  late bool _isOnline;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _title = TextEditingController(text: p?.title ?? '');
    _selectedCategory = PackageCategory.values.firstWhere(
      (c) => c.label == (p?.category ?? ''),
      orElse: () => PackageCategory.puja,
    );
    _description = TextEditingController(text: p?.description ?? '');
    _imageUrl = TextEditingController(text: p?.imageUrl ?? '');
    _price = TextEditingController(
        text: p != null ? p.basePrice.toStringAsFixed(0) : '');
    _duration = TextEditingController(
        text: p != null ? '${p.durationMinutes}' : '');
    _isActive = p?.isActive ?? true;
    _isOnline = p?.isOnlineAvailable ?? false;
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _imageUrl,
      _price,
      _duration,
    ]) {
      c.dispose();
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
            _FormField(controller: _title, label: 'Title'),
            const SizedBox(height: 12),
            // ── Category dropdown ──────────────────────────────────────
            DropdownButtonFormField<PackageCategory>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category',
                helperText:
                    'Poojas appear under this filter in the Browse Poojas tab.',
                helperMaxLines: 2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              items: PackageCategory.values.map((cat) {
                return DropdownMenuItem<PackageCategory>(
                  value: cat,
                  child: Row(
                    children: [
                      Icon(cat.icon, size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(cat.label),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (cat) {
                if (cat != null) setState(() => _selectedCategory = cat);
              },
            ),
            const SizedBox(height: 12),
            _FormField(
                controller: _description,
                label: 'Description',
                maxLines: 3),
            const SizedBox(height: 12),
            _FormField(
              controller: _imageUrl,
              label: 'Image URL',
              hintText: 'https://cdn.example.com/pooja.jpg',
              helperText: _kPoojaImageGuidance,
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
              builder: (context, value, _) {
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
                    _PoojaImage(
                      imageUrl: image,
                      height: 100,
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
                  child: _FormField(
                    controller: _price,
                    label: 'Base Price (₹)',
                    keyboard: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FormField(
                    controller: _duration,
                    label: 'Duration (min)',
                    keyboard: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ToggleRow(
                    label: 'Active listing',
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ),
                Expanded(
                  child: _ToggleRow(
                    label: 'Online available',
                    value: _isOnline,
                    onChanged: (v) => setState(() => _isOnline = v),
                  ),
                ),
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
                child:
                    Text(isEdit ? 'Save Changes' : 'Create Pooja'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_title.text.isEmpty) return;
    final imageText = _imageUrl.text.trim();
    final imageUrl = imageText.isEmpty ? null : imageText;
    if (imageUrl != null && !_looksLikeValidImageSource(imageUrl)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text(
              'Enter a valid image URL (http/https) or an assets/ path.'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }

    final price = double.tryParse(_price.text) ?? 0;
    final duration = int.tryParse(_duration.text) ?? 60;
    final pooja = AdminPooja(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      category: _selectedCategory.label,
      description: _description.text.trim(),
      imageUrl: imageUrl,
      basePrice: price,
      durationMinutes: duration,
      isActive: _isActive,
      isOnlineAvailable: _isOnline,
      tags: widget.existing?.tags ?? [],
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    widget.onSave(pooja);
    Navigator.pop(context);
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
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Could not pick image from gallery: $e'),
          behavior: SnackBarBehavior.floating,
        ));
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
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Could not pick image file: $e'),
          behavior: SnackBarBehavior.floating,
        ));
    }
  }

  Future<void> _uploadPickedImage(Uint8List bytes, String fileName) async {
    if (bytes.lengthInBytes > _kMaxPoojaImageBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
            'Image is too large. Max allowed size is '
            '${_kMaxPoojaImageBytes ~/ (1024 * 1024)} MB.',
          ),
          behavior: SnackBarBehavior.floating,
        ));
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
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Image upload failed: $e'),
          behavior: SnackBarBehavior.floating,
        ));
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
}

// ── Shared mini widgets ───────────────────────────────────────────────────────

class _PillChip extends StatelessWidget {
  const _PillChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

class _InfoChip extends StatelessWidget {
  const _InfoChip(
      {required this.icon,
      required this.label,
      this.color = AppColors.textSecondary});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon(
      {required this.icon, required this.color, required this.onTap});
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

class _FormField extends StatelessWidget {
  const _FormField({
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
        helperMaxLines: 2,
        filled: true,
        fillColor: AppColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

class _PoojaImage extends StatelessWidget {
  const _PoojaImage({
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
                errorBuilder: (_, _, _) => fallback(),
              )
            : Image.network(
                source,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback(),
              ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow(
      {required this.label,
      required this.value,
      required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.success,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Flexible(
          child: Text(label,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
