import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../../core/providers/supabase_provider.dart';
import '../../packages/models/package_model.dart';
import '../../packages/providers/packages_provider.dart';
import '../../payment/payment_provider.dart';
import '../../payment/payment_service.dart';
import '../../widgets/country_phone_field.dart';
import '../models/booking_model.dart';
import '../models/booking_status.dart';
import '../models/time_slot_model.dart';
import '../providers/booking_provider.dart';

// ── Entry Point ───────────────────────────────────────────────────────────────

class BookingWizardScreen extends ConsumerStatefulWidget {
  const BookingWizardScreen({super.key, this.preSelectedPackage});

  /// When launched from a package detail screen, this pre-fills step 0.
  final PackageModel? preSelectedPackage;

  @override
  ConsumerState<BookingWizardScreen> createState() =>
      _BookingWizardScreenState();
}

class _BookingWizardScreenState
    extends ConsumerState<BookingWizardScreen> {
  late final PageController _pageCtrl;
  PackageModel? get _pre => widget.preSelectedPackage;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    // If pre-selected, seed the controller
    if (_pre != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(bookingWizardProvider(_pre).notifier).selectPackage(_pre!);
      });
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _animateTo(int step) {
    _pageCtrl.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wz = ref.watch(bookingWizardProvider(_pre));

    // Keep PageView in sync with controller step
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageCtrl.hasClients &&
          _pageCtrl.page?.round() != wz.currentStep) {
        _animateTo(wz.currentStep);
      }
    });

    final stepLabels = _stepLabels(wz.draft.package?.mode);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          stepLabels[wz.currentStep],
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: wz.isFirstStep
            ? CloseButton(onPressed: () => context.pop())
            : BackButton(
                onPressed: () =>
                    ref.read(bookingWizardProvider(_pre).notifier).prevStep(),
              ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: _StepProgressBar(
            current: wz.currentStep,
            total: wz.totalSteps,
          ),
        ),
      ),
      body: Column(
        children: [
          // Error banner
          if (wz.error != null)
            _ErrorBanner(
              message: wz.error!,
              onDismiss: () =>
                  ref.read(bookingWizardProvider(_pre).notifier).clearError(),
            ),

          // Step pages
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(), // nav via controller
              children: [
                _StepPackage(pre: _pre),
                _StepDate(pre: _pre),
                _StepSlot(pre: _pre),
                _StepLocation(pre: _pre),
                _StepConfirm(pre: _pre),
                _StepPayment(pre: _pre),
              ],
            ),
          ),

          // Bottom navigation bar
          if (wz.currentStep < 4)
            _WizardBottomBar(pre: _pre),
        ],
      ),
    );
  }

  List<String> _stepLabels(PackageMode? mode) => [
        'Select Pooja',
        'Choose Date',
        'Choose Time',
        if (mode == PackageMode.online) 'Online Session' else 'Your Location',
        'Review & Confirm',
        'Payment',
      ];
}

// ── Bottom nav bar ────────────────────────────────────────────────────────────

class _WizardBottomBar extends ConsumerWidget {
  const _WizardBottomBar({required this.pre});
  final PackageModel? pre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wz = ref.watch(bookingWizardProvider(pre));
    final ctrl = ref.read(bookingWizardProvider(pre).notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            if (!wz.isFirstStep)
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: ctrl.prevStep,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Back'),
                ),
              ),
            if (!wz.isFirstStep) const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: FilledButton(
                onPressed: wz.currentStepValid ? ctrl.nextStep : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  wz.currentStep == 3 ? 'Review' : 'Continue',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────────

class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LinearProgressIndicator(
      value: (current + 1) / total,
      minHeight: 4,
      backgroundColor: cs.surfaceContainerHighest,
      valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.onErrorContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                color: Theme.of(context).colorScheme.onErrorContainer,
                size: 18),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// STEP 0 – Select Package
// ════════════════════════════════════════════════════════════════════════════════

class _StepPackage extends ConsumerWidget {
  const _StepPackage({required this.pre});
  final PackageModel? pre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wz = ref.watch(bookingWizardProvider(pre));
    final ctrl = ref.read(bookingWizardProvider(pre).notifier);
    final packagesAsync = ref.watch(packagesFetchProvider);

    return packagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Unable to load packages right now. Please try again.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (packages) {
        if (packages.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No packages are available yet. Please add packages in Supabase first.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: packages.length,
          itemBuilder: (_, i) {
            final pkg = packages[i];
            final selected = wz.draft.package?.id == pkg.id;
            return _PackageSelectTile(
              package: pkg,
              selected: selected,
              onTap: () => ctrl.selectPackage(pkg),
            );
          },
        );
      },
    );
  }
}

