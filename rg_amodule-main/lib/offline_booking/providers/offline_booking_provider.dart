// lib/offline_booking/providers/offline_booking_provider.dart
// State management for offline pandit booking

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../models/offline_booking_models.dart';
import '../repository/offline_booking_repository.dart';

// ── Repository Provider ───────────────────────────────────────────────────────────────

final offlineBookingRepositoryProvider = Provider<IOfflineBookingRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  // Wrap in a fallback: try Supabase first, use mock data if the table
  // doesn't exist or any Supabase error occurs.
  return FallbackOfflineBookingRepository(
    primary: SupabaseOfflineBookingRepository(client),
    fallback: MockOfflineBookingRepository(),
  );
});

// ── Pandit Search State ─────────────────────────────────────────────────────────────────

class PanditSearchState {
  const PanditSearchState({
    this.pandits = const [],
    this.loading = false,
    this.error,
    this.hasMore = true,
  });

  final List<OfflinePanditProfile> pandits;
  final bool loading;
  final String? error;
  final bool hasMore;

  PanditSearchState copyWith({
    List<OfflinePanditProfile>? pandits,
    bool? loading,
    String? error,
    bool? hasMore,
    bool clearError = false,
  }) =>
      PanditSearchState(
        pandits: pandits ?? this.pandits,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        hasMore: hasMore ?? this.hasMore,
      );
}

// ── Pandit Search Controller ───────────────────────────────────────────────────────────

class PanditSearchController extends StateNotifier<PanditSearchState> {
  PanditSearchController(this._repository) : super(const PanditSearchState());

  final IOfflineBookingRepository _repository;
  int _offset = 0;
  static const _limit = 20;

