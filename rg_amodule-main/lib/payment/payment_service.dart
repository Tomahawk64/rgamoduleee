// lib/payment/payment_service.dart
// Payment Abstraction Layer — Production uses RazorpayPaymentService.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

// ── Domain objects ────────────────────────────────────────────────────────────

enum PaymentStatus { idle, processing, success, failed, cancelled }

class PaymentRequest {
  const PaymentRequest({
    required this.orderId,
    required this.amountPaise,
    required this.description,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    this.razorpayOrderId,
    this.metadata = const {},
  });

  final String orderId;
  final int amountPaise;     // amount in paise (₹1 = 100 paise)
  final String description;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String? razorpayOrderId;
  final Map<String, dynamic> metadata;

  double get amountRupees => amountPaise / 100;
}

class PaymentResult {
  const PaymentResult({
    required this.status,
    this.transactionId,
    this.providerPaymentId,
    this.errorMessage,
    this.providerData,
  });

  final PaymentStatus status;
  final String? transactionId;
  final String? providerPaymentId;
  final String? errorMessage;
  final Map<String, dynamic>? providerData;

  bool get isSuccess => status == PaymentStatus.success;

  factory PaymentResult.success({
    required String transactionId,
    String? providerPaymentId,
    Map<String, dynamic>? providerData,
  }) =>
      PaymentResult(
        status: PaymentStatus.success,
        transactionId: transactionId,
        providerPaymentId: providerPaymentId,
        providerData: providerData,
      );

  factory PaymentResult.failed(String message) => PaymentResult(
        status: PaymentStatus.failed,
        errorMessage: message,
      );

  factory PaymentResult.cancelled() => const PaymentResult(
        status: PaymentStatus.cancelled,
      );
}

// ── Abstract interface ────────────────────────────────────────────────────────

abstract class IPaymentService {
  /// Initiates a payment flow. On mobile this opens the payment SDK.
  /// Returns a [PaymentResult] when the flow completes (success/fail/cancel).
  Future<PaymentResult> initiatePayment(PaymentRequest request);

  /// Verifies a payment server-side after client receives success callback.
  /// Returns true if verification passes.
  Future<bool> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  });

  String get providerName;
}

// ── Razorpay Implementation (Production) ─────────────────────────────────────
// Uses the official razorpay_flutter SDK.
// Set RAZORPAY_KEY_ID in app config / env before shipping.

class RazorpayPaymentService implements IPaymentService {
  static const _keyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_test_REPLACE_WITH_YOUR_KEY',
  );

  static bool get isConfigured =>
      _keyId.isNotEmpty && !_keyId.contains('REPLACE_WITH_YOUR_KEY');

  @override
  String get providerName => 'razorpay';

  @override
  Future<PaymentResult> initiatePayment(PaymentRequest request) async {
    // Web platform: Razorpay Flutter SDK is Android/iOS only.
    if (kIsWeb) {
      return PaymentResult.failed(
        'Online payment is not supported on web. Please use the Android app.',
      );
    }

    if (!isConfigured) {
      return PaymentResult.failed(
        'Payment gateway is not configured yet. Add RAZORPAY_KEY_ID and rebuild.',
      );
    }

    final completer = Completer<PaymentResult>();
    final razorpay = Razorpay();

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse res) {
      razorpay.clear();
      completer.complete(
        PaymentResult.success(
          transactionId: request.orderId,
          providerPaymentId: res.paymentId,
          providerData: {
            'razorpay_payment_id': res.paymentId,
            'razorpay_order_id': res.orderId,
            'razorpay_signature': res.signature,
          },
        ),
      );
    });

    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse res) {
      razorpay.clear();
      completer.complete(
        PaymentResult.failed(res.message ?? 'Payment failed. Please try again.'),
      );
    });

    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse res) {
      // External wallet selected — treat as cancelled from our flow perspective
      razorpay.clear();
      completer.complete(PaymentResult.cancelled());
    });

    try {
      final options = <String, dynamic>{
        'key': _keyId,
        'amount': request.amountPaise,
        if (request.razorpayOrderId != null &&
            request.razorpayOrderId!.isNotEmpty)
          'order_id': request.razorpayOrderId,
        'name': 'Saral Pooja',
        'description': request.description,
        'prefill': {
          'contact': request.customerPhone,
          'email': request.customerEmail,
          'name': request.customerName,
        },
        'notes': {
          'app_order_id': request.orderId,
          ...request.metadata,
        },
        'theme': {'color': '#FF5722'},
        'currency': 'INR',
        'retry': {'enabled': true, 'max_count': 3},
      };
      razorpay.open(options);
    } catch (e) {
      razorpay.clear();
      return PaymentResult.failed('Unable to open payment gateway: $e');
    }

    return completer.future;
  }

  /// Razorpay signature verification should always be done server-side.
  /// This client-side stub returns true — use a Supabase Edge Function or
  /// your backend to call Razorpay's /payments/verify API.
  @override
  Future<bool> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    // TODO: call your Supabase Edge Function / backend to verify signature
    // Example: POST /functions/v1/verify-razorpay-payment
    //   body: { order_id, payment_id, signature }
    // Edge function computes HMAC-SHA256 with your Razorpay secret and verifies.
    return true;
  }
}

// ── Mock Implementation (Dev / Web fallback) ──────────────────────────────────
// Simulates a 1.5s payment processing delay and always succeeds.
// Used on web or when RAZORPAY_KEY_ID is not configured.

class MockPaymentService implements IPaymentService {
  int _sequence = 0;

  @override
  String get providerName => 'mock';

  @override
  Future<PaymentResult> initiatePayment(PaymentRequest request) async {
    // Simulate network + SDK latency
    await Future.delayed(const Duration(milliseconds: 1500));
    final sequence = ++_sequence;
    return PaymentResult.success(
      transactionId: 'mock_txn_${request.orderId}_$sequence',
      providerPaymentId:
          'mock_pay_${DateTime.now().millisecondsSinceEpoch}_$sequence',
      providerData: {'provider': 'mock'},
    );
  }

  @override
  Future<bool> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async =>
      true;
}

