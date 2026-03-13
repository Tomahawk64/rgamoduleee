import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../packages/models/package_model.dart';
import '../models/booking_draft.dart';
import '../models/booking_model.dart';
import '../models/time_slot_model.dart';
import '../repository/booking_repository.dart';

// ── Wizard State ──────────────────────────────────────────────────────────────

/// All state the booking wizard needs across its 7 steps.
class BookingWizardState {
  const BookingWizardState({
    this.currentStep = 0,
    this.draft = const BookingDraft(),
    this.bookedSlotIds = const {},
    this.loadingSlots = false,
    this.submitting = false,
    this.error,
    this.completedBooking,
  });

  final int currentStep;
  final BookingDraft draft;

  /// Slot IDs already taken on the selected date + package combination.
  final Set<String> bookedSlotIds;
  final bool loadingSlots;

  /// True while the final confirm/submit call is in-flight.
  final bool submitting;

  /// Non-null when a step or submission error occurs.
  final String? error;

  /// Non-null after a successful booking submission (step 6 success).
  final BookingModel? completedBooking;

  int get totalSteps => 7; // 0-based: 0…6
  bool get isLastStep => currentStep == totalSteps - 1;
  bool get isFirstStep => currentStep == 0;

  // Per-step validity gate (user cannot advance past an invalid step)
  bool get currentStepValid {
    switch (currentStep) {
      case 0: return draft.step0Valid;
      case 1: return draft.step1Valid;
      case 2: return draft.step2Valid;
      case 3: return draft.step3Valid;
      case 4: return draft.step4Valid;
      case 5: return draft.readyToConfirm; // confirm step
      case 6: return completedBooking != null; // payment step
      default: return true;
    }
  }

  BookingWizardState copyWith({
    int? currentStep,
    BookingDraft? draft,
    Set<String>? bookedSlotIds,
    bool? loadingSlots,
    bool? submitting,
    String? error,
    BookingModel? completedBooking,
    bool clearError = false,
    bool clearCompleted = false,
  }) =>
      BookingWizardState(
        currentStep:      currentStep      ?? this.currentStep,
        draft:            draft            ?? this.draft,
        bookedSlotIds:    bookedSlotIds    ?? this.bookedSlotIds,
        loadingSlots:     loadingSlots     ?? this.loadingSlots,
        submitting:       submitting       ?? this.submitting,
        error:            clearError       ? null : (error ?? this.error),
        completedBooking: clearCompleted   ? null : (completedBooking ?? this.completedBooking),
      );
}

// ── Wizard Controller ─────────────────────────────────────────────────────────

class BookingWizardController extends StateNotifier<BookingWizardState> {
  BookingWizardController(
    this._repository, {
    PackageModel? preSelectedPackage,
  }) : super(const BookingWizardState()) {
    if (preSelectedPackage != null) {
      state = state.copyWith(
        draft: state.draft.copyWith(package: preSelectedPackage),
      );
    }
  }

  final IBookingRepository _repository;

  // ── Navigation ────────────────────────────────────────────────────────────

  void nextStep() {
    if (!state.currentStepValid || state.isLastStep) {
      if (state.error != null) {
        state = state.copyWith(clearError: true);
      }
      return;
    }

    final next = _computeNextStep(state.currentStep);
    state = state.copyWith(currentStep: next, clearError: true);
  }

  void prevStep() {
    if (state.isFirstStep) {
      if (state.error != null) {
        state = state.copyWith(clearError: true);
      }
      return;
    }
    final prev = _computePrevStep(state.currentStep);
    state = state.copyWith(currentStep: prev, clearError: true);
  }

  void goToStep(int step) {
    if (step < 0 || step >= state.totalSteps) return;
    state = state.copyWith(currentStep: step, clearError: true);
  }

  /// Skip location step when package mode is online.
  int _computeNextStep(int from) {
    final next = from + 1;
    // Skip step 3 (location) for online packages
    if (next == 3 &&
        state.draft.package?.mode == PackageMode.online) {
      return 4;
    }
    return next;
  }

  int _computePrevStep(int from) {
    final prev = from - 1;
    // Skip step 3 backwards for online packages
    if (prev == 3 &&
        state.draft.package?.mode == PackageMode.online) {
      return 2;
    }
    return prev;
  }

  // ── Step 0: Package ───────────────────────────────────────────────────────

  void selectPackage(PackageModel pkg) {
    // Changing package clears date, slot, location
    state = state.copyWith(
      draft: BookingDraft(package: pkg),
      bookedSlotIds: {},
      clearError: true,
    );
  }

  // ── Step 1: Date ──────────────────────────────────────────────────────────

