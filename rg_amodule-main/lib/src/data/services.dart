import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import '../domain/models.dart';

class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract class PaymentService {
  Future<PaymentRecord> pay({
    required String userId,
    required int amount,
    required PaymentMethod method,
    String? referenceId,
  });
}

class RazorpayPaymentGateway implements PaymentService {
  const RazorpayPaymentGateway(this.config, {this.client});

  final AppConfig config;
  final SupabaseClient? client;

  @override
  Future<PaymentRecord> pay({
    required String userId,
    required int amount,
    required PaymentMethod method,
    String? referenceId,
  }) async {
    if (amount <= 0) {
      throw const AppException('Payment amount must be greater than zero.');
    }
    if (method == PaymentMethod.razorpay && !config.hasRazorpay) {
      throw const AppException('Razorpay key is not configured.');
    }
    if (method == PaymentMethod.razorpay && client != null) {
      final response = await client!.functions.invoke(
        'create-razorpay-order',
        body: {
          'amount_paise': amount * 100,
          'customer_id': userId,
          'description': referenceId ?? 'Saral Pooja payment',
          'metadata': {'app_order_id': referenceId, 'user_id': userId},
        },
      );
      final data = response.data;
      if (data is! Map || data['order_id'] == null) {
        throw const AppException('Razorpay order creation failed.');
      }
      final orderId = data['order_id'] as String;
      final checkout = Razorpay();
      final completer = Completer<PaymentRecord>();

      checkout.on(Razorpay.EVENT_PAYMENT_SUCCESS, (
        PaymentSuccessResponse response,
      ) async {
        try {
          final paymentId = response.paymentId;
          final signature = response.signature;
          if (paymentId == null || signature == null) {
            throw const AppException('Razorpay callback was incomplete.');
          }
          final verification = await client!.functions.invoke(
            'verify-razorpay-payment-v2',
            body: {
              'razorpay_order_id': orderId,
              'razorpay_payment_id': paymentId,
              'razorpay_signature': signature,
            },
          );
          final verificationData = verification.data;
          if (verificationData is! Map ||
              verificationData['verified'] != true) {
            throw const AppException('Razorpay payment verification failed.');
          }
          completer.complete(
            PaymentRecord(
              id: orderId,
              userId: userId,
              amount: amount,
              method: method,
              status: 'captured',
              createdAt: DateTime.now(),
              referenceId: referenceId,
              providerOrderId: orderId,
              providerPaymentId: paymentId,
              providerSignature: signature,
            ),
          );
        } catch (error, stackTrace) {
          completer.completeError(error, stackTrace);
        }
      });
      checkout.on(Razorpay.EVENT_PAYMENT_ERROR, (
        PaymentFailureResponse response,
      ) {
        completer.completeError(
          AppException(response.message ?? 'Razorpay payment failed.'),
        );
      });
      checkout.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {
        completer.completeError(
          const AppException('External wallet payments are not supported.'),
        );
      });

      checkout.open({
        'key': config.razorpayKeyId,
        'amount': amount * 100,
        'currency': 'INR',
        'name': 'Saral Pooja',
        'description': referenceId ?? 'Saral Pooja payment',
        'order_id': orderId,
        'retry': {'enabled': true, 'max_count': 1},
        'theme': {'color': '#E8892E'},
      });
      return completer.future.whenComplete(checkout.clear);
    }
    if (method == PaymentMethod.razorpay) {
      throw const AppException('Supabase is required for Razorpay payments.');
    }
    if (method == PaymentMethod.wallet) {
      return PaymentRecord(
        id: 'pay_${DateTime.now().microsecondsSinceEpoch}',
        userId: userId,
        amount: amount,
        method: method,
        status: 'captured',
        createdAt: DateTime.now(),
        referenceId: referenceId,
      );
    }
    throw const AppException('Unsupported payment method.');
  }
}

abstract class MediaStorageService {
  Future<String> uploadBytes({
    required String folder,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
    int maxBytes,
  });
}

class CloudflareR2MediaStorage implements MediaStorageService {
  CloudflareR2MediaStorage({required this.config, this.client});

  final AppConfig config;
  final SupabaseClient? client;

  @override
  Future<String> uploadBytes({
    required String folder,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
    int maxBytes = 300 * 1024 * 1024,
  }) async {
    if (bytes.length > maxBytes) {
      throw const AppException('Selected media exceeds the allowed size.');
    }
    if (config.cloudflareUploadFunction.isEmpty || client == null) {
      return 'r2://$folder/$fileName';
    }
    final response = await client!.functions.invoke(
      config.cloudflareUploadFunction,
      body: {
        'folder': folder,
        'fileName': fileName,
        'contentType': contentType,
        'sizeBytes': bytes.length,
      },
    );
    final data = response.data;
    if (data is Map && data['uploadUrl'] is String) {
      await Dio().put<void>(
        data['uploadUrl'] as String,
        data: Stream.fromIterable([bytes]),
        options: Options(headers: {'Content-Type': contentType}),
      );
      final url =
          data['downloadUrl'] ?? data['publicUrl'] ?? data['storageKey'];
      if (url is String) return url;
    }
    throw const AppException('Cloudflare upload failed.');
  }
}

class SessionTimerService {
  Stream<Duration> countdown(
    ChatSession session, {
    Duration tick = const Duration(seconds: 1),
  }) async* {
    while (true) {
      final remaining = session.remaining(DateTime.now());
      yield remaining;
      if (remaining == Duration.zero) {
        break;
      }
      await Future<void>.delayed(tick);
    }
  }
}
