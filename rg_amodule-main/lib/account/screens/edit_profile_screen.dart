// lib/account/screens/edit_profile_screen.dart
// Edit profile (name, phone with country picker, avatar) +
// inline Address Management — replacing the separate Manage Addresses screen.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/supabase_storage_upload_helper.dart';
import '../../models/role_enum.dart';
import '../../widgets/country_phone_field.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  // ── Profile fields ────────────────────────────────────────────────────────
  final _profileFormKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  Uint8List? _avatarBytes;
  String? _avatarExt;
  String? _avatarUrl;
  bool _savingProfile = false;
  bool _uploadingImage = false;
  CountryDialCode _selectedCountry = kCountryList.first; // default India +91

  // ── Pandit-specific fields ────────────────────────────────────────────────
  late final TextEditingController _bioCtrl;
  late final TextEditingController _expCtrl;
  late final TextEditingController _specialtiesCtrl;
  late final TextEditingController _languagesCtrl;
  bool _panditDetailsLoading = false;

  // ── Address fields ────────────────────────────────────────────────────────
  bool _addressLoading = true;
  bool _savingAddress = false;
  String? _addressError;
  List<Map<String, dynamic>> _addresses = const [];

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    // Strip any stored dial code prefix so only digits appear
    final rawPhone = (user?.phone ?? '').replaceAll(RegExp(r'^\+\d{1,3}\s*'), '');
    _phoneCtrl = TextEditingController(text: rawPhone);
    _avatarUrl = user?.avatarUrl;
    _bioCtrl = TextEditingController();
    _expCtrl = TextEditingController();
    _specialtiesCtrl = TextEditingController();
    _languagesCtrl = TextEditingController();
    if (user?.role == UserRole.pandit) {
      Future.microtask(_loadPanditDetails);
    }
    Future.microtask(_loadAddresses);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    _expCtrl.dispose();
    _specialtiesCtrl.dispose();
    _languagesCtrl.dispose();
    super.dispose();
  }

  // ── Profile save ──────────────────────────────────────────────────────────

  Future<void> _loadPanditDetails() async {
    final client = ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    if (mounted) setState(() => _panditDetailsLoading = true);
    try {
      final row = await client
          .from('pandit_details')
          .select('bio, experience_years, specialties, languages')
          .eq('id', uid)
          .maybeSingle();
      if (!mounted) return;
      if (row != null) {
        final specialties = (row['specialties'] as List<dynamic>?)
                ?.map((s) => s.toString())
                .join(', ') ??
            '';
        final languages = (row['languages'] as List<dynamic>?)
                ?.map((s) => s.toString())
                .join(', ') ??
            '';
        setState(() {
          _bioCtrl.text = row['bio'] as String? ?? '';
          _expCtrl.text = (row['experience_years'] as num?)?.toString() ?? '';
          _specialtiesCtrl.text = specialties;
          _languagesCtrl.text = languages;
        });
      }
    } catch (_) {
      // Non-critical — silently fail
    } finally {
      if (mounted) setState(() => _panditDetailsLoading = false);
    }
  }

  Future<void> _savePanditDetails(SupabaseClient client, String uid) async {
    final specialties = _specialtiesCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final languages = _languagesCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final exp = int.tryParse(_expCtrl.text.trim());

    await client.from('pandit_details').upsert({
      'id': uid,
      'bio': _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
      if (exp != null) 'experience_years': exp,
      if (specialties.isNotEmpty) 'specialties': specialties,
      if (languages.isNotEmpty) 'languages': languages,
    }, onConflict: 'id');
  }

  Future<void> _saveProfile() async {
    if (!(_profileFormKey.currentState?.validate() ?? false)) return;
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

    setState(() => _savingProfile = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final uid = client.auth.currentUser?.id;
      if (uid == null) throw Exception('Not authenticated');

      final uploadedAvatarUrl = await _uploadAvatarIfNeeded(client, uid);
      final phoneToSave = _phoneCtrl.text.trim().isEmpty
          ? null
          : '${_selectedCountry.dialCode}${_phoneCtrl.text.trim()}';

      await client.from('profiles').update({
        'full_name': _nameCtrl.text.trim(),
        'phone': phoneToSave,
        'avatar_url': uploadedAvatarUrl,
      }).eq('id', uid);

      if (currentUser?.role == UserRole.pandit) {
        await _savePanditDetails(client, uid);
      }

      await ref.read(authProvider.notifier).refreshProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
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
    final ext = dotIdx != -1 ? picked.name.substring(dotIdx + 1).toLowerCase() : 'jpg';
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

  // ── Address management ────────────────────────────────────────────────────

  Future<void> _loadAddresses() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (mounted) setState(() { _addressLoading = false; _addressError = 'Not signed in.'; });
      return;
    }
    if (mounted) setState(() { _addressLoading = true; _addressError = null; });
    try {
      final client = ref.read(supabaseClientProvider);
      final rows = await client
          .from('addresses')
          .select('*')
          .eq('user_id', user.id)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _addresses = List<Map<String, dynamic>>.from(rows as List);
        _addressLoading = false;
      });
    } on PostgrestException catch (e) {
      if (mounted) setState(() { _addressLoading = false; _addressError = e.message; });
    } catch (_) {
      if (mounted) setState(() { _addressLoading = false; _addressError = 'Failed to load addresses.'; });
    }
  }

  Future<void> _saveAddressRow({
    Map<String, dynamic>? existing,
    required String label,
    required String addressLine,
    required String city,
    required String state,
    required String pincode,
    required bool isDefault,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _savingAddress = true);
    try {
      final client = ref.read(supabaseClientProvider);
      if (isDefault) {
        await client.from('addresses').update({'is_default': false}).eq('user_id', user.id);
      }
      final payload = <String, dynamic>{
        'user_id': user.id,
        'label': label,
        'address_line': addressLine,
        'city': city,
        'state': state,
        'pincode': pincode,
        'is_default': isDefault,
      };
      if (existing == null) {
        await client.from('addresses').insert(payload);
      } else {
        await client.from('addresses').update(payload).eq('id', existing['id']);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      await _loadAddresses();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Unable to save address.')));
    } finally {
      if (mounted) setState(() => _savingAddress = false);
    }
  }

  Future<void> _deleteAddress(String id) async {
    setState(() => _savingAddress = true);
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('addresses').delete().eq('id', id);
      await _loadAddresses();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Unable to delete address.')));
    } finally {
      if (mounted) setState(() => _savingAddress = false);
    }
  }

  Future<void> _setDefaultAddress(String id) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _savingAddress = true);
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('addresses').update({'is_default': false}).eq('user_id', user.id);
      await client.from('addresses').update({'is_default': true}).eq('id', id);
      await _loadAddresses();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Unable to update default address.')));
    } finally {
      if (mounted) setState(() => _savingAddress = false);
    }
  }

  Future<void> _openAddressSheet({Map<String, dynamic>? existing}) async {
    final addrFormKey = GlobalKey<FormState>();
    final labelCtrl = TextEditingController(text: existing?['label'] as String? ?? 'Home');
    final lineCtrl = TextEditingController(text: existing?['address_line'] as String? ?? '');
    final cityCtrl = TextEditingController(text: existing?['city'] as String? ?? '');
    final stateCtrl = TextEditingController(text: existing?['state'] as String? ?? '');
    final pinCtrl = TextEditingController(text: existing?['pincode'] as String? ?? '');
    var isDefault = existing?['is_default'] as bool? ?? _addresses.isEmpty;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 16,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: addrFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        existing == null ? 'Add Address' : 'Edit Address',
                        style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _addrField(labelCtrl, 'Label (Home / Office)', TextInputType.text,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Label is required' : null),
                      const SizedBox(height: 10),
                      _addrField(lineCtrl, 'Street Address', TextInputType.streetAddress,
                          maxLines: 2,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Address is required' : null),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: _addrField(cityCtrl, 'City', TextInputType.text,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Required' : null),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _addrField(stateCtrl, 'State', TextInputType.text,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Required' : null),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: pinCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 6,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'PIN code is required';
                          if (v.trim().length != 6) return 'Enter a valid 6-digit PIN code';
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'PIN Code',
                          counterText: '',
                          prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                      CheckboxListTile(
                        value: isDefault,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Set as default address'),
                        onChanged: (v) => setLocal(() => isDefault = v ?? false),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _savingAddress
                              ? null
                              : () {
                                  if (!(addrFormKey.currentState?.validate() ?? false)) return;
                                  _saveAddressRow(
                                    existing: existing,
                                    label: labelCtrl.text.trim(),
                                    addressLine: lineCtrl.text.trim(),
                                    city: cityCtrl.text.trim(),
                                    state: stateCtrl.text.trim(),
                                    pincode: pinCtrl.text.trim(),
                                    isDefault: isDefault,
                                  );
                                },
                          child: Text(existing == null ? 'Save Address' : 'Update Address'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    labelCtrl.dispose();
    lineCtrl.dispose();
    cityCtrl.dispose();
    stateCtrl.dispose();
    pinCtrl.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final avatarRequired = user?.role == UserRole.pandit;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Form(
        key: _profileFormKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            // ── Avatar ──────────────────────────────────────────────────────
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
                    child: (_avatarBytes == null && (_avatarUrl == null || _avatarUrl!.isEmpty))
                        ? const Icon(Icons.person, size: 48, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _savingProfile || _uploadingImage ? null : _pickAvatar,
                    icon: _uploadingImage
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.image_outlined),
                    label: Text(
                        avatarRequired ? 'Upload Profile Photo *' : 'Upload Profile Photo'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    avatarRequired
                        ? 'Profile photo is required for pandit accounts.'
                        : 'Profile photo is optional.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Full Name ────────────────────────────────────────────────────
            _sectionLabel('Full Name'),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              decoration: _decor('Your full name', Icons.person_outline),
            ),
            const SizedBox(height: 20),

            // ── Phone Number with country picker ─────────────────────────────
            _sectionLabel('Phone Number'),
            CountryPhoneFormField(
              controller: _phoneCtrl,
              country: _selectedCountry,
              onCountryTap: () => showCountryPicker(
                context: context,
                selected: _selectedCountry,
                onSelected: (c) => setState(() => _selectedCountry = c),
              ),
              decoration: _decor('98765 43210', Icons.phone_outlined),
            ),
            const SizedBox(height: 32),

            // ── Pandit-specific details ──────────────────────────────────────
            if (avatarRequired) ...[
              const SizedBox(height: 4),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'PANDIT DETAILS',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary, letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 16),

              if (_panditDetailsLoading)
                const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(),
                ))
              else ...[
                _sectionLabel('Bio / Description'),
                TextFormField(
                  controller: _bioCtrl,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Describe your experience, expertise…',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _sectionLabel('Years of Experience'),
                TextFormField(
                  controller: _expCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _decor('e.g. 10', Icons.workspace_premium_outlined),
                ),
                const SizedBox(height: 16),

                _sectionLabel('Specialties (comma-separated)'),
                TextFormField(
                  controller: _specialtiesCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decor(
                    'e.g. Satyanarayan Puja, Griha Pravesh',
                    Icons.star_outline,
                  ),
                ),
                const SizedBox(height: 16),

                _sectionLabel('Languages (comma-separated)'),
                TextFormField(
                  controller: _languagesCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decor(
                    'e.g. Hindi, Sanskrit, Telugu',
                    Icons.language,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],

            const SizedBox(height: 12),
            FilledButton(
              onPressed: _savingProfile ? null : _saveProfile,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _savingProfile
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Profile',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),

            const SizedBox(height: 36),
            const Divider(),
            const SizedBox(height: 16),

            // ── My Addresses ─────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'MY ADDRESSES',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary, letterSpacing: 0.8,
                  ),
                ),
                TextButton.icon(
                  onPressed: _savingAddress ? null : () => _openAddressSheet(),
                  icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                  label: const Text('Add New'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_addressLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_addressError != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_addressError!,
                    style: const TextStyle(color: AppColors.error)),
              )
            else if (_addresses.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text(
                    'No saved addresses yet.\nTap "Add New" to add your first address.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _addresses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final a = _addresses[i];
                  final isDef = a['is_default'] as bool? ?? false;
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDef
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : AppColors.border,
                      ),
                    ),
                    child: ListTile(
                      title: Row(children: [
                        Text(
                          a['label'] as String? ?? 'Address',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (isDef) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                fontSize: 11, color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ]),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${a['address_line'] ?? ''}, ${a['city'] ?? ''}, '
                          '${a['state'] ?? ''} - ${a['pincode'] ?? ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') {
                            await _openAddressSheet(existing: a);
                          } else if (v == 'default') {
                            await _setDefaultAddress(a['id'] as String);
                          } else if (v == 'delete') {
                            await _deleteAddress(a['id'] as String);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'default', child: Text('Set as default')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      );

  InputDecoration _decor(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textHint),
        filled: true,
        fillColor: Colors.white,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );

  TextFormField _addrField(
    TextEditingController ctrl,
    String label,
    TextInputType kbType, {
    int maxLines = 1,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: kbType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      );
}
