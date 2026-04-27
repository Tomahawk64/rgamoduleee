// lib/payment/payment_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/supabase_provider.dart';
import 'payment_service.dart';
import 'services/razorpay_payment_service_v2.dart';

// ── Service provider ──────────────────────────────────────────────────────────
// Uses RazorpayPaymentServiceV2 on Android/iOS with server-side verification,
// mock on web (Razorpay SDK is mobile-only).

final paymentServiceProvider = Provider<IPaymentService>(
  (ref) => (kIsWeb || !RazorpayPaymentServiceV2.isConfigured)
      ? MockPaymentService()
      : RazorpayPaymentServiceV2(
          supabase: ref.watch(supabaseClientProvider),
        ),
);

// ── Payment state ─────────────────────────────────────────────────────────────

class PaymentState {
  const PaymentState({
    this.status = PaymentStatus.idle,
    this.result,
    this.errorMessage,
  });

  final PaymentStatus status;
  final PaymentResult? result;
  final String? errorMessage;

  bool get isProcessing => status == PaymentStatus.processing;
  bool get isSuccess => status == PaymentStatus.success;
  bool get isFailed => status == PaymentStatus.failed;

  PaymentState copyWith({
    PaymentStatus? status,
    PaymentResult? result,
    String? errorMessage,
  }) =>
      PaymentState(
        status: status ?? this.status,
        result: result ?? this.result,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

// ── Controller ────────────────────────────────────────────────────────────────

class PaymentController extends StateNotifier<PaymentState> {
  PaymentController(this._service) : super(const PaymentState());

  final IPaymentService _service;

  Future<PaymentResult> pay(PaymentRequest request) async {
    state = state.copyWith(status: PaymentStatus.processing, errorMessage: null);

    final result = await _service.initiatePayment(request);

    if (result.isSuccess) {
      state = state.copyWith(status: PaymentStatus.success, result: result);
    } else if (result.status == PaymentStatus.cancelled) {
      state = state.copyWith(status: PaymentStatus.cancelled);
    } else {
      state = state.copyWith(
        status: PaymentStatus.failed,
        errorMessage: result.errorMessage ?? 'Payment failed',
      );
    }

    return result;
  }

  void reset() => state = const PaymentState();
}

final paymentProvider =
    StateNotifierProvider<PaymentController, PaymentState>((ref) {
  return PaymentController(ref.watch(paymentServiceProvider));
});