  void selectDate(DateTime date) {
    // Changing date clears slot and reloads availability
    state = state.copyWith(
      draft: state.draft.copyWith(date: date).clearSlot(),
      bookedSlotIds: {},
      clearError: true,
    );
    if (state.draft.package != null) {
      _loadBookedSlots(date, state.draft.package!.id);
    }
  }

  Future<void> _loadBookedSlots(DateTime date, String packageId) async {
    state = state.copyWith(loadingSlots: true, clearError: true);
    try {
      final ids = await _repository.getBookedSlotIds(date, packageId);
      state = state.copyWith(bookedSlotIds: ids, loadingSlots: false);
    } catch (_) {
      state = state.copyWith(loadingSlots: false, bookedSlotIds: {});
    }
  }

  // ── Step 2: Slot ──────────────────────────────────────────────────────────

  /// Returns false (and sets error) if [slot] is already booked.
  bool selectSlot(TimeSlot slot) {
    if (state.bookedSlotIds.contains(slot.id)) {
      state = state.copyWith(
          error: 'This slot is already booked. Please choose another time.');
      return false;
    }
    state = state.copyWith(
      draft: state.draft.copyWith(slot: slot),
      clearError: true,
    );
    return true;
  }

  // ── Step 3: Location ──────────────────────────────────────────────────────

  void setLocation(BookingLocation location) {
    state = state.copyWith(
      draft: state.draft.copyWith(location: location),
      clearError: true,
    );
  }

  // ── Step 4: Pandit ────────────────────────────────────────────────────────

  void selectPandit(PanditOption pandit) {
    final isAuto = pandit.id == 'auto';
    state = state.copyWith(
      draft: state.draft.copyWith(
        panditOption: pandit,
        isAutoAssign: isAuto,
      ),
      clearError: true,
    );
  }

  // ── Step 5: Confirm → submit booking ─────────────────────────────────────

  Future<void> submitBooking(String userId) async {
    if (!state.draft.readyToConfirm) {
      state = state.copyWith(error: 'Please complete all steps first.');
      return;
    }
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final booking = await _repository.createBooking(
        draft: state.draft,
        userId: userId,
      );
      state = state.copyWith(
        submitting: false,
        completedBooking: booking,
        currentStep: 6, // advance to payment step
      );
    } catch (e) {
      state = state.copyWith(
        submitting: false,
        error: e.toString(),
      );
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  /// Full reset — used when user starts a new booking.
  void reset() => state = const BookingWizardState();
}

// ── Booking List State ────────────────────────────────────────────────────────

class BookingListState {
  const BookingListState({
    this.bookings = const [],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<BookingModel> bookings;
  final bool loading;

  /// True while a load-more page fetch is in flight.
  final bool loadingMore;

  /// False once a page returns fewer items than [kDefaultPageSize].
  final bool hasMore;

  final String? error;

  List<BookingModel> get upcoming =>
      bookings.where((b) => b.isUpcoming).toList();
  List<BookingModel> get past =>
      bookings.where((b) => b.isPast).toList();

  BookingListState copyWith({
    List<BookingModel>? bookings,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) =>
      BookingListState(
        bookings:    bookings    ?? this.bookings,
        loading:     loading     ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        hasMore:     hasMore     ?? this.hasMore,
        error:       clearError  ? null : (error ?? this.error),
      );
}

class BookingListController extends StateNotifier<BookingListState> {
  BookingListController(this._repository) : super(const BookingListState());

  final IBookingRepository _repository;
  int _currentPage = 0;

  /// Resets pagination and fetches the first page of bookings for [userId].
  Future<void> loadBookings(String userId) async {
    _currentPage = 0;
    state = state.copyWith(loading: true, hasMore: true, clearError: true);
    try {
      final bookings = await _repository.getBookingsForUser(
        userId,
        page: 0,
        pageSize: kDefaultPageSize,
      );
      _currentPage = 1;
      state = state.copyWith(
        bookings: bookings,
        loading: false,
        hasMore: bookings.length == kDefaultPageSize,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Appends the next page of bookings for [userId].
  /// No-op when [BookingListState.hasMore] is false or already loading.
  Future<void> loadMore(String userId) async {
    if (!state.hasMore || state.loading || state.loadingMore) return;
    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final next = await _repository.getBookingsForUser(
        userId,
        page: _currentPage,
        pageSize: kDefaultPageSize,
      );
      _currentPage++;
      state = state.copyWith(
        bookings: [...state.bookings, ...next],
        loadingMore: false,
        hasMore: next.length == kDefaultPageSize,
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false, error: e.toString());
    }
  }

  Future<void> cancelBooking(String bookingId) async {
    try {
      final updated = await _repository.cancelBooking(bookingId);
      final newList = state.bookings
          .map((b) => b.id == bookingId ? updated : b)
          .toList();
      state = state.copyWith(bookings: newList);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void refresh(String userId) => loadBookings(userId);
}
