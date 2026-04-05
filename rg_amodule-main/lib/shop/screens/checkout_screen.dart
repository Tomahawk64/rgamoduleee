// lib/shop/screens/checkout_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../payment/payment_provider.dart';
import '../../payment/payment_service.dart';
import '../../widgets/base_scaffold.dart';
import '../../widgets/country_phone_field.dart';
import '../controllers/shop_controller.dart';
import '../models/cart_item.dart';
import '../providers/shop_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  String _selectedPayment = 'upi';
  CountryDialCode _selectedCountry = kCountryList.first; // default: India +91
  bool _addressLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromProfile());
  }

  Future<void> _prefillFromProfile() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    if (_nameCtrl.text.isEmpty) _nameCtrl.text = currentUser.name;
    if (_phoneCtrl.text.isEmpty && (currentUser.phone ?? '').isNotEmpty) {
      final raw = currentUser.phone!.replaceAll(RegExp(r'^\+\d{1,3}'), '').trim();
      _phoneCtrl.text = raw;
    }

    setState(() => _addressLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final rows = await client
          .from('addresses')
          .select('*')
          .eq('user_id', currentUser.id)
          .eq('is_default', true)
          .limit(1);
      if (!mounted) return;
      final list = List<Map<String, dynamic>>.from(rows as List);
      if (list.isNotEmpty) {
        final a = list.first;
        if (_addressCtrl.text.isEmpty) {
          final parts = [
            a['address_line'] as String? ?? '',
            a['city'] as String? ?? '',
            a['state'] as String? ?? '',
          ].where((s) => s.isNotEmpty).join(', ');
          _addressCtrl.text = parts;
        }
        if (_pincodeCtrl.text.isEmpty) {
          _pincodeCtrl.text = a['pincode'] as String? ?? '';
        }
      }
    } catch (_) {
      // silently ignore – user can fill manually
    } finally {
      if (mounted) setState(() => _addressLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _placeOrder(CartSummary summary) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final currentUser = ref.read(currentUserProvider);

    // Only launch Razorpay for non-COD methods.
    if (_selectedPayment != 'cod') {
      final request = PaymentRequest(
        orderId: 'SHOP-${DateTime.now().millisecondsSinceEpoch}',
        amountPaise: summary.totalPaise,
        description: 'Saral Pooja Shop Order',
        customerName: _nameCtrl.text.trim(),
        customerEmail: currentUser?.email ?? '',
        customerPhone: '${_selectedCountry.dialCode}${_phoneCtrl.text.trim()}',
      );
      final result = await ref.read(paymentProvider.notifier).pay(request);
      if (!result.isSuccess) return; // User cancelled or error — stop here.
    }

    await ref.read(orderProvider.notifier).placeOrder(
          cart: summary,
          deliveryName: _nameCtrl.text.trim(),
          deliveryAddress:
              '${_addressCtrl.text.trim()}, ${_pincodeCtrl.text.trim()}',
          paymentMethod: _selectedPayment,
        );
  }

  void _openCountryPicker() {
    showCountryPicker(
      context: context,
      selected: _selectedCountry,
      onSelected: (c) => setState(() => _selectedCountry = c),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(cartSummaryProvider);
    final orderState = ref.watch(orderProvider);

    // Listen for order success
    ref.listen<OrderState>(orderProvider, (prev, next) {
      if (next.status == OrderStatus.success) {
        _showSuccessDialog(next.orderId ?? '');
      }
    });

    return BaseScaffold(
      title: 'Checkout',
      body: summary.isEmpty
          ? _EmptyCheckout(onGoBack: () => context.pop())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Order summary ────────────────────────────────────
                    _CheckoutSection(
                      title: 'Order Summary',
                      child: Column(
                        children: [
                          ...summary.items.map(
                            (item) => _OrderItemRow(item: item),
                          ),
                          const Divider(height: 20, color: AppColors.divider),
                          _TotalRow(
                              label: 'Subtotal',
                              value: summary.formattedSubtotal),
                          const SizedBox(height: 4),
                          _TotalRow(
                              label: 'GST (5%)', value: summary.formattedTax),
                          const SizedBox(height: 8),
                          _TotalRow(
                            label: 'Total',
                            value: summary.formattedTotal,
                            bold: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Delivery address ─────────────────────────────────
                    if (_addressLoading)
                      const LinearProgressIndicator(minHeight: 2),
                    _CheckoutSection(
                      title: 'Delivery Address',
                      child: Column(
                        children: [
                          _FormField(
                            controller: _nameCtrl,
                            label: 'Full Name',
                            icon: Icons.person_outline,
                            validator: (v) => (v?.trim().isEmpty ?? true)
                                ? 'Name is required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          CountryPhoneFormField(
                            controller: _phoneCtrl,
                            country: _selectedCountry,
                            onCountryTap: _openCountryPicker,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              filled: true,
                              fillColor: AppColors.background,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _FormField(
                            controller: _addressCtrl,
                            label: 'Street Address',
                            icon: Icons.home_outlined,
                            maxLines: 2,
                            validator: (v) => (v?.trim().isEmpty ?? true)
                                ? 'Address is required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _FormField(
                            controller: _pincodeCtrl,
                            label: 'PIN Code',
                            icon: Icons.location_on_outlined,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v?.trim().isEmpty ?? true) {
                                return 'PIN code is required';
                              }
                              if ((v?.trim().length ?? 0) !=
                                  _selectedCountry.postalCodeLength) {
                                return 'Enter a valid '
                                    '${_selectedCountry.postalCodeLength}-digit '
                                    'postal code for ${_selectedCountry.name}';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Payment method ───────────────────────────────────
                    _CheckoutSection(
                      title: 'Payment Method',
                      subtitle:
                          'Payment gateway integration ready (Razorpay / PayU)',
                      child: Column(
                        children: [
                          _PaymentOption(
                            value: 'upi',
                            groupValue: _selectedPayment,
                            label: 'UPI',
                            subtitle: 'Google Pay, PhonePe, Paytm, BHIM',
                            icon: Icons.account_balance_wallet_outlined,
                            onChanged: (v) =>
                                setState(() => _selectedPayment = v!),
                          ),
                          const SizedBox(height: 8),
                          _PaymentOption(
                            value: 'card',
                            groupValue: _selectedPayment,
                            label: 'Credit / Debit Card',
                            subtitle: 'Visa, Mastercard, RuPay',
                            icon: Icons.credit_card,
                            onChanged: (v) =>
                                setState(() => _selectedPayment = v!),
                          ),
                          const SizedBox(height: 8),
                          _PaymentOption(
                            value: 'netbanking',
                            groupValue: _selectedPayment,
                            label: 'Net Banking',
                            subtitle: 'All major banks supported',
                            icon: Icons.account_balance_outlined,
                            onChanged: (v) =>
                                setState(() => _selectedPayment = v!),
                          ),
                          const SizedBox(height: 8),
                          _PaymentOption(
                            value: 'cod',
                            groupValue: _selectedPayment,
                            label: 'Cash on Delivery',
                            subtitle: 'Pay when your kit arrives',
                            icon: Icons.money_outlined,
                            onChanged: (v) =>
                                setState(() => _selectedPayment = v!),
                          ),
                          const SizedBox(height: 12),
                          // Payment note
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.info.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.security,
                                    size: 16, color: AppColors.info),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'All transactions are encrypted and secured by '
                                    'industry-standard SSL.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.info,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

      // ── Sticky place-order bar ──────────────────────────────────────────────
      bottomNavigationBar: summary.isEmpty
          ? null
          : Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              child: FilledButton(
                onPressed: orderState.status == OrderStatus.processing
                    ? null
                    : () => _placeOrder(summary),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: orderState.status == OrderStatus.processing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Place Order · ${summary.formattedTotal}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
    );
  }

  void _showSuccessDialog(String orderId) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 60),
            SizedBox(height: 12),
            Text(
              'Order Placed!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your puja kit order has been placed successfully.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Order ID: $orderId',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () {
              ctx.pop(); // close dialog
              ref.read(cartProvider.notifier).clear();
              ref.read(orderProvider.notifier).reset();
              // Navigate back to shop
              context.go(Routes.shop);
            },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Continue Shopping'),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _CheckoutSection extends StatelessWidget {
  const _CheckoutSection({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
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
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${item.product.name} × ${item.quantity}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            item.formattedTotal,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w400,
            color: bold ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: bold ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: true,
        fillColor: AppColors.background,
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onChanged,
  });

  final String value;
  final String groupValue;
  final String label;
  final String subtitle;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color:
                    selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              value == groupValue
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: value == groupValue
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCheckout extends StatelessWidget {
  const _EmptyCheckout({required this.onGoBack});
  final VoidCallback onGoBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.remove_shopping_cart,
              size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          const Text(
            'Nothing to checkout',
            style:
                TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onGoBack,
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}