  Future<void> searchPandits({
    String? city,
    String? specialty,
    double? minRating,
    double? maxPrice,
    String? language,
    bool reset = false,
  }) async {
    if (reset) {
      _offset = 0;
      state = const PanditSearchState();
    }

    if (state.loading) return;

    state = state.copyWith(loading: true, clearError: true);

    try {
      final pandits = await _repository.searchPandits(
        city: city,
        specialty: specialty,
        minRating: minRating,
        maxPrice: maxPrice,
        language: language,
        limit: _limit,
        offset: _offset,
      );

      _offset += pandits.length;

      state = state.copyWith(
        pandits: reset ? pandits : [...state.pandits, ...pandits],
        loading: false,
        hasMore: pandits.length >= _limit,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }

  void reset() {
    _offset = 0;
    state = const PanditSearchState();
  }
}

final panditSearchProvider =
    StateNotifierProvider<PanditSearchController, PanditSearchState>((ref) {
  final repository = ref.watch(offlineBookingRepositoryProvider);
  return PanditSearchController(repository);
});

// ── Pandit Profile State ───────────────────────────────────────────────────────────────

class PanditProfileState {
  const PanditProfileState({
    this.profile,
    this.services = const [],
    this.reviews = const [],
    this.loading = false,
    this.error,
  });

  final OfflinePanditProfile? profile;
  final List<OfflinePanditService> services;
  final List<OfflinePanditReview> reviews;
  final bool loading;
  final String? error;

  PanditProfileState copyWith({
    OfflinePanditProfile? profile,
    List<OfflinePanditService>? services,
    List<OfflinePanditReview>? reviews,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      PanditProfileState(
        profile: profile ?? this.profile,
        services: services ?? this.services,
        reviews: reviews ?? this.reviews,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

// ── Pandit Profile Controller ──────────────────────────────────────────────────────────

class PanditProfileController extends StateNotifier<PanditProfileState> {
  PanditProfileController(this._repository) : super(const PanditProfileState());

  final IOfflineBookingRepository _repository;

  Future<void> loadPanditProfile(String panditId) async {
    state = state.copyWith(loading: true, clearError: true);

    try {
      final profile = await _repository.getPanditProfile(panditId);
      if (profile == null) {
        state = state.copyWith(
          loading: false,
          error: 'Pandit not found',
        );
        return;
      }

      state = state.copyWith(
        profile: profile,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadServices(String panditId) async {
    try {
      final services = await _repository.getPanditServices(panditId);
      state = state.copyWith(services: services);
    } catch (e) {
      // Don't set error for services, just log
    }
  }

  Future<void> loadReviews(String panditId) async {
    try {
      final reviews = await _repository.getPanditReviews(panditId);
      state = state.copyWith(reviews: reviews);
    } catch (e) {
      // Don't set error for reviews, just log
    }
  }

  Future<void> loadAll(String panditId) async {
    await Future.wait([
      loadPanditProfile(panditId),
      loadServices(panditId),
      loadReviews(panditId),
    ]);
  }

  void reset() {
    state = const PanditProfileState();
  }
}

final panditProfileProvider =
    StateNotifierProvider.family<PanditProfileController, PanditProfileState, String>(
  (ref, panditId) {
    final repository = ref.watch(offlineBookingRepositoryProvider);
    return PanditProfileController(repository);
  },
);

// ── Booking Creation State ─────────────────────────────────────────────────────────────

class BookingCreationState {
  const BookingCreationState({
    this.creating = false,
    this.booking,
    this.error,
  });

  final bool creating;
  final OfflineBooking? booking;
  final String? error;

  BookingCreationState copyWith({
    bool? creating,
    OfflineBooking? booking,
    String? error,
    bool clearError = false,
  }) =>
      BookingCreationState(
        creating: creating ?? this.creating,
        booking: booking ?? this.booking,
        error: clearError ? null : (error ?? this.error),
      );
}

// ── Booking Creation Controller ─────────────────────────────────────────────────────────

class BookingCreationController extends StateNotifier<BookingCreationState> {
  BookingCreationController(this._repository) : super(const BookingCreationState());

  final IOfflineBookingRepository _repository;

  Future<void> createBooking({
    required String userId,
    required String panditId,
    String? serviceId,
    required String addressLine1,
    String? addressLine2,
    required String city,
    required String state,
    required String pincode,
    String? landmark,
    required DateTime bookingDate,
    required String bookingTime,
    required String serviceName,
    String? serviceDescription,
    required double amount,
    String? specialRequirements,
    String? userNotes,
  }) async {
    final stateParam = state;
    final controllerState = this.state;
    this.state = controllerState.copyWith(creating: true, clearError: true);

    try {
      final booking = await _repository.createBooking(
        userId: userId,
        panditId: panditId,
        serviceId: serviceId,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        city: city,
        state: stateParam,
        pincode: pincode,
        landmark: landmark,
        bookingDate: bookingDate,
        bookingTime: bookingTime,
        serviceName: serviceName,
        serviceDescription: serviceDescription,
        amount: amount,
        specialRequirements: specialRequirements,
        userNotes: userNotes,
      );

      this.state = this.state.copyWith(
        creating: false,
        booking: booking,
      );
    } catch (e) {
      this.state = this.state.copyWith(
        creating: false,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = const BookingCreationState();
  }
}

final bookingCreationProvider =
    StateNotifierProvider<BookingCreationController, BookingCreationState>((ref) {
  final repository = ref.watch(offlineBookingRepositoryProvider);
  return BookingCreationController(repository);
});

// ── User Bookings State ─────────────────────────────────────────────────────────────────

class UserBookingsState {
  const UserBookingsState({
    this.bookings = const [],
    this.loading = false,
    this.error,
  });

  final List<OfflineBooking> bookings;
  final bool loading;
  final String? error;

  UserBookingsState copyWith({
    List<OfflineBooking>? bookings,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      UserBookingsState(
        bookings: bookings ?? this.bookings,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

// ── User Bookings Controller ────────────────────────────────────────────────────────────

class UserBookingsController extends StateNotifier<UserBookingsState> {
  UserBookingsController(this._repository) : super(const UserBookingsState());

  final IOfflineBookingRepository _repository;

  Future<void> loadUserBookings(String userId) async {
    state = state.copyWith(loading: true, clearError: true);

    try {
      final bookings = await _repository.getUserBookings(userId);
      state = state.copyWith(
        bookings: bookings,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = const UserBookingsState();
  }
}

final userBookingsProvider =
    StateNotifierProvider.family<UserBookingsController, UserBookingsState, String>(
  (ref, userId) {
    final repository = ref.watch(offlineBookingRepositoryProvider);
    return UserBookingsController(repository);
  },
);

// ── Pandit Bookings State ──────────────────────────────────────────────────────────────

class PanditBookingsState {
  const PanditBookingsState({
    this.pendingBookings = const [],
    this.loading = false,
    this.error,
  });

  final List<OfflineBooking> pendingBookings;
  final bool loading;
  final String? error;

  PanditBookingsState copyWith({
    List<OfflineBooking>? pendingBookings,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      PanditBookingsState(
        pendingBookings: pendingBookings ?? this.pendingBookings,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

// ── Pandit Bookings Controller ─────────────────────────────────────────────────────────

class PanditBookingsController extends StateNotifier<PanditBookingsState> {
  PanditBookingsController(this._repository) : super(const PanditBookingsState());

  final IOfflineBookingRepository _repository;

  Future<void> loadPendingBookings(String panditId) async {
    state = state.copyWith(loading: true, clearError: true);

    try {
      final bookings = await _repository.getPanditPendingBookings(panditId);
      state = state.copyWith(
        pendingBookings: bookings,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> respondToBooking({
    required String bookingId,
    required String action,
    String? panditNotes,
  }) async {
    try {
      await _repository.respondToBooking(
        bookingId: bookingId,
        action: action,
        panditNotes: panditNotes,
      );
      // Reload pending bookings after response
      if (state.pendingBookings.isNotEmpty) {
        final panditId = state.pendingBookings.first.panditId;
        await loadPendingBookings(panditId);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void reset() {
    state = const PanditBookingsState();
  }
}

final panditBookingsProvider =
    StateNotifierProvider.family<PanditBookingsController, PanditBookingsState, String>(
  (ref, panditId) {
    final repository = ref.watch(offlineBookingRepositoryProvider);
    return PanditBookingsController(repository);
  },
);
