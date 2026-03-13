// test/special_poojas/special_poojas_filter_test.dart
// Unit tests for SpecialPoojasFilter provider logic.
// Run with: flutter test test/special_poojas/special_poojas_filter_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saralpooja/special_poojas/models/special_pooja_model.dart';
import 'package:saralpooja/special_poojas/providers/special_poojas_provider.dart';

void main() {
  group('SpecialPoojasFilter — mock data filtering', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('returns all items when no filter applied', () {
      final all = container.read(filteredSpecialPoojasProvider);
      expect(all.length, kMockSpecialPoojas.length);
    });

    test('search filters by title', () {
      container
          .read(specialPoojasFilterProvider.notifier)
          .setSearch('Rudrabhishek');

      final filtered = container.read(filteredSpecialPoojasProvider);
      expect(filtered.isNotEmpty, isTrue);
      expect(
        filtered.every((p) =>
            p.title.toLowerCase().contains('rudrabhishek') ||
            p.description.toLowerCase().contains('rudrabhishek')),
        isTrue,
      );
    });

    test('search is case-insensitive', () {
      container
          .read(specialPoojasFilterProvider.notifier)
          .setSearch('LAKSHMI');

      final filtered = container.read(filteredSpecialPoojasProvider);
      expect(filtered.isNotEmpty, isTrue);
    });

    test('empty search returns all items', () {
      container
          .read(specialPoojasFilterProvider.notifier)
          .setSearch('XYZ_NOEXIST_12345');

      final empty = container.read(filteredSpecialPoojasProvider);
      container
          .read(specialPoojasFilterProvider.notifier)
          .setSearch('');
      final all = container.read(filteredSpecialPoojasProvider);
      expect(all.length, kMockSpecialPoojas.length);
      expect(empty.isEmpty, isTrue);
    });

    test('city filter returns only matching city', () {
      final withLocation = kMockSpecialPoojas.firstWhere(
        (p) => p.location != null,
      );
      final city = withLocation.location!.city;
      container
          .read(specialPoojasFilterProvider.notifier)
          .setCity(city);

      final filtered = container.read(filteredSpecialPoojasProvider);
      expect(filtered.isNotEmpty, isTrue);
      expect(
        filtered.every((p) =>
            p.location?.city.toLowerCase() == city.toLowerCase()),
        isTrue,
      );
    });

    test('city filter is case-insensitive', () {
      final withLocation = kMockSpecialPoojas.firstWhere(
        (p) => p.location != null,
      );
      final city = withLocation.location!.city;
      container
          .read(specialPoojasFilterProvider.notifier)
          .setCity(city.toUpperCase());

      final filtered = container.read(filteredSpecialPoojasProvider);
      expect(filtered.isNotEmpty, isTrue);
    });

    test('clearing city filter restores all items', () {
      final withLocation = kMockSpecialPoojas.firstWhere(
        (p) => p.location != null,
      );
      final city = withLocation.location!.city;
      container
          .read(specialPoojasFilterProvider.notifier)
          .setCity(city);
      container
          .read(specialPoojasFilterProvider.notifier)
          .setCity('');

      final all = container.read(filteredSpecialPoojasProvider);
      expect(all.length, kMockSpecialPoojas.length);
    });

    test('filter reset restores all items', () {
      container
          .read(specialPoojasFilterProvider.notifier)
          .setSearch('Navgraha');
      expect(container.read(filteredSpecialPoojasProvider).length,
          lessThan(kMockSpecialPoojas.length));

      container.read(specialPoojasFilterProvider.notifier).reset();
      expect(container.read(filteredSpecialPoojasProvider).length,
          kMockSpecialPoojas.length);
    });
  });

  // ── SpecialPoojaModel ──────────────────────────────────────────────────────

  group('SpecialPoojaModel', () {
    test('priceLabel formats correctly', () {
      final pooja = kMockSpecialPoojas.first;
      expect(pooja.priceLabel, startsWith('₹'));
    });

    test('durationMinutes is positive', () {
      for (final pooja in kMockSpecialPoojas) {
        expect(pooja.durationMinutes, greaterThan(0));
      }
    });

    test('availabilitySlots are valid', () {
      for (final pooja in kMockSpecialPoojas) {
        for (final slot in pooja.availabilitySlots) {
          expect(slot.totalSlots, greaterThan(0));
          expect(slot.bookedSlots, greaterThanOrEqualTo(0));
        }
      }
    });

    test('templeLocation city is non-empty when present', () {
      for (final pooja in kMockSpecialPoojas) {
        if (pooja.location != null) {
          expect(pooja.location!.city.isNotEmpty, isTrue);
        }
      }
    });
  });
}
