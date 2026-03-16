// lib/special_poojas/screens/special_pooja_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../booking/providers/booking_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/role_enum.dart';
import '../../payment/payment_provider.dart';
import '../../payment/payment_service.dart';
import '../models/special_pooja_model.dart';
import '../providers/special_poojas_provider.dart';

class SpecialPoojaDetailScreen extends ConsumerStatefulWidget {
  const SpecialPoojaDetailScreen({super.key, required this.poojaId});

  final String poojaId;

  @override
  ConsumerState<SpecialPoojaDetailScreen> createState() =>
      _SpecialPoojaDetailScreenState();
}

class _SpecialPoojaDetailScreenState
    extends ConsumerState<SpecialPoojaDetailScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final pooja = ref.watch(specialPoojaByIdProvider(widget.poojaId));

    if (pooja == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pooja Details')),
        body: const Center(child: Text('Pooja not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Hero SliverAppBar ─────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.secondary,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.secondary, AppColors.primary],
                  ),
                ),
                child: Stack(
                  children: [
                    // Full-bleed image if available
                    if ((pooja.imageUrl ?? '').trim().isNotEmpty)
                      Positioned.fill(
                        child: pooja.imageUrl!.startsWith('assets/')
                            ? Image.asset(
                                pooja.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.temple_hindu,
                                    color: Colors.white70,
                                    size: 64,
                                  ),
                                ),
                              )
                            : Image.network(
                                pooja.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.temple_hindu,
                                    color: Colors.white70,
                                    size: 64,
                                  ),
                                ),
                              ),
                      )
                    else
                      // Large background icon fallback
                      Positioned(
                        right: -30,
                        bottom: -30,
                        child: Opacity(
                          opacity: 0.1,
                          child: const Icon(
                            Icons.temple_hindu,
                            size: 200,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    // Dark scrim for text legibility
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black54,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (pooja.templeName != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                pooja.templeName!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            pooja.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                // ── Quick stats ──────────────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _QuickStat(
                        icon: Icons.schedule,
                        label: pooja.durationLabel,
                        sublabel: 'Duration',
                        color: AppColors.primary,
                      ),
                      _Divider(),
                      _QuickStat(
                        icon: Icons.currency_rupee,
                        label: pooja.price.toStringAsFixed(0),
                        sublabel: 'Starting price',
                        color: AppColors.secondary,
                      ),
                      _Divider(),
                      _QuickStat(
                        icon: Icons.location_on,
                        label: 'Online',
                        sublabel: 'Streaming',
                        color: Colors.green,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── About ────────────────────────────────────────────────
                _Section(
                  title: 'About This Ritual',
                  child: Text(
                    pooja.description,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),
                ),

                // ── Significance ─────────────────────────────────────────
                if (pooja.significance != null)
                  _Section(
                    title: 'Spiritual Significance',
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.secondary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.menu_book,
                              color: AppColors.secondary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              pooja.significance!,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── What's Included ──────────────────────────────────────
                if (pooja.includes.isNotEmpty)
                  _Section(
                    title: "What's Included",
                    child: Column(
                      children: pooja.includes
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check,
                                        size: 12, color: Colors.green),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),

                // ── Location ─────────────────────────────────────────────
                if (pooja.location != null)
                  _Section(
                    title: 'Temple Location',
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.location_on,
                                color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pooja.location!.fullAddress,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                _Section(
                  title: 'How Online Pooja Works',
                  child: const Column(
                    children: [
                      _ProcessStep(
                        number: '1',
                        title: 'Choose the ritual date',
                        subtitle: 'Book your pooja online for the temple date you want.',
                      ),
                      SizedBox(height: 10),
                      _ProcessStep(
                        number: '2',
                        title: 'Pay securely',
                        subtitle: 'Your booking is confirmed only after payment succeeds.',
                      ),
                      SizedBox(height: 10),
                      _ProcessStep(
                        number: '3',
                        title: 'Our team oversees the booking and updates status',
                        subtitle: 'Our admin team manually verifies, schedules, and progresses the pooja.',
                      ),
                      SizedBox(height: 10),
                      _ProcessStep(
                        number: '4',
                        title: 'Receive video proof after completion',
                        subtitle: 'Once the pooja is completed, you can view and download the uploaded video proof from your booking.',
                      ),
                    ],
                  ),
                ),

                // ── Availability Calendar ────────────────────────────────
                _Section(
                  title: 'Select Date',
                  child: TableCalendar(
                    firstDay: DateTime.now(),
                    lastDay: pooja.availableUntil ??
                        DateTime.now().add(const Duration(days: 365)),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) =>
                        isSameDay(_selectedDay, day),
                    onDaySelected: (selected, focused) {
                      setState(() {
                        _selectedDay = selected;
                        _focusedDay = focused;
                      });
                    },
                    calendarStyle: CalendarStyle(
                      selectedDecoration: BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle:
                          const TextStyle(color: Colors.white),
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ),

                // Booking CTA spacer
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),

      // ── Sticky Book CTA ───────────────────────────────────────────────
      bottomNavigationBar: _BookingCTA(
        pooja: pooja,
        selectedDay: _selectedDay,
        onBook: _selectedDay == null
            ? null
            : () => _openBookingSheet(context, pooja, _selectedDay!),
      ),
    );
  }

  void _openBookingSheet(
    BuildContext context,
    SpecialPoojaModel pooja,
    DateTime selectedDay,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SpecialPoojaBookingSheet(
        pooja: pooja,
        selectedDay: selectedDay,
      ),
    );
  }
}

// ── Divider helper ────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        width: 1,
        color: Colors.grey.shade200,
      );
}

