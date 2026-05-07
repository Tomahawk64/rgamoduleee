import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:saralpooja/src/data/app_repository.dart';
import 'package:saralpooja/src/data/services.dart';
import 'package:saralpooja/src/domain/models.dart';

void main() {
  late InMemoryAppRepository repository;

  setUp(() {
    repository = InMemoryAppRepository(
      paymentService: _FakePaymentService(),
      mediaStorage: _FakeMediaStorage(),
    );
  });

  test(
    'login and offline booking use wallet ledger and protect full address from pandit assignment view',
    () async {
      await repository.signInAs(UserRole.user);
      final starting = repository.walletFor('u1').balance;

      final booking = await repository.createBooking(
        type: BookingType.offlinePandit,
        catalogueId: 'pkg1',
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
        paymentMethod: PaymentMethod.wallet,
        address: const Address(
          id: 'a1',
          userId: 'u1',
          label: 'Home',
          line1: 'Private tower and flat',
          city: 'Lucknow',
          state: 'UP',
          pincode: '226001',
        ),
      );

      expect(repository.walletFor('u1').balance, starting - booking.amount);
      expect(repository.ledgerFor('u1').last.type, LedgerType.debit);

      await repository.signInAs(UserRole.admin);
      final assigned = await repository.adminUpdateBooking(
        bookingId: booking.id,
        status: BookingStatus.panditAssigned,
        panditId: 'p1',
      );

      expect(assigned.address!.full, contains('Private tower'));
      expect(assigned.panditSafeAddress, 'Lucknow, UP - 226001');
    },
  );

  test(
    'chat booking, message image upload, warning notification, and extension flow work',
    () async {
      await repository.signInAs(UserRole.user);
      final session = await repository.bookChatSession(
        panditId: 'p1',
        minutes: 10,
        paymentMethod: PaymentMethod.wallet,
      );

      final message = await repository.sendChatMessage(
        sessionId: session.id,
        text: 'Please read this kundli.',
        imageBytes: Uint8List.fromList([1, 2, 3]),
      );

      final extended = await repository.extendChatSession(
        sessionId: session.id,
        minutes: 5,
        paymentMethod: PaymentMethod.wallet,
      );

      expect(message.imageUrl, startsWith('r2://chat/'));
      expect(repository.messagesFor(session.id), hasLength(2));
      expect(repository.chatSessionById(session.id), isNotNull);
      expect(extended.endsAt.isAfter(session.endsAt), isTrue);
    },
  );

  test('chat booking can use Razorpay without debiting wallet', () async {
    await repository.signInAs(UserRole.user);
    final starting = repository.walletFor('u1').balance;

    final session = await repository.bookChatSession(
      panditId: 'p1',
      minutes: 15,
      paymentMethod: PaymentMethod.razorpay,
    );

    expect(session.price, 375);
    expect(repository.walletFor('u1').balance, starting);
    expect(repository.ledgerFor('u1'), isEmpty);
  });

  test('cart checkout creates order and clears persistent cart', () async {
    await repository.signInAs(UserRole.user);
    await repository.addToCart('sh1', 2);
    await repository.addToCart('sh2', 1);

    final order = await repository.checkoutCart(PaymentMethod.wallet);

    expect(order.lines, hasLength(2));
    expect(order.total, 3897);
    expect(repository.cartFor('u1'), isEmpty);
  });

  test(
    'admin special pooja status and proof video are visible only within seven days',
    () async {
      await repository.signInAs(UserRole.user);
      final booking = await repository.createBooking(
        type: BookingType.specialPooja,
        catalogueId: 'sp1',
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
        paymentMethod: PaymentMethod.wallet,
      );

      await repository.signInAs(UserRole.admin);
      await repository.adminUpdateBooking(
        bookingId: booking.id,
        status: BookingStatus.completed,
        panditId: 'p1',
      );
      final proof = await repository.uploadProofVideo(
        bookingId: booking.id,
        bytes: Uint8List.fromList(List<int>.filled(1024, 4)),
        fileName: 'proof.mp4',
      );

      await repository.signInAs(UserRole.user);
      expect(
        repository.proofsFor(
          'u1',
          proof.uploadedAt.add(const Duration(days: 6)),
        ),
        hasLength(1),
      );
      expect(
        repository.proofsFor(
          'u1',
          proof.uploadedAt.add(const Duration(days: 8)),
        ),
        isEmpty,
      );
    },
  );

  test(
    'pandit cannot see wallet money or perform admin catalogue writes',
    () async {
      await repository.signInAs(UserRole.pandit);

      expect(repository.walletFor(repository.currentUser.id).balance, 0);
      expect(
        repository.upsertCatalogue(
          area: 'packages',
          item: repository.poojaPackages.first.copyWith(title: 'Changed'),
        ),
        throwsA(isA<AppException>()),
      );
    },
  );

  test(
    'assigned pandit can complete a booking without seeing payment details',
    () async {
      await repository.signInAs(UserRole.user);
      final booking = await repository.createBooking(
        type: BookingType.offlinePandit,
        catalogueId: 'pkg1',
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
        paymentMethod: PaymentMethod.wallet,
        address: const Address(
          id: 'a2',
          userId: 'u1',
          label: 'Home',
          line1: 'Exact private address',
          city: 'Lucknow',
          state: 'UP',
          pincode: '226001',
        ),
      );
      await repository.signInAs(UserRole.admin);
      await repository.adminUpdateBooking(
        bookingId: booking.id,
        status: BookingStatus.panditAssigned,
        panditId: 'p1',
      );

      await repository.signInAs(UserRole.pandit);
      final completed = await repository.adminUpdateBooking(
        bookingId: booking.id,
        status: BookingStatus.completed,
      );

      expect(completed.status, BookingStatus.completed);
      expect(completed.panditSafeAddress, 'Lucknow, UP - 226001');
      expect(repository.walletFor(repository.currentUser.id).balance, 0);
    },
  );
}

class _FakePaymentService implements PaymentService {
  @override
  Future<PaymentRecord> pay({
    required String userId,
    required int amount,
    required PaymentMethod method,
    String? referenceId,
  }) async {
    return PaymentRecord(
      id: 'fake_$referenceId',
      userId: userId,
      amount: amount,
      method: method,
      status: 'captured',
      createdAt: DateTime.now(),
      referenceId: referenceId,
    );
  }
}

class _FakeMediaStorage implements MediaStorageService {
  @override
  Future<String> uploadBytes({
    required String folder,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
    int maxBytes = 300 * 1024 * 1024,
  }) async {
    if (bytes.length > maxBytes) throw const AppException('too large');
    return 'r2://$folder/$fileName';
  }
}
