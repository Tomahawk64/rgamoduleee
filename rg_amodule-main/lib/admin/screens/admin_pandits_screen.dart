// lib/admin/screens/admin_pandits_screen.dart
// Manage pandits, toggle active/consultation, set pricing per pandit.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../models/admin_models.dart';
import '../providers/admin_providers.dart';

class AdminPanditsScreen extends ConsumerStatefulWidget {
  const AdminPanditsScreen({super.key});

  @override
  ConsumerState<AdminPanditsScreen> createState() =>
      _AdminPanditsScreenState();
}

class _AdminPanditsScreenState
    extends ConsumerState<AdminPanditsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    final pandits = state.pandits
        .where((p) =>
            _search.isEmpty ||
            p.name.toLowerCase().contains(_search.toLowerCase()) ||
            p.specialties.any((s) =>
                s.toLowerCase().contains(_search.toLowerCase())))
        .toList();

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
        title: const Text('Manage Pandits',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search pandits…',
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
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _PillChip(
                    label:
                        '${state.pandits.where((p) => p.isActive).length} Active',
                    color: AppColors.success),
                const SizedBox(width: 8),
                _PillChip(
                    label:
                        '${state.pandits.where((p) => p.consultationEnabled).length} Consultation On',
                    color: AppColors.info),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              separatorBuilder: (_, _) =>
                  const SizedBox(height: 10),
              itemCount: pandits.length,
              itemBuilder: (_, i) => _PanditCard(
                pandit: pandits[i],
                onToggleActive: (v) =>
                    ref.read(adminProvider.notifier).togglePandit(
                          pandits[i].id,
                          isActive: v,
                        ),
                onToggleConsultation: (v) => ref
                    .read(adminProvider.notifier)
                    .toggleConsultation(pandits[i].id, enabled: v),
                onEditPricing: () =>
                    _showPricingSheet(context, ref, pandits[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPricingSheet(
      BuildContext context, WidgetRef ref, AdminPandit pandit) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PricingSheet(
        pandit: pandit,
        onSave: (rates) => ref
            .read(adminProvider.notifier)
            .updateConsultationRates(pandit.id, rates),
      ),
    );
  }
}

// ── Pandit card ───────────────────────────────────────────────────────────────

class _PanditCard extends StatelessWidget {
  const _PanditCard({
    required this.pandit,
    required this.onToggleActive,
    required this.onToggleConsultation,
    required this.onEditPricing,
  });

  final AdminPandit pandit;
  final ValueChanged<bool> onToggleActive;
  final ValueChanged<bool> onToggleConsultation;
  final VoidCallback onEditPricing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: pandit.isActive
                ? AppColors.divider
                : AppColors.warning.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    AppColors.secondary.withValues(alpha: 0.15),
                child: Text(
                  pandit.initials,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pandit.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      pandit.specialties.take(2).join(' · '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Active toggle
              Column(
                children: [
                  const Text('Active',
                      style: TextStyle(
                          fontSize: 9, color: AppColors.textSecondary)),
                  Switch(
                    value: pandit.isActive,
                    onChanged: onToggleActive,
                    activeThumbColor: AppColors.success,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Stats row
          Row(
            children: [
              _StatBadge(
                icon: Icons.star,
                label: '${pandit.rating}',
                color: Colors.amber,
              ),
              const SizedBox(width: 8),
              _StatBadge(
                icon: Icons.calendar_today,
                label: '${pandit.totalBookings} bookings',
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              _StatBadge(
                icon: Icons.videocam,
                label: '${pandit.totalSessions} sessions',
                color: AppColors.info,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),

          // Consultation row
          Row(
            children: [
              const Icon(Icons.videocam_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Online Consultations',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              Switch(
                value: pandit.consultationEnabled,
                onChanged: onToggleConsultation,
                activeThumbColor: AppColors.info,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 8),
              if (pandit.consultationEnabled || pandit.consultationRates.isNotEmpty)
                TextButton.icon(
                  onPressed: onEditPricing,
                  icon: const Icon(Icons.edit, size: 12),
                  label: const Text('Pricing',
                      style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.secondary,
                  ),
                ),
            ],
          ),

          // Current pricing summary
          if (pandit.consultationRates.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: pandit.consultationRates
                  .map((r) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          r.label,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.info),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Pricing sheet ─────────────────────────────────────────────────────────────

class _PricingSheet extends StatefulWidget {
  const _PricingSheet({required this.pandit, required this.onSave});
  final AdminPandit pandit;
  final ValueChanged<List<AdminRate>> onSave;

  @override
  State<_PricingSheet> createState() => _PricingSheetState();
}

class _PricingSheetState extends State<_PricingSheet> {
  late final List<AdminRate> _rates;

  @override
  void initState() {
    super.initState();
    _rates = List.from(widget.pandit.consultationRates);
    if (_rates.isEmpty) {
      _rates.addAll([
        const AdminRate(durationMinutes: 10, pricePaise: 25000),
        const AdminRate(durationMinutes: 15, pricePaise: 35000),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Consultation Pricing\n${widget.pandit.name}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Configure consultation rate tiers for this pandit.',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ...List.generate(
              _rates.length,
              (i) => _RateTile(
                rate: _rates[i],
                onDurationChanged: (v) =>
                    setState(() => _rates[i] = _rates[i].copyWith(
                          durationMinutes:
                              int.tryParse(v) ?? _rates[i].durationMinutes,
                        )),
                onPriceChanged: (v) =>
                    setState(() => _rates[i] = _rates[i].copyWith(
                          pricePaise: ((double.tryParse(v) ?? 0) * 100)
                              .toInt(),
                        )),
                onRemove:
                    _rates.length > 1 ? () => setState(() => _rates.removeAt(i)) : null,
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _rates.length < 5
                  ? () => setState(() => _rates.add(
                        const AdminRate(
                            durationMinutes: 10, pricePaise: 20000),
                      ))
                  : null,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add tier'),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  widget.onSave(_rates);
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Pricing'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RateTile extends StatelessWidget {
  const _RateTile({
    required this.rate,
    required this.onDurationChanged,
    required this.onPriceChanged,
    this.onRemove,
  });

  final AdminRate rate;
  final ValueChanged<String> onDurationChanged;
  final ValueChanged<String> onPriceChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: '${rate.durationMinutes}',
              keyboardType: TextInputType.number,
              onChanged: onDurationChanged,
              decoration: const InputDecoration(
                labelText: 'Duration (min)',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              initialValue: rate.priceRupees.toStringAsFixed(0),
              keyboardType: TextInputType.number,
              onChanged: onPriceChanged,
              decoration: const InputDecoration(
                labelText: 'Price (₹)',
                prefixText: '₹ ',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                color: AppColors.error),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

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

class _StatBadge extends StatelessWidget {
  const _StatBadge(
      {required this.icon,
      required this.label,
      required this.color});
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
