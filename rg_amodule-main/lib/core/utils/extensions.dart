import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ── BuildContext Extensions ────────────────────────────────────────────────────
extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => MediaQuery.of(this).size;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  EdgeInsets get padding => MediaQuery.of(this).padding;

  bool get isSmallScreen => screenWidth < 600;
  bool get isMediumScreen => screenWidth >= 600 && screenWidth < 1024;
  bool get isLargeScreen => screenWidth >= 1024;

  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : null,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
  }
}

// ── String Extensions ──────────────────────────────────────────────────────────
extension StringExtensions on String {
  String get capitalize =>
      isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';

  String get titleCase => split(' ')
      .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
      .join(' ');

  bool get isValidEmail =>
      RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);

  bool get isValidPhone =>
      RegExp(r'^\+?[0-9]{10,15}$').hasMatch(replaceAll(' ', ''));
}

// ── DateTime Extensions ────────────────────────────────────────────────────────
extension DateTimeExtensions on DateTime {
  String get formattedDate => DateFormat('dd MMM yyyy').format(this);
  String get formattedTime => DateFormat('hh:mm a').format(this);
  String get formattedDateTime => DateFormat('dd MMM yyyy, hh:mm a').format(this);
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
}

// ── Num Extensions ─────────────────────────────────────────────────────────────
extension NumExtensions on num {
  String get toRupee => '₹${toStringAsFixed(2)}';
  Widget get heightBox => SizedBox(height: toDouble());
  Widget get widthBox => SizedBox(width: toDouble());
}
