// lib/payment/payment_service.dart

// Payment Abstraction Layer — Uses RazorpayPaymentServiceV2 via payment_provider.dart



import 'dart:async';



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

// DEPRECATED: Use RazorpayPaymentServiceV2 from supabase integration instead.
// (V2 includes server-side payment verification via edge functions)

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



