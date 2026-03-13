import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/base_scaffold.dart';
import '../controllers/consultation_controller.dart';
import '../models/consultation_session.dart';
import '../models/pandit_model.dart';
import '../providers/consultation_provider.dart';

// ── Consultation Screen ───────────────────────────────────────────────────────

class ConsultationScreen extends ConsumerWidget {
  const ConsultationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panditsState = ref.watch(panditsProvider);

    return BaseScaffold(
      title: 'Live Consultation',
      showBackButton: false,
      body: RefreshIndicator(
        onRefresh: () => ref.read(panditsProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeroBanner(),
            const SizedBox(height: 20),
            _SectionHeader(
              title: 'Available Consultants',
              subtitle: panditsState.loading
                  ? 'Loading...'
                  : '${panditsState.pandits.where((p) => p.isOnline).length} online now',
            ),
            const SizedBox(height: 12),
            if (panditsState.loading)
              const _LoadingCards()
            else if (panditsState.error != null)
              _ErrorView(
                  message: panditsState.error!,
                  onRetry: () =>
                      ref.read(panditsProvider.notifier).refresh())
            else ...[
              ...panditsState.pandits.map(
                (p) => _PanditCard(
                  pandit: p,
                  onConnect: p.isOnline
                      ? () => _openSessionSheet(context, p)
                      : null,
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _openSessionSheet(BuildContext context, PanditModel pandit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PanditSessionSheet(pandit: pandit),
    );
  }
}

// ── Hero Banner ───────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.secondary, AppColors.secondaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withAlpha(60),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Get Expert Guidance',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17)),
                SizedBox(height: 4),
                Text(
                    '1-on-1 live chat with certified pandits.\nSecure · Private · Instant',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                shape: BoxShape.circle),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        if (subtitle != null)
          Text(subtitle!,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

// ── Pandit Card ───────────────────────────────────────────────────────────────

class _PanditCard extends StatelessWidget {
  const _PanditCard({required this.pandit, this.onConnect});
  final PanditModel pandit;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    final isOnline = pandit.isOnline;
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary.withAlpha(20),
                    backgroundImage:
                        pandit.avatarUrl != null &&
                                pandit.avatarUrl!.startsWith('assets/')
                            ? AssetImage(pandit.avatarUrl!)
                            : null,
                    child: pandit.avatarUrl != null &&
                            pandit.avatarUrl!.startsWith('assets/')
                        ? null
                        : Text(pandit.initials,
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 1,
                      right: 1,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pandit.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5)),
                      const SizedBox(height: 2),
                      Text(pandit.specialty,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5)),
                      const SizedBox(height: 5),
                      Row(children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.warning, size: 14),
                        const SizedBox(width: 3),
                        Text(pandit.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text('${pandit.totalSessions} sessions',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        const SizedBox(width: 8),
                        Text('${pandit.experienceYears}y exp',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: pandit.languagesSpoken
                  .map((l) => _Chip(label: l))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Starts at',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                    Text(
                      pandit.rates.isNotEmpty
                          ? pandit.rates.first.priceLabel
                          : '₹—',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.primary),
                    ),
                  ],
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onConnect,
                  icon: Icon(
                    isOnline
                        ? Icons.chat_rounded
                        : Icons.access_time_rounded,
                    size: 16,
                  ),
                  label: Text(isOnline ? 'Connect' : 'Busy',
                      style: const TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    backgroundColor: isOnline
                        ? AppColors.primary
                        : cs.surfaceContainerHighest,
                    foregroundColor: isOnline
                        ? Colors.white
                        : AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.secondary.withAlpha(18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.secondary,
              fontWeight: FontWeight.w500)),
    );
  }
}

// ── Loading Cards ─────────────────────────────────────────────────────────────

class _LoadingCards extends StatelessWidget {
  const _LoadingCards();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                _ShimmerBox(width: 60, height: 60, radius: 30),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShimmerBox(width: 150, height: 14),
                      SizedBox(height: 6),
                      _ShimmerBox(width: 100, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox(
      {required this.width, required this.height, this.radius = 6});
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(40),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ── Error View ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PANDIT SESSION BOTTOM SHEET
// Manages: duration selection → payment → connecting
// ═════════════════════════════════════════════════════════════════════════════

class _PanditSessionSheet extends ConsumerStatefulWidget {
  const _PanditSessionSheet({required this.pandit});
  final PanditModel pandit;

  @override
  ConsumerState<_PanditSessionSheet> createState() =>
      _PanditSessionSheetState();
}

class _PanditSessionSheetState
    extends ConsumerState<_PanditSessionSheet> {
  @override
  Widget build(BuildContext context) {
    final flowState =
        ref.watch(consultationFlowProvider(widget.pandit.id));
    final ctrl =
        ref.read(consultationFlowProvider(widget.pandit.id).notifier);

    // Navigate when session is created
    ref.listen<ConsultationFlowState>(
        consultationFlowProvider(widget.pandit.id), (_, next) {
      if (next.step == ConsultationFlowStep.started &&
          next.createdSession != null) {
        if (context.mounted) {
          Navigator.of(context).pop();
          context.push('/consultation/chat', extra: next.createdSession);
          ctrl.reset();
        }
      }
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) {
        return ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(
                  child: switch (flowState.step) {
                    ConsultationFlowStep.selectDuration => _DurationStep(
                        scrollCtrl: scrollCtrl,
                        pandit: widget.pandit,
                        flowState: flowState,
                        ctrl: ctrl,
                      ),
                    ConsultationFlowStep.payment => _PaymentStep(
                        scrollCtrl: scrollCtrl,
                        flowState: flowState,
                        ctrl: ctrl,
                      ),
                    ConsultationFlowStep.connecting ||
                    ConsultationFlowStep.started =>
                      _ConnectingView(panditName: widget.pandit.name),
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Step 1: Duration Selection ────────────────────────────────────────────────

class _DurationStep extends StatelessWidget {
  const _DurationStep({
    required this.scrollCtrl,
    required this.pandit,
    required this.flowState,
    required this.ctrl,
  });
  final ScrollController scrollCtrl;
  final PanditModel pandit;
  final ConsultationFlowState flowState;
  final ConsultationFlowController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SheetPanditHeader(pandit: pandit),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            children: [
              const Text('Select Session Duration',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              const Text('Choose how long you want to consult',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12.5)),
              const SizedBox(height: 14),
              ...pandit.rates.map((rate) => _DurationCard(
                    rate: rate,
                    isSelected:
                        flowState.selectedRate?.duration == rate.duration,
                    onTap: () => ctrl.selectRate(rate),
                  )),
              if (flowState.error != null) ...[
                const SizedBox(height: 8),
                _ErrorBanner(message: flowState.error!),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
        _SheetBottomBar(
          label: 'Continue →',
          enabled: flowState.canProceedToPayment,
          onTap: ctrl.proceedToPayment,
        ),
      ],
    );
  }
}

class _DurationCard extends StatelessWidget {
  const _DurationCard({
    required this.rate,
    required this.isSelected,
    required this.onTap,
  });
  final ConsultationRate rate;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(15) : cs.surface,
          border: Border.all(
            color: isSelected ? AppColors.primary : cs.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textHint,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rate.durationLabel,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isSelected ? AppColors.primary : null)),
                  const SizedBox(height: 2),
                  Text(
                    '₹${(rate.totalRupees / rate.duration).toStringAsFixed(0)}/min',
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Text(rate.priceLabel,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isSelected ? AppColors.primary : null)),
          ],
        ),
      ),
    );
  }
}

// ── Step 2: Payment ───────────────────────────────────────────────────────────

class _PaymentStep extends StatelessWidget {
  const _PaymentStep({
    required this.scrollCtrl,
    required this.flowState,
    required this.ctrl,
  });
  final ScrollController scrollCtrl;
  final ConsultationFlowState flowState;
  final ConsultationFlowController ctrl;

  @override
  Widget build(BuildContext context) {
    final rate = flowState.selectedRate!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: ctrl.backToSelectDuration,
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18),
              ),
              const Text('Payment',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(16),
            children: [
              _OrderSummary(pandit: flowState.pandit, rate: rate),
              const SizedBox(height: 20),
              const _PaymentMethodPlaceholder(),
              const SizedBox(height: 12),
              const _SecurityNote(),
              if (flowState.error != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: flowState.error!),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
        _SheetBottomBar(
          label: flowState.processingPayment
              ? 'Processing…'
              : 'Pay ${rate.priceLabel}',
          enabled: !flowState.processingPayment,
          loading: flowState.processingPayment,
          onTap: () => ctrl.confirmPayment(
            userId: 'user_mock',
            userName: 'You',
          ),
        ),
      ],
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.pandit, required this.rate});
  final PanditModel pandit;
  final ConsultationRate rate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.secondary.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Summary',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Consultant', value: pandit.name),
          _SummaryRow(label: 'Specialty', value: pandit.specialty),
          _SummaryRow(label: 'Duration', value: rate.durationLabel),
          const Divider(height: 20),
          Row(
            children: [
              const Text('Total',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              Text(rate.priceLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _PaymentMethodPlaceholder extends StatelessWidget {
  const _PaymentMethodPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Method',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 14),
          _PaymentOption(
            icon: Icons.account_balance_wallet_rounded,
            label: 'UPI / Google Pay / PhonePe',
            subtitle: 'Connect payment gateway',
            isSelected: true,
          ),
          const SizedBox(height: 8),
          _PaymentOption(
            icon: Icons.credit_card_rounded,
            label: 'Credit / Debit Card',
            subtitle: 'Visa, Mastercard, RuPay',
            isSelected: false,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded,
                  color: AppColors.warning, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Payment gateway integration pending. This is a demo flow.',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withAlpha(12) : null,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(children: [
        Icon(icon,
            color:
                isSelected ? AppColors.primary : AppColors.textSecondary,
            size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              Text(subtitle,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11.5)),
            ],
          ),
        ),
        if (isSelected)
          const Icon(Icons.check_circle_rounded,
              color: AppColors.primary, size: 18),
      ]),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();
  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_rounded, size: 13, color: AppColors.textHint),
        SizedBox(width: 5),
        Text('Secured by 256-bit SSL encryption',
            style: TextStyle(fontSize: 11.5, color: AppColors.textHint)),
      ],
    );
  }
}

// ── Connecting View ───────────────────────────────────────────────────────────

class _ConnectingView extends StatelessWidget {
  const _ConnectingView({required this.panditName});
  final String panditName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text('Connecting to $panditName…',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
                'Please wait while we set up your secure session.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13.5)),
          ],
        ),
      ),
    );
  }
}

// ── Shared Sheet Widgets ──────────────────────────────────────────────────────

class _SheetPanditHeader extends StatelessWidget {
  const _SheetPanditHeader({required this.pandit});
  final PanditModel pandit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Row(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withAlpha(20),
          child: Text(pandit.initials,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 17)),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pandit.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            Text(pandit.specialty,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
        const Spacer(),
        const Row(children: [
          Icon(Icons.circle, color: AppColors.success, size: 8),
          SizedBox(width: 4),
          Text('Online',
              style: TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

class _SheetBottomBar extends StatelessWidget {
  const _SheetBottomBar({
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.loading = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          height: 50,
          width: double.infinity,
          child: FilledButton(
            onPressed: enabled ? onTap : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withAlpha(80)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded,
            color: AppColors.error, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.error))),
      ]),
    );
  }
}
