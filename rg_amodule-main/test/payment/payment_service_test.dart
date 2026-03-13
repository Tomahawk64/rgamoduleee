// test/payment/payment_service_test.dart
// Unit tests for MockPaymentService and PaymentController.
// Run with: flutter test test/payment/payment_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saralpooja/payment/payment_service.dart';
import 'package:saralpooja/payment/payment_provider.dart';

void main() {
  // ── MockPaymentService ─────────────────────────────────────────────────────

  group('MockPaymentService', () {
    late IPaymentService service;

    setUp(() => service = MockPaymentService());

    test('initiatePayment returns success status', () async {
      final result = await service.initiatePayment(
        PaymentRequest(
          orderId: 'order_001',
          amountPaise: 50000,
          description: 'Rudrabhishek Puja',
          customerName: 'Ravi Sharma',
          customerEmail: 'ravi@example.com',
          customerPhone: '9876543210',
        ),
      );

      expect(result.status, PaymentStatus.success);
      expect(result.transactionId, isNotEmpty);
      expect(result.errorMessage, isNull);
    });

    test('transactionId is unique across calls', () async {
      final req = PaymentRequest(
        orderId: 'order_002',
        amountPaise: 10000,
        description: 'Test',
        customerName: 'User',
        customerEmail: 'u@test.com',
        customerPhone: '9000000000',
      );
      final r1 = await service.initiatePayment(req);
      final r2 = await service.initiatePayment(req);
      expect(r1.transactionId, isNot(equals(r2.transactionId)));
    });

    test('verifyPayment returns true for valid ids', () async {
      final ok = await service.verifyPayment(
        orderId: 'order_001',
        paymentId: 'pay_mock_123',
        signature: 'sig_mock_456',
      );
      expect(ok, isTrue);
    });

    test('payment request captures amount', () {
      final req = PaymentRequest(
        orderId: 'ord_test',
        amountPaise: 250000,
        description: 'Navgraha Shanti',
        customerName: 'Test User',
        customerEmail: 'test@gmail.com',
        customerPhone: '8888888888',
        metadata: {'ref': 'book_001'},
      );
      expect(req.amountRupees, 2500.0);
      expect(req.metadata['ref'], 'book_001');
    });
  });

  // ── PaymentController ──────────────────────────────────────────────────────

  group('PaymentController', () {
    ProviderContainer makeContainer() => ProviderContainer(
          overrides: [
            paymentServiceProvider.overrideWithValue(MockPaymentService()),
          ],
        );

    test('initial state is idle', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final state = container.read(paymentProvider);
      expect(state.status, PaymentStatus.idle);
      expect(state.errorMessage, isNull);
      expect(state.result, isNull);
    });

    test('pay transitions to processing then success', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(paymentProvider.notifier);
      await ctrl.pay(
        PaymentRequest(
          orderId: 'ord_ctrl_test',
          amountPaise: 75000,
          description: 'Booking payment',
          customerName: 'Priya',
          customerEmail: 'priya@test.com',
          customerPhone: '7777777777',
        ),
      );

      final state = container.read(paymentProvider);
      expect(state.status, PaymentStatus.success);
      expect(state.result?.transactionId, isNotEmpty);
    });

    test('reset clears state back to idle', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(paymentProvider.notifier);
      await ctrl.pay(
        PaymentRequest(
          orderId: 'ord_reset',
          amountPaise: 5000,
          description: 'reset test',
          customerName: 'A',
          customerEmail: 'a@b.com',
          customerPhone: '6666666666',
        ),
      );
      ctrl.reset();

      final state = container.read(paymentProvider);
      expect(state.status, PaymentStatus.idle);
    });
  });
}
