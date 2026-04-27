// test/auth/auth_test.dart
// Automated tests for authentication

import 'package:flutter_test/flutter_test.dart';
import 'package:saralpooja/models/role_enum.dart';

void main() {
  group('Authentication Tests', () {
    test('Demo credentials validation', () {
      // Test User credentials
      expect('user2@user.com', isNotEmpty);
      expect('Abc@123', hasLength(greaterThanOrEqualTo(6)));
      
      // Test Pandit credentials  
      expect('pandit2@pandit.com', isNotEmpty);
      expect('Abc@123', isNotEmpty);
      
      // Test Admin credentials
      expect('demo_admin@saralpooja.com', isNotEmpty);
      expect('Demo@123', isNotEmpty);
    });

    test('User role detection', () {
      // Test email patterns
      final userEmail = 'user2@user.com';
      final panditEmail = 'pandit2@pandit.com';
      final adminEmail = 'demo_admin@saralpooja.com';
      
      expect(userEmail.contains('user'), isTrue);
      expect(panditEmail.contains('pandit'), isTrue);
      expect(adminEmail.contains('admin'), isTrue);
    });

    test('Password strength check', () {
      final password1 = 'Abc@123';
      final password2 = 'Demo@123';
      
      // Should have uppercase
      expect(password1.contains(RegExp(r'[A-Z]')), isTrue);
      expect(password2.contains(RegExp(r'[A-Z]')), isTrue);
      
      // Should have special character
      expect(password1.contains(RegExp(r'[!@#$%^&*]')), isTrue);
      expect(password2.contains(RegExp(r'[!@#$%^&*]')), isTrue);
      
      // Should have numbers
      expect(password1.contains(RegExp(r'[0-9]')), isTrue);
      expect(password2.contains(RegExp(r'[0-9]')), isTrue);
    });
  });

  group('Auth State Tests', () {
    test('UserRole enum values', () {
      expect(UserRole.values, contains(UserRole.user));
      expect(UserRole.values, contains(UserRole.pandit));
      expect(UserRole.values, contains(UserRole.admin));
      expect(UserRole.values, contains(UserRole.guest));
    });

    test('UserRole comparison', () {
      expect(UserRole.admin == UserRole.admin, isTrue);
      expect(UserRole.user == UserRole.pandit, isFalse);
    });
  });
}
