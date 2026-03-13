import 'package:flutter/material.dart';

/// Saral Pooja — Premium spiritual services colour palette.
class AppColors {
  AppColors._();

  // ── Primary: Deep Saffron ───────────────────────────────────────────────────
  static const Color primary      = Color(0xFFD4611A); // deep saffron
  static const Color primaryDark  = Color(0xFFB04E12);
  static const Color primaryLight = Color(0xFFE87B2F);

  // ── Accent: Royal Gold ─────────────────────────────────────────────────────
  static const Color gold         = Color(0xFFBF9B30); // royal gold
  static const Color goldLight    = Color(0xFFD4AF45);

  // ── Secondary: Soft Maroon ─────────────────────────────────────────────────
  static const Color secondary    = Color(0xFF7C1E3C); // soft maroon
  static const Color secondaryLight = Color(0xFF9E2E52);

  // ── Background: Warm cream ─────────────────────────────────────────────────
  static const Color background   = Color(0xFFFBF6EF); // warm cream
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color surfaceWarm  = Color(0xFFFFF8F0); // warm white
  static const Color cardBackground = Color(0xFFFFFFFF);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF1C1008); // near-black warm
  static const Color textSecondary = Color(0xFF6B5744);
  static const Color textHint      = Color(0xFFBAAFA6);

  // ── Status ─────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF2E7D32);
  static const Color error   = Color(0xFFC62828);
  static const Color warning = Color(0xFFF57F17);
  static const Color info    = Color(0xFF0277BD);

  // ── Dark theme ─────────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF150E07);
  static const Color darkSurface    = Color(0xFF231509);
  static const Color darkCard       = Color(0xFF2C1B0C);

  // ── Divider / border ───────────────────────────────────────────────────────
  static const Color divider = Color(0xFFEFE4D6);
  static const Color border  = Color(0xFFE5D5C4);

  // ── Overlay ────────────────────────────────────────────────────────────────
  static const Color overlay = Color(0x80000000);

  // ── Gradient helpers ───────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFFE87B2F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFBF9B30), Color(0xFFD4AF45)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient saffronDeep = LinearGradient(
    colors: [Color(0xFF7C1E3C), Color(0xFFD4611A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
