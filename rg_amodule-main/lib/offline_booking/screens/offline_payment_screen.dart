// lib/offline_booking/screens/offline_payment_screen.dart
// Payment screen for offline bookings using Razorpay

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../payment/payment_provider.dart';
import '../../payment/payment_service.dart';
import '../providers/offline_booking_provider.dart';

class OfflinePaymentScreen extends ConsumerStatefulWidget {
  const OfflinePaymentScreen({
    super.key,
    required this.bookingId,
    required this.amount,
    required this.panditName,
    required this.serviceName,
    required this.bookingDate,
    required this.bookingTime,
  });

  final String bookingId;
  final double amount;
  final String panditName;
  final String serviceName;
  final DateTime bookingDate;
  final String bookingTime;

  @override
  ConsumerState<OfflinePaymentScreen> createState() =>
      _OfflinePaymentScreenState();
}

class _OfflinePaymentScreenState extends ConsumerState<OfflinePaymentScreen> {
  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentProvider);

    ref.listen<PaymentState>(paymentProvider, (previous, next) {
      if (next.status == PaymentStatus.success && next.result != null) {
        _handlePaymentSuccess(next.result!);
      } else if (next.status == PaymentStatus.failed && next.errorMessage != null) {
        _handlePaymentError(next.errorMessage!);
      } else if (next.status == PaymentStatus.cancelled) {
        _handlePaymentCancelled();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBookingSummary(),
            const SizedBox(height: 24),
            _buildPaymentDetails(),
            const SizedBox(height: 24),
            _buildPaymentButton(paymentState),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Booking Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Pandit', widget.panditName),
          const SizedBox(height: 12),
          _buildSummaryRow('Service', widget.serviceName),
          const SizedBox(height: 12),
          _buildSummaryRow('Date', _formatDate(widget.bookingDate)),
          const SizedBox(height: 12),
          _buildSummaryRow('Time', widget.bookingTime),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        const Text(': '),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentDetails() {
    final platformFee = widget.amount * 0.15;
    final total = widget.amount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildPaymentRow('Service Charge', widget.amount.toStringAsFixed(2)),
          const SizedBox(height: 12),
          _buildPaymentRow('Platform Fee (15%)', platformFee.toStringAsFixed(2)),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          _buildTotalRow('Total Amount', total.toStringAsFixed(2)),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          '₹$value',
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildTotalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          '₹$value',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentButton(PaymentState state) {
    final isLoading = state.isProcessing;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : _initiatePayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'Pay ₹${widget.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _initiatePayment() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to continue')),
      );
      return;
    }

    final amountPaise = (widget.amount * 100).toInt();
    final orderId = 'OFFLINE_${DateTime.now().millisecondsSinceEpoch}';

    final request = PaymentRequest(
      orderId: orderId,
      amountPaise: amountPaise,
      description: '${widget.serviceName} with ${widget.panditName}',
      customerName: user.name,
      customerEmail: user.email,
      customerPhone: user.phone ?? '',
    );

    await ref.read(paymentProvider.notifier).pay(request);
  }

  Future<void> _handlePaymentSuccess(PaymentResult result) async {
    try {
      await ref
          .read(offlineBookingRepositoryProvider)
          .confirmBookingPayment(
            bookingId: widget.bookingId,
            paymentId: result.transactionId ?? result.providerPaymentId ?? '',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful! Booking confirmed.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment successful but booking confirmation failed: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _handlePaymentError(String error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handlePaymentCancelled() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment cancelled'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
