import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// DivinePooja — premium Material 3 theme.
/// Fonts: Playfair Display (headings) · Inter (body)
class AppTheme {
  AppTheme._();

  // ── Text Theme helpers ───────────────────────────────────────────────────────
  static TextTheme _buildTextTheme({required bool dark}) {
    final baseColor = dark ? Colors.white : AppColors.textPrimary;
    final subColor  = dark ? Colors.white70 : AppColors.textSecondary;
    return TextTheme(
      displayLarge:  GoogleFonts.playfairDisplay(fontSize: 48, fontWeight: FontWeight.w700, color: baseColor),
      displayMedium: GoogleFonts.playfairDisplay(fontSize: 40, fontWeight: FontWeight.w700, color: baseColor),
      displaySmall:  GoogleFonts.playfairDisplay(fontSize: 32, fontWeight: FontWeight.w600, color: baseColor),
      headlineLarge: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.w700, color: baseColor),
      headlineMedium:GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.w600, color: baseColor),
      headlineSmall: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w600, color: baseColor),
      titleLarge:  GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: baseColor),
      titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: baseColor),
      titleSmall:  GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: baseColor),
      bodyLarge:   GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: baseColor),
      bodyMedium:  GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: baseColor),
      bodySmall:   GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: subColor),
      labelLarge:  GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: baseColor),
      labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: subColor),
      labelSmall:  GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: subColor, letterSpacing: 0.4),
    );
  }

  // ── Light Theme ─────────────────────────────────────────────────────────────
  static ThemeData get light {
    final textTheme = _buildTextTheme(dark: false);
    final cs = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: cs,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.playfairDisplay(
            color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceWarm,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.error)),
        hintStyle: GoogleFonts.inter(color: AppColors.textHint, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        elevation: 0,
        height: 64,
        iconTheme: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
            ? const IconThemeData(color: AppColors.primary, size: 24)
            : IconThemeData(color: AppColors.textSecondary.withValues(alpha: 0.7), size: 24)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
            ? GoogleFonts.inter(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)
            : GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceWarm,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Dark Theme ───────────────────────────────────────────────────────────────
  static ThemeData get dark {
    final textTheme = _buildTextTheme(dark: true);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      textTheme: textTheme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primaryLight,
        secondary: AppColors.secondaryLight,
        surface: AppColors.darkSurface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.playfairDisplay(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.2),
        elevation: 0,
        height: 64,
        iconTheme: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
            ? const IconThemeData(color: AppColors.primaryLight, size: 24)
            : const IconThemeData(color: Colors.white54, size: 24)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
            ? GoogleFonts.inter(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w700)
            : GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
      ),
    );
  }
}
