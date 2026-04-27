import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../providers/support_provider.dart';

class HelpFormScreen extends ConsumerStatefulWidget {
  const HelpFormScreen({super.key});

  @override
  ConsumerState<HelpFormScreen> createState() => _HelpFormScreenState();
}

class _HelpFormScreenState extends ConsumerState<HelpFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _problemCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _problemCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      await ref.read(supportRepositoryProvider).submitTicket(
            requesterId: user.id,
            requesterRole: user.role.name,
            requesterName: user.name,
            phone: _phoneCtrl.text,
            problem: _problemCtrl.text,
          );

      ref.invalidate(mySupportTicketsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Help request submitted successfully.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit request: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user != null && _phoneCtrl.text.isEmpty && (user.phone ?? '').isNotEmpty) {
      _phoneCtrl.text = user.phone!;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Describe your issue clearly. Admin can update status as submitted, processing, completed, or rejected.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact Number',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final v = (value ?? '').trim();
                      if (v.length < 7 || v.length > 20) {
                        return 'Enter a valid number.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _problemCtrl,
                    minLines: 5,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Problem Description',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final v = (value ?? '').trim();
                      if (v.length < 10) return 'Please provide at least 10 characters.';
                      if (v.length > 2000) return 'Please keep it under 2000 characters.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Submit to Admin'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Consumer(
            builder: (context, ref, _) {
              ref.listen(supportRealtimeTickProvider, (_, __) {
                ref.invalidate(mySupportTicketsProvider);
              });
              final async = ref.watch(mySupportTicketsProvider);
              return async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const SizedBox.shrink(),
                data: (tickets) {
                  if (tickets.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('My Recent Help Requests', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...tickets.take(5).map((t) => ListTile(
                            tileColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            title: Text(t.problem, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('Status: ${t.statusLabel}'),
                            trailing: Text('${t.createdAt.day}/${t.createdAt.month}'),
                          )),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
