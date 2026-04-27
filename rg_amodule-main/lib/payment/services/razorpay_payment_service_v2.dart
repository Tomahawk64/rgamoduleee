// lib/payment/services/razorpay_payment_service_v2.dart
// Production-grade Razorpay integration with server-side verification

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../payment_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// PRODUCTION RAZORPAY SERVICE (V2) — WITH SERVER-SIDE VERIFICATION
// ══════════════════════════════════════════════════════════════════════════════

/// Production-grade Razorpay payment service with complete lifecycle management
class RazorpayPaymentServiceV2 implements IPaymentService {
  // Razorpay Configuration
  static const String _keyId = String.fromEnvironment('RAZORPAY_KEY_ID');
  static const String _keySecret = String.fromEnvironment('RAZORPAY_KEY_SECRET');

  static bool get isConfigured => _keyId.isNotEmpty && _keySecret.isNotEmpty;

  final SupabaseClient _supabase;

  RazorpayPaymentServiceV2({
    required SupabaseClient supabase,
  }) : _supabase = supabase;

  @override
  String get providerName => 'razorpay_v2';

  // ────────────────────────────────────────────────────────────────────────────
  // STEP 1: CREATE RAZORPAY ORDER (Backend)
  // ────────────────────────────────────────────────────────────────────────────

  /// Creates a Razorpay order on the backend before initiating payment
  Future<String> _createRazorpayOrder({
    required int amountPaise,
    required String customerId,
    required String description,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-razorpay-order',
        body: {
          'amount_paise': amountPaise,
          'customer_id': customerId,
          'description': description,
          'metadata': metadata,
        },
      );

      final data = response as Map<String, dynamic>;

      if (data['error'] != null) {
        throw Exception('Failed to create Razorpay order: ${data['error']}');
      }

      return data['order_id'] as String;
    } catch (e) {
      debugPrint('Error creating Razorpay order: $e');
      rethrow;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // STEP 2: INITIATE PAYMENT (Client-side SDK)
  // ────────────────────────────────────────────────────────────────────────────

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
        'Payment gateway is not configured. Contact support.',
      );
    }

    try {
      // Create Razorpay order on backend if not already created
      String razorpayOrderId = request.razorpayOrderId ?? '';

      if (razorpayOrderId.isEmpty) {
        final userId = _supabase.auth.currentUser?.id ?? request.orderId;
        razorpayOrderId = await _createRazorpayOrder(
          amountPaise: request.amountPaise,
          customerId: userId,
          description: request.description,
          metadata: {
            ...request.metadata,
            'app_order_id': request.orderId,
          },
        );
      }

      // Log payment attempt
      await _logPaymentAttempt(
        orderId: request.orderId,
        amountPaise: request.amountPaise,
        razorpayOrderId: razorpayOrderId,
      );

      // Open Razorpay payment UI
      return await _openRazorpayUI(
        request: request,
        razorpayOrderId: razorpayOrderId,
      );
    } catch (e) {
      debugPrint('Error initiating payment: $e');
      return PaymentResult.failed('Payment initialization failed: $e');
    }
  }

  /// Opens the Razorpay payment UI and handles payment flow
  Future<PaymentResult> _openRazorpayUI({
    required PaymentRequest request,
    required String razorpayOrderId,
  }) async {
    final completer = Completer<PaymentResult>();
    final razorpay = Razorpay();

    razorpay.on(
      Razorpay.EVENT_PAYMENT_SUCCESS,
      (PaymentSuccessResponse res) async {
        razorpay.clear();
        try {
          // Verify payment on backend before completing
          final verified = await verifyPayment(
            orderId: res.orderId ?? '',
            paymentId: res.paymentId ?? '',
            signature: res.signature ?? '',
          );

          if (verified) {
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
          } else {
            completer.complete(
              PaymentResult.failed('Payment verification failed'),
            );
          }
        } catch (e) {
          completer.complete(PaymentResult.failed('Verification error: $e'));
        }
      },
    );

    razorpay.on(
      Razorpay.EVENT_PAYMENT_ERROR,
      (PaymentFailureResponse res) {
        razorpay.clear();
        completer.complete(
          PaymentResult.failed(res.message ?? 'Payment failed'),
        );
      },
    );

    razorpay.on(
      Razorpay.EVENT_EXTERNAL_WALLET,
      (ExternalWalletResponse res) {
        razorpay.clear();
        completer.complete(PaymentResult.cancelled());
      },
    );

    try {
      final options = <String, dynamic>{
        'key': _keyId,
        'amount': request.amountPaise,
        'order_id': razorpayOrderId,
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

  // ────────────────────────────────────────────────────────────────────────────
  // STEP 3: VERIFY PAYMENT (Server-side)
  // ────────────────────────────────────────────────────────────────────────────

  @override
  Future<bool> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      // Call Supabase Edge Function to verify payment
      final response = await _supabase.functions.invoke(
        'verify-razorpay-payment',
        body: {
          'order_id': orderId,
          'payment_id': paymentId,
          'signature': signature,
        },
      );

      final data = response as Map<String, dynamic>;
      return data['verified'] == true;
    } catch (e) {
      debugPrint('Error verifying payment: $e');
      return false;
    }
  }


  // ────────────────────────────────────────────────────────────────────────────
  // PAYMENT LOGGING & TRACKING
  // ────────────────────────────────────────────────────────────────────────────

  /// Logs payment attempt to database for audit trail
  Future<void> _logPaymentAttempt({
    required String orderId,
    required int amountPaise,
    required String razorpayOrderId,
  }) async {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    if (!uuidRegex.hasMatch(orderId)) {
      return;
    }

    try {
      await _supabase.rpc(
        'log_payment_attempt',
        params: {
          'p_user_id': _supabase.auth.currentUser?.id,
          'p_order_id': orderId,
          'p_amount_paise': amountPaise,
          'p_razorpay_order_id': razorpayOrderId,
        },
      );
    } catch (e) {
      debugPrint('Error logging payment attempt: $e');
    }
  }

  /// Updates payment status after successful verification
  Future<void> updatePaymentStatus({
    required String orderId,
    required String paymentStatus,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required Map<String, dynamic> responseData,
  }) async {
    try {
      await _supabase.rpc(
        'update_payment_status',
        params: {
          'p_order_id': orderId,
          'p_payment_status': paymentStatus,
          'p_razorpay_payment_id': razorpayPaymentId,
          'p_razorpay_signature': razorpaySignature,
          'p_response_data': responseData,
        },
      );
    } catch (e) {
      debugPrint('Error updating payment status: $e');
      rethrow;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SIGNATURE VERIFICATION HELPER (Client-side for reference)
// ══════════════════════════════════════════════════════════════════════════════

class RazorpaySignatureVerifier {
  static const String _keySecret = String.fromEnvironment('RAZORPAY_KEY_SECRET');

  /// Verifies Razorpay signature client-side (NOT RECOMMENDED FOR PRODUCTION)
  /// Always verify server-side in production
  static bool verifySignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) {
    final message = '$orderId|$paymentId';
    final expectedSignature = Hmac(sha256, utf8.encode(_keySecret))
        .convert(utf8.encode(message))
        .toString();
    return expectedSignature == signature;
  }
}
