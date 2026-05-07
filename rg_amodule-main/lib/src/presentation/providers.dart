import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import '../data/app_repository.dart';
import '../data/services.dart';
import '../data/supabase_app_repository.dart';
import '../domain/models.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final repositoryProvider = Provider<AppRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final hasSupabaseClient = config.hasSupabase;
  if (hasSupabaseClient) {
    final client = Supabase.instance.client;
    return SupabaseAppRepository(
      client: client,
      paymentService: RazorpayPaymentGateway(config, client: client),
      mediaStorage: CloudflareR2MediaStorage(config: config, client: client),
    );
  }
  return InMemoryAppRepository(
    paymentService: RazorpayPaymentGateway(config),
    mediaStorage: CloudflareR2MediaStorage(config: config),
  );
});

final appControllerProvider = StateNotifierProvider<AppController, AppSnapshot>(
  (ref) {
    return AppController(ref.watch(repositoryProvider));
  },
);

class AppSnapshot {
  const AppSnapshot({
    required this.user,
    required this.wallet,
    required this.cartCount,
    required this.loading,
    required this.isAuthenticated,
    this.error,
  });

  final AppUser user;
  final Wallet wallet;
  final int cartCount;
  final bool loading;
  final bool isAuthenticated;
  final String? error;

  AppSnapshot copyWith({
    AppUser? user,
    Wallet? wallet,
    int? cartCount,
    bool? loading,
    bool? isAuthenticated,
    String? error,
  }) {
    return AppSnapshot(
      user: user ?? this.user,
      wallet: wallet ?? this.wallet,
      cartCount: cartCount ?? this.cartCount,
      loading: loading ?? this.loading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
    );
  }
}

class AppController extends StateNotifier<AppSnapshot> {
  AppController(this.repository)
    : super(
        AppSnapshot(
          user: repository.currentUser,
          wallet: repository.walletFor(repository.currentUser.id),
          cartCount: repository.cartFor(repository.currentUser.id).length,
          loading: false,
          isAuthenticated: repository.isAuthenticated,
        ),
      ) {
    unawaited(bootstrap());
  }

  final AppRepository repository;

  Future<void> bootstrap() async {
    await _guard(() async {
      await repository.reload();
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    await _guard(() async {
      await repository.signIn(email: email, password: password);
    });
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    await _guard(() async {
      await repository.signUp(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
    });
  }

  Future<void> signInAs(UserRole role) async {
    await _guard(() async {
      await repository.signInAs(role);
    });
  }

  Future<void> signOut() async {
    await _guard(() async {
      await repository.signOut();
    });
  }

  Future<Booking?> createBooking({
    required BookingType type,
    required String catalogueId,
    required DateTime scheduledAt,
    required PaymentMethod paymentMethod,
    Address? address,
    String notes = '',
  }) async {
    Booking? booking;
    await _guard(() async {
      booking = await repository.createBooking(
        type: type,
        catalogueId: catalogueId,
        scheduledAt: scheduledAt,
        paymentMethod: paymentMethod,
        address: address,
        notes: notes,
      );
    });
    return booking;
  }

  Future<void> topUpWallet(int amount) async {
    await _guard(() async {
      await repository.topUpWallet(state.user.id, amount);
    });
  }

  Future<void> addToCart(String itemId) async {
    await _guard(() async {
      await repository.addToCart(itemId, 1);
    });
  }

  Future<void> updateCart(String itemId, int quantity) async {
    await _guard(() async {
      await repository.updateCart(itemId, quantity);
    });
  }

  Future<ShopOrder?> checkout(PaymentMethod method) async {
    ShopOrder? order;
    await _guard(() async {
      order = await repository.checkoutCart(method);
    });
    return order;
  }

  Future<ChatSession?> bookChat(
    String panditId,
    int minutes, {
    PaymentMethod paymentMethod = PaymentMethod.wallet,
  }) async {
    ChatSession? session;
    await _guard(() async {
      session = await repository.bookChatSession(
        panditId: panditId,
        minutes: minutes,
        paymentMethod: paymentMethod,
      );
    });
    return session;
  }

  Future<void> extendChat(String sessionId, int minutes) async {
    await _guard(() async {
      await repository.extendChatSession(
        sessionId: sessionId,
        minutes: minutes,
        paymentMethod: PaymentMethod.wallet,
      );
    });
  }

  Future<void> sendMessage(String sessionId, String text) async {
    await _guard(() async {
      await repository.sendChatMessage(sessionId: sessionId, text: text);
    });
  }

  Future<void> sendImageMessage(
    String sessionId, {
    required String text,
    required Uint8List bytes,
  }) async {
    await _guard(() async {
      await repository.sendChatMessage(
        sessionId: sessionId,
        text: text,
        imageBytes: bytes,
      );
    });
  }

  Future<void> adminUpdate(
    String bookingId,
    BookingStatus status, {
    String? panditId,
  }) async {
    await _guard(() async {
      await repository.adminUpdateBooking(
        bookingId: bookingId,
        status: status,
        panditId: panditId,
      );
    });
  }

  Future<void> uploadProof(String bookingId) async {
    await _guard(() async {
      await repository.uploadProofVideo(
        bookingId: bookingId,
        bytes: Uint8List.fromList(List<int>.filled(128, 1)),
        fileName: 'proof.mp4',
      );
    });
  }

  Future<void> uploadProofBytes(
    String bookingId, {
    required Uint8List bytes,
    required String fileName,
  }) async {
    await _guard(() async {
      await repository.uploadProofVideo(
        bookingId: bookingId,
        bytes: bytes,
        fileName: fileName,
      );
    });
  }

  Future<void> _guard(Future<void> Function() action) async {
    state = state.copyWith(loading: true);
    try {
      await action();
      _refresh();
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  void _refresh() {
    state = AppSnapshot(
      user: repository.currentUser,
      wallet: repository.walletFor(repository.currentUser.id),
      cartCount: repository.cartFor(repository.currentUser.id).length,
      loading: false,
      isAuthenticated: repository.isAuthenticated,
    );
  }
}
