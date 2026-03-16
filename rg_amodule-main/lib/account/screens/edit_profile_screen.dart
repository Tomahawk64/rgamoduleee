// lib/account/screens/edit_profile_screen.dart
// Allows the authenticated user to update their display name and phone number.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/supabase_storage_upload_helper.dart';
import '../../models/role_enum.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  Uint8List? _avatarBytes;
  String? _avatarExt;
  String? _avatarUrl;
  bool _saving = false;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _avatarUrl = user?.avatarUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final currentUser = ref.read(currentUserProvider);
    final avatarRequired = currentUser?.role == UserRole.pandit;
    if (avatarRequired && _avatarBytes == null && (_avatarUrl ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pandit profile photo is required before saving.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final client = ref.read(supabaseClientProvider);
      final uid = client.auth.currentUser?.id;
      if (uid == null) throw Exception('Not authenticated');

      final uploadedAvatarUrl = await _uploadAvatarIfNeeded(client, uid);

      await client.from('profiles').update({
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        'avatar_url': uploadedAvatarUrl,
      }).eq('id', uid);

      // Refresh auth state so the app-wide user model updates
      await ref.read(authProvider.notifier).refreshProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final dotIdx = picked.name.lastIndexOf('.');
    final ext = dotIdx != -1
        ? picked.name.substring(dotIdx + 1).toLowerCase()
        : 'jpg';
    if (!mounted) return;

    setState(() {
      _avatarBytes = bytes;
      _avatarExt = ext.isEmpty ? 'jpg' : ext;
    });
  }

  Future<String?> _uploadAvatarIfNeeded(SupabaseClient client, String uid) async {
    if (_avatarBytes == null) return _avatarUrl;

    setState(() => _uploadingImage = true);
    try {
      final ext = (_avatarExt == null || _avatarExt!.isEmpty) ? 'jpg' : _avatarExt!;
      final contentType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final url = await SupabaseStorageUploadHelper.uploadImageWithFallback(
        client: client,
        bytes: _avatarBytes!,
        fileName: fileName,
        contentType: contentType,
        folder: 'avatar',
        primaryBucket: SupabaseStorageUploadHelper.profileImagesBucket,
        fallbackBuckets: const [],
      );
      setState(() => _avatarUrl = url);
      return url;
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final avatarRequired = user?.role == UserRole.pandit;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            // Avatar
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: _avatarBytes != null
                        ? MemoryImage(_avatarBytes!)
                        : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                            ? NetworkImage(_avatarUrl!)
                            : null) as ImageProvider<Object>?,
                    child: _avatarBytes == null && (_avatarUrl == null || _avatarUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 48, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _saving || _uploadingImage ? null : _pickAvatar,
                    icon: _uploadingImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.image_outlined),
                    label: Text(avatarRequired ? 'Upload Profile Photo *' : 'Upload Profile Photo'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    avatarRequired
                        ? 'Profile photo is required for pandit accounts.'
                        : 'Profile photo is optional for user accounts.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Full name
            _label('Full Name'),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              decoration: _decor('Your full name', Icons.person_outline),
            ),
            const SizedBox(height: 20),

            // Phone
            _label('Phone Number'),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _decor('+91 98765 43210', Icons.phone_outlined),
            ),
            const SizedBox(height: 40),

            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      );

  InputDecoration _decor(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textHint),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );
}