// ── Quick stat ────────────────────────────────────────────────────────────────

class _QuickStat extends StatelessWidget {
  const _QuickStat({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        Text(
          sublabel,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

class _ProcessStep extends StatelessWidget {
  const _ProcessStep({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: AppColors.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── Booking CTA ───────────────────────────────────────────────────────────────

class _BookingCTA extends StatelessWidget {
  const _BookingCTA({
    required this.pooja,
    required this.selectedDay,
    required this.onBook,
  });

  final SpecialPoojaModel pooja;
  final DateTime? selectedDay;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Price',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                pooja.priceLabel,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: onBook,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                selectedDay == null ? 'Select a Date First' : 'Book This Pooja',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecialPoojaBookingSheet extends ConsumerStatefulWidget {
  const _SpecialPoojaBookingSheet({
    required this.pooja,
    required this.selectedDay,
  });

  final SpecialPoojaModel pooja;
  final DateTime selectedDay;

  @override
  ConsumerState<_SpecialPoojaBookingSheet> createState() =>
      _SpecialPoojaBookingSheetState();
}

class _SpecialPoojaBookingSheetState
    extends ConsumerState<_SpecialPoojaBookingSheet> {
  late final TextEditingController _devoteeNameController;
  late final TextEditingController _gotraController;
  late final TextEditingController _sankalpController;
  late final TextEditingController _notesController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _devoteeNameController = TextEditingController(text: user?.name ?? '');
    _gotraController = TextEditingController();
    _sankalpController = TextEditingController();
    _notesController = TextEditingController();
    ref.read(paymentProvider.notifier).reset();
  }

  @override
  void dispose() {
    _devoteeNameController.dispose();
    _gotraController.dispose();
    _sankalpController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentProvider);
    final user = ref.watch(currentUserProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Book Online Pooja',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Pay now. Our team will oversee the request, update the status accordingly, and upload video proof after completion.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.pooja.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _CheckoutRow(
                      label: 'Temple',
                      value: widget.pooja.templeName ?? 'Temple-managed livestream',
                    ),
                    _CheckoutRow(
                      label: 'Date',
                      value: _formatDate(widget.selectedDay),
                    ),
                    _CheckoutRow(
                      label: 'Mode',
                      value: 'Online pooja with proof delivery',
                    ),
                    _CheckoutRow(
                      label: 'Amount',
                      value: widget.pooja.priceLabel,
                      highlight: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _devoteeNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Devotee Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _gotraController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Gotra',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sankalpController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Sankalp / Prayer Intention',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What happens after payment',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your booking goes to admin for manual review. Status updates appear under My Bookings, and the completion video proof becomes available there after the ritual is done.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (paymentState.isFailed && paymentState.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  paymentState.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _submitting || paymentState.isProcessing
                    ? null
                    : () => _payAndBook(context, user),
                icon: paymentState.isProcessing || _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_rounded),
                label: Text(
                  paymentState.isProcessing || _submitting
                      ? 'Processing…'
                      : 'Pay ${widget.pooja.priceLabel} & Book',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: AppColors.secondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _payAndBook(BuildContext context, UserModel? user) async {
    if (_devoteeNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the devotee name.')),
      );
      return;
    }
    if (user == null || user.role == UserRole.guest) {
      if (context.mounted) {
        Navigator.of(context).pop();
        context.go(Routes.login);
      }
      return;
    }

    setState(() => _submitting = true);
    ref.read(paymentProvider.notifier).reset();
    final orderId =
        'sp_${widget.pooja.id}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final paymentResult = await ref.read(paymentProvider.notifier).pay(
            PaymentRequest(
              orderId: orderId,
              amountPaise: (widget.pooja.price * 100).round(),
              description:
                  '${widget.pooja.title} on ${_formatDate(widget.selectedDay)}',
              customerName: user.name,
              customerEmail: user.email,
              customerPhone: user.phone ?? '',
              metadata: {
                'special_pooja_id': widget.pooja.id,
                'booking_date': widget.selectedDay.toIso8601String(),
              },
            ),
          );

      if (!paymentResult.isSuccess) {
        return;
      }

      final booking = await ref.read(bookingRepositoryProvider).createSpecialPoojaBooking(
            pooja: widget.pooja,
            date: widget.selectedDay,
            userId: user.id,
            paymentId: paymentResult.providerPaymentId ?? paymentResult.transactionId ?? orderId,
            notes: _buildBookingNotes(user.name),
          );

      await ref.read(bookingListProvider.notifier).loadBookings(user.id);

      if (!context.mounted) return;
      Navigator.of(context).pop();
      context.push('/booking/${booking.id}');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _buildBookingNotes(String customerName) {
    final lines = <String>[
      'Booking type: Online special pooja',
      'Customer: $customerName',
      'Devotee name: ${_devoteeNameController.text.trim()}',
      if (_gotraController.text.trim().isNotEmpty)
        'Gotra: ${_gotraController.text.trim()}',
      if (_sankalpController.text.trim().isNotEmpty)
        'Sankalp: ${_sankalpController.text.trim()}',
      if (_notesController.text.trim().isNotEmpty)
        'Additional notes: ${_notesController.text.trim()}',
    ];
    return lines.join('\n');
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _CheckoutRow extends StatelessWidget {
  const _CheckoutRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                color: highlight ? AppColors.primary : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

