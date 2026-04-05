// lib/widgets/country_phone_field.dart
// Shared country dial-code model + phone/pincode helpers used across the app.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class CountryDialCode {
  final String name;
  final String flag;
  final String dialCode;
  final int phoneLength;
  final int postalCodeLength;

  const CountryDialCode({
    required this.name,
    required this.flag,
    required this.dialCode,
    required this.phoneLength,
    required this.postalCodeLength,
  });
}

const kCountryList = <CountryDialCode>[
  CountryDialCode(name: 'India',          flag: '🇮🇳', dialCode: '+91',  phoneLength: 10, postalCodeLength: 6),
  CountryDialCode(name: 'United States',  flag: '🇺🇸', dialCode: '+1',   phoneLength: 10, postalCodeLength: 5),
  CountryDialCode(name: 'United Kingdom', flag: '🇬🇧', dialCode: '+44',  phoneLength: 10, postalCodeLength: 7),
  CountryDialCode(name: 'UAE',            flag: '🇦🇪', dialCode: '+971', phoneLength: 9,  postalCodeLength: 5),
  CountryDialCode(name: 'Australia',      flag: '🇦🇺', dialCode: '+61',  phoneLength: 9,  postalCodeLength: 4),
  CountryDialCode(name: 'Canada',         flag: '🇨🇦', dialCode: '+1',   phoneLength: 10, postalCodeLength: 6),
  CountryDialCode(name: 'Singapore',      flag: '🇸🇬', dialCode: '+65',  phoneLength: 8,  postalCodeLength: 6),
];

/// Show a bottom sheet for the user to pick a country.
Future<void> showCountryPicker({
  required BuildContext context,
  required CountryDialCode selected,
  required ValueChanged<CountryDialCode> onSelected,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ListView(
      shrinkWrap: true,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Select Country',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 4),
        ...kCountryList.map(
          (c) => ListTile(
            leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
            title: Text(c.name),
            trailing: Text(
              c.dialCode,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            selected: c.name == selected.name,
            selectedColor: AppColors.primary,
            onTap: () {
              onSelected(c);
              Navigator.of(ctx).pop();
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}

// ── Reusable phone field ───────────────────────────────────────────────────────

/// A TextFormField with a tappable flag+dialCode prefix that opens the country
/// picker. Validates exact digit length per country.
class CountryPhoneFormField extends StatelessWidget {
  const CountryPhoneFormField({
    super.key,
    required this.controller,
    required this.country,
    required this.onCountryTap,
    this.decoration,
  });

  final TextEditingController controller;
  final CountryDialCode country;
  final VoidCallback onCountryTap;
  final InputDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: country.phoneLength,
      validator: (v) {
        final digits = v?.trim() ?? '';
        if (digits.isEmpty) return 'Phone is required';
        if (digits.length != country.phoneLength) {
          return 'Enter a valid ${country.phoneLength}-digit number for ${country.name}';
        }
        return null;
      },
      decoration: (decoration ?? const InputDecoration()).copyWith(
        labelText: 'Phone Number',
        counterText: '',
        prefixIcon: GestureDetector(
          onTap: onCountryTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(country.flag, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  country.dialCode,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
