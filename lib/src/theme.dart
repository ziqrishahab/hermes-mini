import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _lavender = Color(0xFFC7B8EA);
  static const _surfaceLowest = Color(0xFF0E0E0E);
  static const _surfaceCard = Color(0xFF242424);
  static const _inputBorder = Color(0xFF333333);
  static const _navInactive = Color(0xFF666666);

  static final _colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: const Color(0xFFE2D5FF),
    onPrimary: const Color(0xFF352A52),
    primaryContainer: _lavender,
    onPrimaryContainer: const Color(0xFF534772),
    secondary: const Color(0xFFC8C6C5),
    onSecondary: const Color(0xFF313030),
    secondaryContainer: const Color(0xFF474746),
    onSecondaryContainer: const Color(0xFFB7B5B4),
    tertiary: const Color(0xFFEADD95),
    onTertiary: const Color(0xFF373100),
    tertiaryContainer: const Color(0xFFCDC17C),
    onTertiaryContainer: const Color(0xFF574F15),
    error: const Color(0xFFFFB4AB),
    onError: const Color(0xFF690005),
    errorContainer: const Color(0xFF93000A),
    onErrorContainer: const Color(0xFFFFDAD6),
    surface: const Color(0xFF131313),
    onSurface: const Color(0xFFE5E2E1),
    surfaceDim: const Color(0xFF131313),
    surfaceBright: const Color(0xFF393939),
    surfaceContainerLowest: _surfaceLowest,
    surfaceContainerLow: const Color(0xFF1C1B1B),
    surfaceContainer: const Color(0xFF201F1F),
    surfaceContainerHigh: const Color(0xFF2A2A2A),
    surfaceContainerHighest: const Color(0xFF353534),
    outline: const Color(0xFF948F99),
    outlineVariant: const Color(0xFF49454E),
    inverseSurface: const Color(0xFFE5E2E1),
    onInverseSurface: const Color(0xFF313030),
    inversePrimary: const Color(0xFF645883),
    surfaceTint: const Color(0xFFCEBFF1),
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: _surfaceLowest,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Color(0xFF131313),
      ),
      textTheme: _buildTextTheme(),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lavender),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _colorScheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _lavender,
          foregroundColor: const Color(0xFF121212),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: const Color(0xFF131313),
        surfaceTintColor: Colors.transparent,
        indicatorColor: _lavender.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _lavender, size: 24);
          }
          return const IconThemeData(color: _navInactive, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 0, height: 0);
          }
          return const TextStyle(fontSize: 0, height: 0);
        }),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF645883),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F7FC),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      textTheme: _buildTextTheme(),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF645883)),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      headlineLarge: GoogleFonts.hankenGrotesk(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 40 / 32,
        letterSpacing: -0.64,
      ),
      headlineMedium: GoogleFonts.hankenGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
      ),
      headlineSmall: GoogleFonts.hankenGrotesk(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 28 / 22,
      ),
      titleLarge: GoogleFonts.hankenGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 26 / 20,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 24 / 16,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.5,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.6,
      ),
    );
  }
}
