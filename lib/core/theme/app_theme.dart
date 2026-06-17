import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1E3A5F);
  static const Color secondary = Color(0xFF60A5FA);
  static const Color accent = Color(0xFF7DD3FC);
  static const Color background = Color(0xFFF4F9FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEEF6FC);
  static const Color onSurface = Color(0xFF1A2B3D);
  static const Color onSurfaceVariant = Color(0xFF5A6B7D);
  static const Color outline = Color(0xFFB8D4EE);
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color textPrimary = Color(0xFF1A2B3D);
  static const Color textSecondary = Color(0xFF5A6B7D);

  // Dark mode colors
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceVariant = Color(0xFF334155);
  static const Color darkOnSurface = Color(0xFFE2E8F0);

  static ThemeData lightTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFDCEBFF),
        onPrimaryContainer: primaryDark,
        secondary: secondary,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFE8F4FF),
        onSecondaryContainer: Color(0xFF1E3A5F),
        tertiary: accent,
        onTertiary: Colors.white,
        tertiaryContainer: Color(0xFFE0F2FE),
        onTertiaryContainer: Color(0xFF1E3A5F),
        error: error,
        onError: Colors.white,
        errorContainer: Color(0xFFFFEDED),
        onErrorContainer: error,
        surface: surface,
        onSurface: onSurface,
        surfaceContainerHighest: surfaceVariant,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        shadow: Colors.black12,
        inverseSurface: onSurface,
        onInverseSurface: surface,
        inversePrimary: accent,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: onSurface,
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        indicatorColor: const Color(0xFFDCEBFF),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: primary,
            );
          }
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: onSurfaceVariant,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        filled: true,
        fillColor: surfaceVariant.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: outline),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: surface,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: outline,
        thickness: 0.5,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData darkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF60A5FA),
        onPrimary: Color(0xFF1E3A5F),
        primaryContainer: Color(0xFF1E40AF),
        onPrimaryContainer: Color(0xFFDCEBFF),
        secondary: Color(0xFF93C5FD),
        onSecondary: Color(0xFF1E3A5F),
        secondaryContainer: Color(0xFF1E3A5F),
        onSecondaryContainer: Color(0xFFBFDBFE),
        tertiary: Color(0xFF7DD3FC),
        onTertiary: Color(0xFF1E3A5F),
        tertiaryContainer: Color(0xFF0C4A6E),
        onTertiaryContainer: Color(0xFFE0F2FE),
        error: Color(0xFFF87171),
        onError: Color(0xFF7F1D1D),
        errorContainer: Color(0xFF991B1B),
        onErrorContainer: Color(0xFFFECACA),
        surface: darkSurface,
        onSurface: darkOnSurface,
        surfaceContainerHighest: darkSurfaceVariant,
        onSurfaceVariant: Color(0xFF94A3B8),
        outline: Color(0xFF334155),
        shadow: Colors.black45,
        inverseSurface: darkOnSurface,
        onInverseSurface: darkSurface,
        inversePrimary: primary,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: darkBackground,
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: darkOnSurface,
      ),
    );
  }
}
