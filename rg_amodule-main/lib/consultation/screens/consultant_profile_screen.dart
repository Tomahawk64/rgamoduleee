import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../payment/payment_provider.dart';
import '../../payment/payment_service.dart';
import '../models/pandit_model.dart';
import '../providers/consultation_provider.dart';

class ConsultantProfileScreen extends ConsumerStatefulWidget {
  const ConsultantProfileScreen({super.key, required this.panditId});

  final String panditId;

  @override
  ConsumerState<ConsultantProfileScreen> createState() =>
      _ConsultantProfileScreenState();
}

class _ConsultantProfileScreenState
    extends ConsumerState<ConsultantProfileScreen> {
  DateTime? _scheduledDateTime;
  final _notesCtrl = TextEditingController();
  bool _processing = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final panditsState = ref.watch(panditsProvider);
    final pandit = panditsState.pandits
        .where((p) => p.id == widget.panditId)
        .cast<PanditModel?>()
        .firstOrNull;

    if (panditsState.loading && pandit == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (panditsState.error != null && pandit == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(panditsState.error!)),
      );
    }
    if (pandit == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Consultant not found')),
      );
    }
    final selectedRate = _live10MinuteRate(pandit);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Consultant Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeader(pandit: pandit),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'About',
            child: Text(
              pandit.bio ??
                  'Certified consultation pandit available for live chat guidance.',
              style: const TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Consultation Duration',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${selectedRate.duration} min consultation',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Live consultation duration is fixed to 10 minutes.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    selectedRate.priceLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Schedule Consultation',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _scheduledDateTime == null
                      ? 'No slot selected yet. Pick date and time to send consultation request.'
                      : 'Scheduled for ${_formatDateTime(_scheduledDateTime!)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickSchedule,
                      icon: const Icon(Icons.schedule_rounded),
                      label: const Text('Pick Date & Time'),
                    ),
                    if (_scheduledDateTime != null)
                      TextButton(
                        onPressed: () => setState(() => _scheduledDateTime = null),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes for pandit (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pandits will review your requested slot and either accept it or propose a new time.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _processing
                ? null
                : () => _payAndSchedule(context, pandit),
            icon: const Icon(Icons.event_available_rounded),
            label: Text('Pay ${selectedRate.priceLabel} & Schedule'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      initialDate: _scheduledDateTime ?? now,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledDateTime ?? now),
    );
    if (time == null) return;

    setState(() {
      _scheduledDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _payAndSchedule(BuildContext context, PanditModel pandit) async {
    final user = ref.read(currentUserProvider);
    final rate = _live10MinuteRate(pandit);
    if (user == null) {
      context.go(Routes.login);
      return;
    }
    if (_scheduledDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a date and time first.')),
      );
      return;
    }

    final repo = ref.read(sessionRepositoryProvider);

    setState(() => _processing = true);
    final orderId = 'cons_sched_${DateTime.now().millisecondsSinceEpoch}';
    try {
      final payment = await ref.read(paymentProvider.notifier).pay(
            PaymentRequest(
              orderId: orderId,
              amountPaise: rate.totalPaise,
              description: 'Scheduled consultation with ${pandit.name}',
              customerName: user.name,
              customerEmail: user.email,
              customerPhone: user.phone ?? '',
              metadata: {
                'mode': 'scheduled_consultation',
                'pandit_id': pandit.id,
                'scheduled_for': _scheduledDateTime!.toIso8601String(),
              },
            ),
          );
      if (!payment.isSuccess) return;

      await repo.requestScheduledSession(
            pandit: pandit,
            rate: rate,
            userId: user.id,
            userName: user.name,
            scheduledFor: _scheduledDateTime!,
            isPaid: true,
            paymentId: payment.providerPaymentId ?? payment.transactionId,
            customerNote: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Consultation request sent. Track it in My Consultations.'),
        ),
      );
      context.go(Routes.consultationRequests);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  static String _formatDateTime(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m $p';
  }

  ConsultationRate _live10MinuteRate(PanditModel pandit) {
    final exact = pandit.rates.where((r) => r.duration == 10).firstOrNull;
    if (exact != null) return exact;

    final first = pandit.rates.firstOrNull;
    if (first == null) {
      return const ConsultationRate(duration: 10, totalPaise: 9900);
    }

    final perMinutePaise = (first.totalPaise / first.duration).round();
    return ConsultationRate(duration: 10, totalPaise: perMinutePaise * 10);
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.pandit});
  final PanditModel pandit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          backgroundImage: _avatarProvider(pandit.avatarUrl),
          child: _avatarProvider(pandit.avatarUrl) != null
                ? null
                : Text(
                    pandit.initials,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 22),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pandit.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  pandit.specialty,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _MetaPill(icon: Icons.star, text: pandit.rating.toStringAsFixed(1)),
                    _MetaPill(icon: Icons.chat_rounded, text: '${pandit.totalSessions} sessions'),
                    _MetaPill(icon: Icons.workspace_premium_rounded, text: '${pandit.experienceYears}y exp'),
                    _MetaPill(
                      icon: pandit.isOnline ? Icons.circle : Icons.access_time_rounded,
                      text: pandit.isOnline ? 'Online now' : 'Offline',
                      color: pandit.isOnline ? AppColors.success : AppColors.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider<Object>? _avatarProvider(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    if (avatarUrl.startsWith('assets/')) return AssetImage(avatarUrl);
    if (avatarUrl.startsWith('http')) return NetworkImage(avatarUrl);
    return null;
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
