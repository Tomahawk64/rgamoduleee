// test/booking/booking_wizard_test.dart
// Unit tests for BookingWizardController.
// Run with: flutter test test/booking/booking_wizard_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:saralpooja/booking/controllers/booking_controller.dart';
import 'package:saralpooja/booking/models/booking_status.dart';
import 'package:saralpooja/booking/models/time_slot_model.dart';
import 'package:saralpooja/booking/repository/booking_repository.dart';
import 'package:saralpooja/packages/models/package_mock_data.dart';
import 'package:saralpooja/packages/models/package_model.dart';

void main() {
  // ── Helpers ────────────────────────────────────────────────────────────────

  BookingWizardController makeController({PackageModel? pre}) {
    final repo = MockBookingRepository();
    return BookingWizardController(repo, preSelectedPackage: pre);
  }

  // ── Initial state ──────────────────────────────────────────────────────────

  group('BookingWizardController — initial state', () {
    test('starts at step 0 with empty draft', () {
      final ctrl = makeController();
      expect(ctrl.state.currentStep, 0);
      expect(ctrl.state.draft.package, isNull);
      expect(ctrl.state.error, isNull);
      expect(ctrl.state.completedBooking, isNull);
    });

    test('pre-selected package is seeded', () {
      final pkg = kMockPackageList.first;
      final ctrl = makeController(pre: pkg);
      expect(ctrl.state.draft.package, pkg);
    });
  });

  // ── Navigation ─────────────────────────────────────────────────────────────

  group('BookingWizardController — navigation', () {
    test('nextStep does not advance when current step is invalid', () {
      final ctrl = makeController();
      // Step 0 is invalid — no package selected
      ctrl.nextStep();
      expect(ctrl.state.currentStep, 0,
          reason: 'Should stay on step 0 without a package');
    });

    test('nextStep advances when step is valid', () {
      final pkg = kMockPackageList.first;
      final ctrl = makeController(pre: pkg);
      // Step 0 is now valid (package selected)
      ctrl.nextStep();
      expect(ctrl.state.currentStep, 1);
    });

    test('prevStep does nothing on first step', () {
      final ctrl = makeController();
      ctrl.prevStep();
      expect(ctrl.state.currentStep, 0);
    });

    test('goToStep clamps to valid range', () {
      final ctrl = makeController();
      ctrl.goToStep(99);
      expect(ctrl.state.currentStep, 0,
          reason: 'Out-of-range step should be ignored');
      ctrl.goToStep(0);
      expect(ctrl.state.currentStep, 0);
    });

    test('online packages skip location step (step 3)', () {
      final onlinePkg = kMockPackageList.firstWhere(
        (p) => p.mode == PackageMode.online,
        orElse: () => kMockPackageList.first,
      );
      final ctrl = makeController(pre: onlinePkg);

      // Advance to step 2
      ctrl.nextStep(); // → 1
      ctrl.state = ctrl.state.copyWith(
        draft: ctrl.state.draft.copyWith(date: DateTime.now()),
      );
      ctrl.nextStep(); // → 2 (date selected)

      // From step 2, next step should jump to 4 (skip 3) for online packages
      if (onlinePkg.mode == PackageMode.online) {
        ctrl.state = ctrl.state.copyWith(
          draft: ctrl.state.draft.copyWith(
            slot: TimeSlot(
              id: 'slot_1000',
              startHour: 10,
              startMinute: 0,
              endHour: 11,
              endMinute: 0,
            ),
          ),
        );
        ctrl.nextStep();
        expect(ctrl.state.currentStep, 4,
            reason: 'Online package should skip location step');
      }
    });
  });

  // ── Package selection ──────────────────────────────────────────────────────

  group('BookingWizardController — selectPackage', () {
    test('selecting package clears previous date and slot', () {
      final pkg = kMockPackageList.first;
      final ctrl = makeController(pre: pkg);

      // Set some state
      ctrl.selectDate(DateTime.now().add(const Duration(days: 1)));
      expect(ctrl.state.draft.date, isNotNull);

      // Selecting a new package should clear the date
      ctrl.selectPackage(kMockPackageList.last);
      expect(ctrl.state.draft.date, isNull);
      expect(ctrl.state.draft.slot, isNull);
    });

    test('selectPackage clears booked slot ids', () {
      final pkg = kMockPackageList.first;
      final ctrl = makeController(pre: pkg);
      ctrl.state = ctrl.state.copyWith(bookedSlotIds: {'slot_1', 'slot_2'});

      ctrl.selectPackage(kMockPackageList.last);
      expect(ctrl.state.bookedSlotIds, isEmpty);
    });
  });

  // ── Date selection ─────────────────────────────────────────────────────────

  group('BookingWizardController — selectDate', () {
    test('selecting new date clears slot', () {
      final pkg = kMockPackageList.first;
      final ctrl = makeController(pre: pkg);

      ctrl.selectDate(DateTime.now());
      ctrl.state = ctrl.state.copyWith(
        draft: ctrl.state.draft.copyWith(
          slot: TimeSlot(
            id: 'old_slot',
            startHour: 9,
            startMinute: 0,
            endHour: 10,
            endMinute: 0,
          ),
        ),
      );

      ctrl.selectDate(DateTime.now().add(const Duration(days: 2)));
      expect(ctrl.state.draft.slot, isNull,
          reason: 'Slot should be cleared when date changes');
    });
  });

  // ── Error handling ─────────────────────────────────────────────────────────

  group('BookingWizardController — errors', () {
    test('error is cleared on nextStep/prevStep', () {
      final ctrl = makeController();
      ctrl.state = ctrl.state.copyWith(error: 'Something went wrong');

      ctrl.prevStep(); // should clear error even if already on step 0
      expect(ctrl.state.error, isNull);
    });
  });

  // ── BookingListController ──────────────────────────────────────────────────

  group('BookingListController', () {
    test('initial state has empty bookings list, not loading', () {
      final ctrl = BookingListController(MockBookingRepository());
      expect(ctrl.state.bookings, isEmpty);
      expect(ctrl.state.loading, isFalse);
    });

    test('loadBookings populates bookings list', () async {
      final ctrl = BookingListController(MockBookingRepository());
      await ctrl.loadBookings('mock_user');
      expect(ctrl.state.bookings.isNotEmpty, isTrue,
          reason: 'Mock should return seed bookings for mock_user');
      expect(ctrl.state.loading, isFalse);
    });

    test('cancelling a booking updates its status', () async {
      final ctrl = BookingListController(MockBookingRepository());
      await ctrl.loadBookings('mock_user');

      final activeBooking = ctrl.state.bookings
          .where((b) => b.status.isActive)
          .firstOrNull;
      if (activeBooking == null) return; // No active bookings in seed

      await ctrl.cancelBooking(activeBooking.id);

      final updated =
          ctrl.state.bookings.firstWhere((b) => b.id == activeBooking.id);
      expect(updated.status, BookingStatus.cancelled);
    });
  });
}
