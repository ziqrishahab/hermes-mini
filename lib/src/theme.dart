import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Hermes Design Tokens — extracted from hermes-desktop main.css
class HermesTokens {
  // Dark theme colors
  static const bgPrimary = Color(0xFF212121);
  static const bgSecondary = Color(0xFF171717);
  static const bgTertiary = Color(0xFF2F2F2F);
  static const bgElevated = Color(0xFF303030);
  static const bgHover = Color(0xFF3A3A3A);
  static const bgActive = Color(0xFF424242);
  static const accent = Color(0xFF003F7A);
  static const accentHover = Color(0xFF0055A4);
  static const accentText = Color(0xFF006ACD);
  static const textPrimary = Color(0xFFECECEC);
  static const textSecondary = Color(0xFFB4B4B4);
  static const textMuted = Color(0xFF8E8E8E);
  static const border = Color(0x0FFFFFFF);
  static const borderBright = Color(0x1AFFFFFF);
  static const borderFocus = Color(0xFF003F7A);
  static const success = Color(0xFF22C55E);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const highlight = Color(0xFFF5C518);

  // Chat bubbles
  static const userBubble = Color(0xFF003F7A);
  static const userBubbleText = Color(0xFFFFFFFF);
  static const agentBubble = Color(0xFF2F2F2F);
  static const agentBubbleText = Color(0xFFECECEC);
  static const codeBg = Color(0xFF1A1A1A);

  // Border radius
  static const radiusSm = 6.0;
  static const radiusMd = 10.0;
  static const radiusLg = 14.0;

  // Spacing
  static const chatBubblePaddingH = 16.0;
  static const chatBubblePaddingV = 10.0;
  static const inputPaddingH = 14.0;
  static const inputPaddingV = 10.0;
  static const messageGap = 12.0;

  // Typography
  static const fontSizeBody = 14.0;
  static const fontSizeCode = 12.0;
  static const fontSizeTime = 11.0;
  static const lineHeightChat = 1.65;
}

class AppTheme {
  static const _navInactive = Color(0xFF666666);

  static final _colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: HermesTokens.accent,
    onPrimary: Colors.white,
    secondary: HermesTokens.textSecondary,
    onSecondary: HermesTokens.bgTertiary,
    surface: HermesTokens.bgPrimary,
    onSurface: HermesTokens.textPrimary,
    error: HermesTokens.error,
    onError: Colors.white,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: HermesTokens.bgPrimary,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Color(0xFF212121),
      ),
      textTheme: _buildTextTheme(),
      cardTheme: CardThemeData(
        elevation: 0,
        color: HermesTokens.bgSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HermesTokens.bgPrimary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
          borderSide: const BorderSide(color: HermesTokens.accent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
          borderSide: const BorderSide(color: HermesTokens.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
          borderSide: const BorderSide(color: HermesTokens.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: HermesTokens.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: HermesTokens.bgSecondary,
        surfaceTintColor: Colors.transparent,
        indicatorColor: HermesTokens.accent.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: HermesTokens.accent, size: 24);
          }
          return const IconThemeData(color: _navInactive, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
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
        seedColor: HermesTokens.accent,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFFFFFFF),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      textTheme: _buildTextTheme(),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFFF8F8F8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
          borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
          borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
          borderSide: const BorderSide(color: HermesTokens.accent),
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
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 16 / 11,
        letterSpacing: 0.6,
      ),
    );
  }
}
