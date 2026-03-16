import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';

class ManageAddressesScreen extends ConsumerStatefulWidget {
  const ManageAddressesScreen({super.key});

  @override
  ConsumerState<ManageAddressesScreen> createState() =>
      _ManageAddressesScreenState();
}

class _ManageAddressesScreenState extends ConsumerState<ManageAddressesScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _addresses = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadAddresses);
  }

  Future<void> _loadAddresses() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Please sign in to manage addresses.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final rows = await client
          .from('addresses')
          .select('*')
          .eq('user_id', user.id)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      setState(() {
        _addresses = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    } on PostgrestException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Failed to load addresses. Please try again.';
      });
    }
  }

  Future<void> _saveAddress({
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

    setState(() => _saving = true);

    try {
      final client = ref.read(supabaseClientProvider);

      if (isDefault) {
        await client
            .from('addresses')
            .update({'is_default': false})
            .eq('user_id', user.id);
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
        ..showSnackBar(
          const SnackBar(content: Text('Unable to save address. Please try again.')),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAddress(String id) async {
    setState(() => _saving = true);
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
        ..showSnackBar(
          const SnackBar(content: Text('Unable to delete address.')),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setDefault(String id) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      await client
          .from('addresses')
          .update({'is_default': false})
          .eq('user_id', user.id);
      await client.from('addresses').update({'is_default': true}).eq('id', id);
      await _loadAddresses();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Unable to update default address.')),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openAddressSheet({Map<String, dynamic>? existing}) async {
    final labelCtrl = TextEditingController(text: existing?['label'] as String? ?? 'Home');
    final lineCtrl =
        TextEditingController(text: existing?['address_line'] as String? ?? '');
    final cityCtrl = TextEditingController(text: existing?['city'] as String? ?? '');
    final stateCtrl =
        TextEditingController(text: existing?['state'] as String? ?? '');
    final pinCtrl =
        TextEditingController(text: existing?['pincode'] as String? ?? '');
    var isDefault = existing?['is_default'] as bool? ?? _addresses.isEmpty;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      existing == null ? 'Add Address' : 'Edit Address',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _AddressInput(controller: labelCtrl, label: 'Label (Home/Office)'),
                    const SizedBox(height: 10),
                    _AddressInput(controller: lineCtrl, label: 'Address Line', maxLines: 2),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _AddressInput(controller: cityCtrl, label: 'City'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _AddressInput(controller: stateCtrl, label: 'State'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _AddressInput(
                      controller: pinCtrl,
                      label: 'Pincode',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: isDefault,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Set as default address'),
                      onChanged: (v) => setLocalState(() => isDefault = v ?? false),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving
                            ? null
                            : () {
                                if (labelCtrl.text.trim().isEmpty ||
                                    lineCtrl.text.trim().isEmpty ||
                                    cityCtrl.text.trim().isEmpty ||
                                    stateCtrl.text.trim().isEmpty ||
                                    pinCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      const SnackBar(content: Text('Please fill all address fields.')),
                                    );
                                  return;
                                }
                                _saveAddress(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Addresses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _openAddressSheet(),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add Address'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                )
              : _addresses.isEmpty
                  ? const Center(
                      child: Text('No saved addresses yet. Add your first address.'),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAddresses,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                        itemCount: _addresses.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final a = _addresses[i];
                          final isDefault = a['is_default'] as bool? ?? false;
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDefault
                                    ? AppColors.primary.withValues(alpha: 0.5)
                                    : AppColors.border,
                              ),
                            ),
                            child: ListTile(
                              title: Row(
                                children: [
                                  Text(
                                    (a['label'] as String? ?? 'Address'),
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  if (isDefault) ...[
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
                                          fontSize: 11,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '${a['address_line'] ?? ''}, ${a['city'] ?? ''}, ${a['state'] ?? ''} - ${a['pincode'] ?? ''}',
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await _openAddressSheet(existing: a);
                                  } else if (value == 'default') {
                                    await _setDefault(a['id'] as String);
                                  } else if (value == 'delete') {
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
                    ),
    );
  }
}

class _AddressInput extends StatelessWidget {
  const _AddressInput({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