class _PackageSelectTile extends StatelessWidget {
  const _PackageSelectTile({
    required this.package,
    required this.selected,
    required this.onTap,
  });
  final PackageModel package;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      elevation: selected ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? cs.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected
                      ? cs.primaryContainer
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(package.category.icon,
                    color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(package.title,
                        style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700)),
                    Text(
                      '${package.durationLabel} · ${package.modeLabel}',
                      style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${package.effectivePrice.toStringAsFixed(0)}',
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle_rounded,
                        color: cs.primary, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// STEP 1 – Select Date
// ════════════════════════════════════════════════════════════════════════════════

class _StepDate extends ConsumerStatefulWidget {
  const _StepDate({required this.pre});
  final PackageModel? pre;

  @override
  ConsumerState<_StepDate> createState() => _StepDateState();
}

class _StepDateState extends ConsumerState<_StepDate> {
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final wz = ref.watch(bookingWizardProvider(widget.pre));
    final ctrl = ref.read(bookingWizardProvider(widget.pre).notifier);

    // Find the active wizard (family key could be any package)
    // We use null key because the wizard is driven by its own state
    final selected = wz.draft.date;
    final today = DateTime.now();
    final maxDate = today.add(const Duration(days: 90));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _MiniCalendar(
        focusedMonth: _focusedMonth,
        selectedDate: selected,
        minDate: today,
        maxDate: maxDate,
        onMonthChanged: (d) => setState(() => _focusedMonth = d),
        onDateSelected: (d) => ctrl.selectDate(d),
      ),
    );
  }
}

class _MiniCalendar extends StatelessWidget {
  const _MiniCalendar({
    required this.focusedMonth,
    required this.selectedDate,
    required this.minDate,
    required this.maxDate,
    required this.onMonthChanged,
    required this.onDateSelected,
  });

  final DateTime focusedMonth;
  final DateTime? selectedDate;
  final DateTime minDate;
  final DateTime maxDate;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    const weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0=Sun

