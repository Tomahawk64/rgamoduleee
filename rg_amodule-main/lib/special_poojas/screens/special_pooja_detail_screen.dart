// lib/special_poojas/screens/special_pooja_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
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
                        label: pooja.location?.city ?? 'Online',
                        sublabel: 'Location',
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
      bottomNavigationBar: _BookingCTA(pooja: pooja, selectedDay: _selectedDay),
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
  const _BookingCTA({required this.pooja, required this.selectedDay});

  final SpecialPoojaModel pooja;
  final DateTime? selectedDay;

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
              onPressed: selectedDay == null
                  ? null
                  : () {
                      context.push(Routes.bookingWizard);
                    },
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

