// lib/shop/screens/checkout_screen_v2.dart
// Production checkout with Razorpay payment integration

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../payment/payment_provider.dart';
import '../../payment/payment_service.dart';
import '../../widgets/base_scaffold.dart';
import '../../widgets/country_phone_field.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider_v2.dart';

class CheckoutScreenV2 extends ConsumerStatefulWidget {
  const CheckoutScreenV2({super.key});

  @override
  ConsumerState<CheckoutScreenV2> createState() => _CheckoutScreenV2State();
}

class _CheckoutScreenV2State extends ConsumerState<CheckoutScreenV2> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  CountryDialCode _selectedCountry = kCountryList.first;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromProfile());
  }

  Future<void> _prefillFromProfile() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    if (_nameCtrl.text.isEmpty) _nameCtrl.text = currentUser.name;
    if (_emailCtrl.text.isEmpty) _emailCtrl.text = currentUser.email;
    if (_phoneCtrl.text.isEmpty && (currentUser.phone ?? '').isNotEmpty) {
      final raw = currentUser.phone!.replaceAll(RegExp(r'^\+\d{1,3}'), '').trim();
      _phoneCtrl.text = raw;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _processPayment(CartSummary summary) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (summary.isEmpty) {
      _showError('Cart is empty');
      return;
    }

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      _showError('Not authenticated');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Step 1: Save cart to database
      final cartController = ref.read(cartProviderV2.notifier);
      await cartController.saveCartToDB();

      // Step 2: Create order from cart
      final orderId = await cartController.createOrderFromCart();
      if (orderId == null) {
        _showError('Failed to create order');
        setState(() => _isProcessing = false);
        return;
      }

      // Step 3: Initiate Razorpay payment
      final paymentRequest = PaymentRequest(
        orderId: orderId,
        amountPaise: summary.totalPaise,
        description: 'Saral Pooja Shop Order',
        customerName: _nameCtrl.text.trim(),
        customerEmail: _emailCtrl.text.trim(),
        customerPhone: '${_selectedCountry.dialCode}${_phoneCtrl.text.trim()}',
        metadata: {
          'order_id': orderId,
          'delivery_name': _nameCtrl.text.trim(),
          'delivery_address': _addressCtrl.text.trim(),
          'pincode': _pincodeCtrl.text.trim(),
          'payment_method': 'razorpay',
        },
      );

      final paymentResult = await ref.read(paymentProvider.notifier).pay(paymentRequest);

      if (!paymentResult.isSuccess) {
        // Payment failed or cancelled
        _showError(paymentResult.errorMessage ?? 'Payment failed');

        // Update order status to failed
        await ref.read(supabaseClientProvider).from('orders').update({
          'payment_status': 'failed',
          'payment_error_message': paymentResult.errorMessage ?? 'Payment failed',
        }).eq('id', orderId);
      } else {
        // Payment successful - order is confirmed
        _showSuccessDialog(orderId);

        // Clear cart
        await cartController.clearCart();

        // Navigate to order details
        if (mounted) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              context.go('/shop/orders');
            }
          });
        }
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Payment Successful! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your order has been confirmed.'),
            const SizedBox(height: 16),
            Text(
              'Order ID: $orderId',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProviderV2);
    final summary = cartState.summary;

    return BaseScaffold(
      title: 'Checkout',
      body: summary.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined,
                      size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  const Text('Your cart is empty'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go('/shop'),
                    child: const Text('Continue Shopping'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Order Summary ────────────────────────────────────
                    _CheckoutSection(
                      title: 'Order Summary',
                      child: Column(
                        children: [
                          ...summary.items.map((item) => _OrderItemRow(item: item)),
                          const Divider(height: 20, color: AppColors.divider),
                          _TotalRow(label: 'Subtotal', value: summary.formattedSubtotal),
                          const SizedBox(height: 4),
                          _TotalRow(label: 'GST (5%)', value: summary.formattedTax),
                          const SizedBox(height: 8),
                          _TotalRow(
                            label: 'Total',
                            value: summary.formattedTotal,
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Delivery Details ────────────────────────────────
                    _CheckoutSection(
                      title: 'Delivery Details',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailCtrl,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v?.isEmpty ?? true) return 'Required';
                              if (!v!.contains('@')) return 'Invalid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          CountryPhoneFormField(
                            controller: _phoneCtrl,
                            country: _selectedCountry,
                            onCountryTap: () => showCountryPicker(
                              context: context,
                              selected: _selectedCountry,
                              onSelected: (c) =>
                                  setState(() => _selectedCountry = c),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _addressCtrl,
                            decoration: InputDecoration(
                              labelText: 'Address',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            maxLines: 3,
                            validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _pincodeCtrl,
                            decoration: InputDecoration(
                              labelText: 'Pincode',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Payment Method ──────────────────────────────────
                    _CheckoutSection(
                      title: 'Payment Method',
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.lock_outline),
                            title: const Text('Razorpay'),
                            subtitle: const Text('UPI, Cards, Net Banking and Wallets'),
                            trailing:
                                const Icon(Icons.check_circle, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── CTA Button ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : () => _processPayment(summary),
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.payment),
                        label: Text(_isProcessing
                            ? 'Processing...'
                            : 'Pay ₹${(summary.totalPaise / 100).toStringAsFixed(0)}'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _CheckoutSection extends StatelessWidget {
  const _CheckoutSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: child,
        ),
      ],
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '₹${(item.product.pricePaise / 100).toStringAsFixed(0)} × ${item.quantity}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            item.formattedTotal,
            style: const TextStyle(fontWeight: FontWeight.w600),
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
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            fontSize: bold ? 14 : 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            fontSize: bold ? 14 : 13,
          ),
        ),
      ],
    );
  }
}