    return Column(
      children: [
        // Month header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => onMonthChanged(DateTime(
                  focusedMonth.year, focusedMonth.month - 1)),
            ),
            Text(
              '${months[focusedMonth.month - 1]} ${focusedMonth.year}',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => onMonthChanged(DateTime(
                  focusedMonth.year, focusedMonth.month + 1)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Weekday labels
        Row(
          children: weekDays
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),

        // Day grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: startWeekday + daysInMonth,
          itemBuilder: (_, idx) {
            if (idx < startWeekday) return const SizedBox.shrink();
            final day = idx - startWeekday + 1;
            final date = DateTime(focusedMonth.year, focusedMonth.month, day);
            final disabled = date.isBefore(
                DateTime(minDate.year, minDate.month, minDate.day)) ||
                date.isAfter(maxDate);
            final isSelected = selectedDate != null &&
                date.year == selectedDate!.year &&
                date.month == selectedDate!.month &&
                date.day == selectedDate!.day;
            final isToday = date.year == DateTime.now().year &&
                date.month == DateTime.now().month &&
                date.day == DateTime.now().day;

            return GestureDetector(
              onTap: disabled ? null : () => onDateSelected(date),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? cs.primary
                      : isToday
                          ? cs.primaryContainer
                          : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: tt.bodySmall?.copyWith(
                      fontWeight:
                          isSelected || isToday ? FontWeight.w800 : null,
                      color: isSelected
                          ? cs.onPrimary
                          : isToday
                              ? cs.onPrimaryContainer
                              : disabled
                                  ? cs.onSurface.withAlpha(60)
                                  : cs.onSurface,
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        if (selectedDate != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.event_available_rounded,
                    color: cs.onPrimaryContainer),
                const SizedBox(width: 10),
                Text(
                  _fmt(selectedDate!),
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// STEP 2 – Select Time Slot
// ════════════════════════════════════════════════════════════════════════════════

class _StepSlot extends ConsumerWidget {
  const _StepSlot({required this.pre});
  final PackageModel? pre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wz = ref.watch(bookingWizardProvider(pre));
    final ctrl = ref.read(bookingWizardProvider(pre).notifier);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (wz.loadingSlots) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Available slots', style: tt.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Grey slots are already booked.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 3.2,
            ),
            itemCount: kStandardTimeSlots.length,
            itemBuilder: (_, i) {
              final slot = kStandardTimeSlots[i];
              final booked = wz.bookedSlotIds.contains(slot.id);
              final selected = wz.draft.slot?.id == slot.id;

              return _SlotChip(
                slot: slot,
                isBooked: booked,
                isSelected: selected,
                onTap: booked
                    ? null
                    : () => ctrl.selectSlot(slot),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _LegendDot(color: cs.primary, label: 'Selected'),
              const SizedBox(width: 20),
              _LegendDot(color: cs.surfaceContainerHighest, label: 'Available'),
              const SizedBox(width: 20),
              _LegendDot(color: Colors.grey[300]!, label: 'Booked'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.isBooked,
    required this.isSelected,
    required this.onTap,
  });
  final TimeSlot slot;
  final bool isBooked;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color bg;
    Color fg;
    if (isBooked) {
      bg = Colors.grey[200]!;
      fg = Colors.grey[400]!;
    } else if (isSelected) {
      bg = cs.primary;
      fg = cs.onPrimary;
    } else {
      bg = cs.surfaceContainerHighest;
      fg = cs.onSurface;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? null
              : Border.all(color: cs.outlineVariant, width: 0.5),
        ),
        child: Center(
          child: Text(
            isBooked ? '${slot.label}\nBooked' : slot.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// STEP 3 – Location
// ════════════════════════════════════════════════════════════════════════════════

class _StepLocation extends ConsumerStatefulWidget {
  const _StepLocation({required this.pre});
  final PackageModel? pre;

  @override
  ConsumerState<_StepLocation> createState() => _StepLocationState();
}

class _StepLocationState extends ConsumerState<_StepLocation> {
  final _addr1Ctrl   = TextEditingController();
  final _addr2Ctrl   = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _formKey     = GlobalKey<FormState>();
  CountryDialCode _selectedCountry = kCountryList.first; // default India +91
  bool _loadingAddress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromProfile());
  }

  Future<void> _prefillFromProfile() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Pre-fill phone from profile (strip dial code)
    if (_phoneCtrl.text.isEmpty && (user.phone ?? '').isNotEmpty) {
      final raw = user.phone!.replaceAll(RegExp(r'^\+\d{1,3}\s*'), '').trim();
      _phoneCtrl.text = raw;
    }

    setState(() => _loadingAddress = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final rows = await client
          .from('addresses')
          .select('*')
          .eq('user_id', user.id)
          .eq('is_default', true)
          .limit(1);
      if (!mounted) return;
      final list = List<Map<String, dynamic>>.from(rows as List);
      if (list.isNotEmpty) {
        final a = list.first;
        if (_addr1Ctrl.text.isEmpty) {
          _addr1Ctrl.text = a['address_line'] as String? ?? '';
        }
        if (_cityCtrl.text.isEmpty) {
          _cityCtrl.text = a['city'] as String? ?? '';
        }
        if (_pincodeCtrl.text.isEmpty) {
          _pincodeCtrl.text = a['pincode'] as String? ?? '';
        }
        // Trigger validation in wizard after pre-fill
        _save();
      }
    } catch (_) {
      // silently ignore – user can fill manually
    } finally {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  @override
  void dispose() {
    _addr1Ctrl.dispose();
    _addr2Ctrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(bookingWizardProvider(widget.pre).notifier).setLocation(
          BookingLocation(
            isOnline: false,
            addressLine1: _addr1Ctrl.text.trim(),
            addressLine2: _addr2Ctrl.text.trim().isEmpty
                ? null
                : _addr2Ctrl.text.trim(),
            city:         _cityCtrl.text.trim(),
            pincode:      _pincodeCtrl.text.trim(),
            contactPhone: _selectedCountry.dialCode + _phoneCtrl.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final wz = ref.watch(bookingWizardProvider(widget.pre));
    final cs = Theme.of(context).colorScheme;

    final isOnline = wz.draft.package?.mode == PackageMode.online;

    if (isOnline) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(Icons.videocam_rounded,
                      size: 56, color: cs.onPrimaryContainer),
                  const SizedBox(height: 16),
                  Text(
                    'Online Session',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A secure video meeting link will be shared with you via SMS and email once your booking is confirmed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: cs.onPrimaryContainer, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                ref.read(bookingWizardProvider(widget.pre).notifier).setLocation(
                      const BookingLocation(isOnline: true),
                    );
                ref.read(bookingWizardProvider(widget.pre).notifier).nextStep();
              },
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Got it, Continue'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      );
    }

    // Offline: address form
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        onChanged: _save,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Service Address',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'The pandit will visit this address.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (_loadingAddress) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 20),
            _AddressField(
              ctrl: _addr1Ctrl,
              label: 'House / Flat / Plot No.',
              hint: 'e.g. 42-B, Shanti Nagar',
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            _AddressField(
              ctrl: _addr2Ctrl,
              label: 'Street / Landmark (optional)',
              hint: 'e.g. Near Hanuman Mandir',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _AddressField(
                    ctrl: _cityCtrl,
                    label: 'City',
                    hint: 'e.g. Jaipur',
                    validator: (v) =>
                        (v?.trim().isEmpty ?? true) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _AddressField(
                    ctrl: _pincodeCtrl,
                    label: 'Pincode',
                    hint: '110001',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: (v) {
                      if (v?.trim().isEmpty ?? true) return 'Required';
                      if ((v?.length ?? 0) < 6) return '6 digits';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Contact Number',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Who should the pandit contact for this booking?',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            CountryPhoneFormField(
              controller: _phoneCtrl,
              country: _selectedCountry,
              onCountryTap: () => showCountryPicker(
                context: context,
                selected: _selectedCountry,
                onSelected: (c) => setState(() {
                  _selectedCountry = c;
                  _save();
                }),
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: cs.outline),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressField extends StatelessWidget {
  const _AddressField({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
  });
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// STEP 4 – Confirm
// ════════════════════════════════════════════════════════════════════════════════

class _StepConfirm extends ConsumerWidget {
  const _StepConfirm({required this.pre});
  final PackageModel? pre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wz = ref.watch(bookingWizardProvider(pre));
    final paymentState = ref.watch(paymentProvider);
    final ctrl = ref.read(bookingWizardProvider(pre).notifier);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final draft = wz.draft;
    if (!draft.readyToConfirm) {
      return const Center(child: Text('Please complete all previous steps.'));
    }

    final pkg = draft.package!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withAlpha(180)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(pkg.category.icon, color: Colors.white, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pkg.title,
                          style: tt.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                      Text(pkg.category.label,
                          style: TextStyle(
                              color: Colors.white.withAlpha(200),
                              fontSize: 12)),
                    ],
                  ),
                ),
                Text(
                  '₹${pkg.effectivePrice.toStringAsFixed(0)}',
                  style: tt.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Detail rows
          _ConfirmSection(
            title: 'Date & Time',
            icon: Icons.event_rounded,
            content: '${draft.date != null ? _fmtDate(draft.date!) : ''}\n${draft.slot?.label ?? ''}',
          ),
          const SizedBox(height: 10),
          _ConfirmSection(
            title: draft.location?.isOnline ?? true
                ? 'Mode'
                : 'Location',
            icon: draft.location?.isOnline ?? true
                ? Icons.videocam_rounded
                : Icons.location_on_rounded,
            content: draft.location?.isOnline ?? true
                ? 'Online — meeting link shared after confirmation'
                : draft.location?.displayAddress ?? '',
          ),
          const SizedBox(height: 10),
          _ConfirmSection(
            title: 'Pandit Assignment',
            icon: Icons.person_rounded,
            content: 'A qualified pandit will be assigned by our team 24 hours before your booking.',
          ),
          const SizedBox(height: 10),
          _ConfirmSection(
            title: 'Duration',
            icon: Icons.schedule_rounded,
            content: pkg.durationLabel,
          ),
          const SizedBox(height: 24),

          // Pricing breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _PriceRow('Package price',
                    '₹${pkg.price.toStringAsFixed(0)}'),
                if (pkg.hasDiscount)
                  _PriceRow(
                    'Discount (${pkg.discountPercent}% off)',
                    '−₹${(pkg.price - pkg.effectivePrice).toStringAsFixed(0)}',
                    color: Colors.green[700],
                  ),
                const Divider(height: 16),
                _PriceRow(
                  'Total Payable',
                  '₹${pkg.effectivePrice.toStringAsFixed(0)}',
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Confirm button
          FilledButton(
            onPressed: wz.submitting || paymentState.isProcessing
                ? null
                : () async {
                    final user = ref.read(currentUserProvider);
                    if (user == null || user.id.isEmpty) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please sign in to continue.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    final draft = wz.draft;
                    final appOrderId =
                        'bk_${DateTime.now().millisecondsSinceEpoch}';
                    final paymentResult = await ref
                        .read(paymentProvider.notifier)
                        .pay(
                          PaymentRequest(
                            orderId: appOrderId,
                            amountPaise: (pkg.effectivePrice * 100).round(),
                            description:
                                '${pkg.title} on ${draft.date != null ? _fmtDate(draft.date!) : ''}',
                            customerName: user.name,
                            customerEmail: user.email,
                            customerPhone:
                                draft.location?.contactPhone ?? (user.phone ?? ''),
                            metadata: {
                              'booking_mode': 'pooja_booking',
                              'package_id': pkg.id,
                              if (draft.date != null)
                                'booking_date':
                                    draft.date!.toIso8601String(),
                            },
                          ),
                        );

                    if (!context.mounted) return;
                    if (!paymentResult.isSuccess) {
                      if (paymentResult.status != PaymentStatus.cancelled) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              paymentResult.errorMessage ??
                                  'Payment failed. Please try again.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                      return;
                    }

                    await ctrl.submitBooking(
                      user.id,
                      isPaid: true,
                      paymentId: paymentResult.providerPaymentId ??
                          paymentResult.transactionId ??
                          appOrderId,
                    );
                  },
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: (wz.submitting || paymentState.isProcessing)
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Text(
                    'Confirm & Pay  ₹${pkg.effectivePrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            'Payment is processed securely before your booking is confirmed.',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _ConfirmSection extends StatelessWidget {
  const _ConfirmSection(
      {required this.title,
      required this.icon,
      required this.content});
  final String title;
  final IconData icon;
  final String content;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: cs.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600)),
              Text(content,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow(this.label, this.value, {this.color, this.bold = false});
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 16 : 14,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// STEP 5 – Confirmation
// ════════════════════════════════════════════════════════════════════════════════

class _StepPayment extends ConsumerWidget {
  const _StepPayment({required this.pre});
  final PackageModel? pre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wz = ref.watch(bookingWizardProvider(pre));
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final booking = wz.completedBooking;
    if (booking == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withAlpha(30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF10B981), width: 1.5),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 64, color: Color(0xFF10B981)),
                const SizedBox(height: 12),
                Text('Booking Confirmed!',
                    style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF065F46))),
                const SizedBox(height: 6),
                Text(
                  'Payment received and booking created successfully.',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  'Booking ID: ${booking.id}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                _StatusBadge(status: booking.status),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _ConfirmSection(
            title: 'Schedule',
            icon: Icons.event_rounded,
            content:
                '${_StepConfirm._fmtDate(booking.date)}\n${booking.slot.label}',
          ),
          const SizedBox(height: 10),
          _ConfirmSection(
            title: booking.location.isOnline ? 'Mode' : 'Location',
            icon: booking.location.isOnline
                ? Icons.videocam_rounded
                : Icons.location_on_rounded,
            content: booking.location.isOnline
                ? 'Online session. Meeting details will be shared by the team.'
                : booking.location.displayAddress,
          ),
          const SizedBox(height: 10),
          _ConfirmSection(
            title: 'Payment',
            icon: Icons.verified_rounded,
            content:
                '₹${booking.amount.toStringAsFixed(0)} paid via Razorpay\nPayment ID: ${booking.paymentId ?? 'Not available'}',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go('/account'),
            icon: const Icon(Icons.home_rounded),
            label: const Text('Go to My Bookings',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () =>
                ref.read(bookingWizardProvider(pre).notifier).reset(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Book Another Pooja'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: status.color),
          const SizedBox(width: 5),
          Text(status.label,
              style: TextStyle(
                  color: status.color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ],
      ),
    );
  }
}

