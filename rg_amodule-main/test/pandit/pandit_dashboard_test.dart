// test/pandit/pandit_dashboard_test.dart
// Automated tests for pandit dashboard (no earnings, toggles working)

import 'package:flutter_test/flutter_test.dart';
import 'package:saralpooja/pandit/controllers/pandit_dashboard_controller.dart';
import 'package:saralpooja/pandit/models/pandit_dashboard_models.dart';

void main() {
  group('PanditDashboardState Tests', () {
    test('State should NOT contain earnings field', () {
      final state = PanditDashboardState();
      
      // Verify state has the correct fields
      expect(state.profile, isNull);
      expect(state.loading, isFalse); // Default is false now
      expect(state.error, isNull);
      expect(state.togglingOnline, isFalse);
      expect(state.togglingOfflineBooking, isFalse);
      
      // Verify no earnings property exists in the state
      // The state should only have: assignments, profile, consultationEnabled, loading,
      // togglingConsultation, togglingOnline, togglingOfflineBooking, error
      expect(state.assignments, isEmpty);
      expect(state.consultationEnabled, isFalse);
      expect(state.togglingConsultation, isFalse);
    });

    test('copyWith creates correct state without earnings', () {
      final state = PanditDashboardState();
      final newState = state.copyWith(
        loading: false,
        error: 'test error',
      );
      
      expect(newState.loading, isFalse);
      expect(newState.error, 'test error');
      expect(newState.profile, isNull);
      expect(newState.toString().contains('earnings'), isFalse);
    });

    test('PanditProfile should have offlineBookingEnabled field', () {
      final profile = PanditProfile(
        id: 'test-id',
        name: 'Test Pandit',
        specialties: ['Puja', 'Havan'],
        rating: 4.5,
        totalBookings: 10,
        consultationEnabled: true,
        offlineBookingEnabled: true, // New field
        yearsExperience: 5,
        languages: ['Hindi', 'English'],
        isOnline: false,
      );
      
      expect(profile.offlineBookingEnabled, isTrue);
      expect(profile.id, 'test-id');
      expect(profile.name, 'Test Pandit');
      expect(profile.specialties, ['Puja', 'Havan']);
      expect(profile.rating, 4.5);
    });

    test('PanditProfile copyWith updates offlineBookingEnabled', () {
      final profile = PanditProfile(
        id: 'test-id',
        name: 'Test Pandit',
        specialties: ['Puja', 'Havan'],
        rating: 4.5,
        totalBookings: 10,
        consultationEnabled: true,
        offlineBookingEnabled: true,
        yearsExperience: 5,
        languages: ['Hindi', 'English'],
        isOnline: false,
      );
      
      final updatedProfile = profile.copyWith(
        offlineBookingEnabled: false,
      );
      
      expect(updatedProfile.offlineBookingEnabled, isFalse);
      expect(updatedProfile.name, 'Test Pandit'); // Other fields unchanged
      expect(updatedProfile.id, 'test-id');
      expect(updatedProfile.specialties, ['Puja', 'Havan']);
    });

    test('PanditProfile copyWith updates isOnline', () {
      final profile = PanditProfile(
        id: 'test-id',
        name: 'Test Pandit',
        specialties: ['Puja', 'Havan'],
        rating: 4.5,
        totalBookings: 10,
        consultationEnabled: true,
        offlineBookingEnabled: true,
        yearsExperience: 5,
        languages: ['Hindi', 'English'],
        isOnline: false,
      );
      
      final updatedProfile = profile.copyWith(
        isOnline: true,
      );
      
      expect(updatedProfile.isOnline, isTrue);
      expect(updatedProfile.offlineBookingEnabled, isTrue); // Unchanged
    });
  });

  group('PanditDashboard Features', () {
    test('EarningsSummary model still exists but not used in dashboard', () {
      // EarningsSummary model exists in the codebase but is not used
      // in the PanditDashboardState (which we removed)
      final earnings = EarningsSummary.zero();
      
      expect(earnings.totalEarnedPaise, 0);
      expect(earnings.thisMonthPaise, 0);
      expect(earnings.formattedTotal, '₹0');
    });

    test('Profile with both toggles enabled', () {
      final profile = PanditProfile(
        id: 'test-id',
        name: 'Test Pandit',
        specialties: ['Puja'],
        rating: 4.5,
        totalBookings: 10,
        isOnline: true, // Online toggle ON
        consultationEnabled: true,
        offlineBookingEnabled: true, // Offline booking toggle ON
        yearsExperience: 5,
        languages: ['Hindi'],
      );
      
      expect(profile.isOnline, isTrue);
      expect(profile.offlineBookingEnabled, isTrue);
      expect(profile.consultationEnabled, isTrue);
    });

    test('Profile with both toggles disabled', () {
      final profile = PanditProfile(
        id: 'test-id',
        name: 'Test Pandit',
        specialties: ['Puja'],
        rating: 4.5,
        totalBookings: 10,
        isOnline: false, // Online toggle OFF
        consultationEnabled: false,
        offlineBookingEnabled: false, // Offline booking toggle OFF
        yearsExperience: 5,
        languages: ['Hindi'],
      );
      
      expect(profile.isOnline, isFalse);
      expect(profile.offlineBookingEnabled, isFalse);
      expect(profile.consultationEnabled, isFalse);
    });

    test('Profile initials generation', () {
      final profile1 = PanditProfile(
        id: 'test-id',
        name: 'Shivendra Shastri',
        specialties: ['Puja'],
        rating: 4.5,
        totalBookings: 10,
        consultationEnabled: true,
        offlineBookingEnabled: true,
        yearsExperience: 5,
        languages: ['Hindi'],
        isOnline: false,
      );
      
      expect(profile1.initials, 'SS');
      
      final profile2 = PanditProfile(
        id: 'test-id',
        name: 'Ram',
        specialties: ['Puja'],
        rating: 4.5,
        totalBookings: 10,
        consultationEnabled: true,
        offlineBookingEnabled: true,
        yearsExperience: 5,
        languages: ['Hindi'],
        isOnline: false,
      );
      
      expect(profile2.initials, 'RA'); // Takes first 2 chars if single name
    });
  });
}
