import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hermes Design Tokens - extracted from hermes-desktop main.css + base.css
/// Authentic developer-tool aesthetic: flat, dark charcoal, deep navy accent.
class HermesTokens {
  // 1. Neumorphic Canvas & Surface Hierarchy
  // Classic Soft Neumorphic Canvas (#E0E5EC)
  static const bgPrimary = Color(0xFFE0E5EC);
  // Surface is extruded directly from the canvas with the same hue
  static const bgSecondary = Color(0xFFE0E5EC);
  // Pressed / Recessed well / Active hover
  static const bgTertiary = Color(0xFFD6DFEB);
  // Dialogs and elevated containers
  static const bgElevated = Color(0xFFE0E5EC);
  // Hover state
  static const bgHover = Color(0xFFE6EBF2);
  // Active / pressed
  static const bgActive = Color(0xFFC8D3E0);

  // 2. Dual Shadow System (The Core of Neumorphism)
  // Pure white top-left highlight shadow
  static const neuShadowLight = Color(0xFFFFFFFF);
  // Cool slate-blue bottom-right depth shadow
  static const neuShadowDark = Color(0x66A3B1C6);
  // Deeper depth shadow for floating items
  static const neuShadowDarkDeep = Color(0x888B9BB0);

  // 3. Accent System (Vibrant Royal Blue on soft background)
  static const accent = Color(0xFF2563EB);
  static const accentHover = Color(0xFF1D4ED8);
  static const accentSubtle = Color(0x1F2563EB);
  static const accentText = Color(0xFF2563EB);

  // 4. Text Hierarchy (Deep Slate for crisp AAA contrast)
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF64748B);

  // 5. Border System (Ultra subtle highlight and rim)
  static const border = Color(0x1494A3B8);
  static const borderBright = Color(0x66FFFFFF);
  static const borderFocus = Color(0xFF2563EB);

  // 6. Semantic Colors
  static const success = Color(0xFF10B981);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const highlight = Color(0xFFF59E0B);

  // Additional UI surfaces
  static const cardBg = Color(0xFFE0E5EC);
  static const divider = Color(0x1F94A3B8);
  static const navInactive = Color(0xFF64748B);
  static const darkBg = Color(0xFFE0E5EC);

  // Chat bubbles & code blocks
  static const userBubble = Color(0xFF2563EB);
  static const userBubbleText = Color(0xFFFFFFFF);
  static const agentBubble = Color(0xFFE8EEF5);
  static const agentBubbleText = Color(0xFF1E293B);
  static const codeBg = Color(0xFFD7E0EB);

  // Border radius scale (Generously rounded for authentic smooth neumorphic curves)
  static const radiusSm = 12.0; // Chips, small buttons
  static const radiusMd = 18.0; // Cards, dialogs, sections
  static const radiusLg = 24.0; // Chat bubbles, floating nav bar

  // Spacing constants
  static const chatBubblePaddingH = 16.0;
  static const chatBubblePaddingV = 10.0;
  static const inputPaddingH = 16.0;
  static const inputPaddingV = 12.0;
  static const messageGap = 12.0;

  // Typography sizing
  static const fontSizeBody = 14.0;
  static const fontSizeCode = 12.0;
  static const fontSizeTime = 11.0;
  static const lineHeightChat = 1.65;
}

/// Helper for authentic Neumorphic dual shadows and debossed wells
class NeumorphicDecoration {
  /// Extruded / Raised surface (cards, buttons, containers)
  static BoxDecoration raised({
    double radius = HermesTokens.radiusMd,
    Color color = HermesTokens.bgSecondary,
    double distance = 5.0,
    double blur = 10.0,
    Border? border,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: border ?? Border.all(color: HermesTokens.borderBright, width: 0.8),
      boxShadow: [
        BoxShadow(
          color: HermesTokens.neuShadowLight,
          offset: Offset(-distance, -distance),
          blurRadius: blur,
        ),
        BoxShadow(
          color: HermesTokens.neuShadowDark,
          offset: Offset(distance, distance),
          blurRadius: blur,
        ),
      ],
    );
  }

  /// Recessed / Inset / Debossed surface (text inputs, search bars, toggle tracks)
  static BoxDecoration recessed({
    double radius = HermesTokens.radiusSm,
    Color color = HermesTokens.bgTertiary,
    Border? border,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: border ?? Border.all(color: const Color(0x1F94A3B8), width: 0.8),
      boxShadow: const [
        BoxShadow(
          color: Color(0x28000000),
          offset: Offset(1.5, 1.5),
          blurRadius: 3,
        ),
        BoxShadow(
          color: Colors.white,
          offset: Offset(-1, -1),
          blurRadius: 3,
        ),
      ],
    );
  }

  /// Circular raised icon button or avatar
  static BoxDecoration circle({
    Color color = HermesTokens.bgSecondary,
    double distance = 4.0,
    double blur = 8.0,
    Border? border,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: color,
      border: border ?? Border.all(color: HermesTokens.borderBright, width: 0.8),
      boxShadow: [
        BoxShadow(
          color: HermesTokens.neuShadowLight,
          offset: Offset(-distance, -distance),
          blurRadius: blur,
        ),
        BoxShadow(
          color: HermesTokens.neuShadowDark,
          offset: Offset(distance, distance),
          blurRadius: blur,
        ),
      ],
    );
  }
}

class AppTheme {
  static final _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: HermesTokens.accent,
    onPrimary: Colors.white,
    secondary: HermesTokens.textSecondary,
    onSecondary: HermesTokens.bgTertiary,
    surface: HermesTokens.bgPrimary,
    onSurface: HermesTokens.textPrimary,
    error: HermesTokens.error,
    onError: Colors.white,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: HermesTokens.bgPrimary,
      canvasColor: HermesTokens.bgPrimary,
      dialogTheme: const DialogThemeData(
        backgroundColor: HermesTokens.bgElevated,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: HermesTokens.bgElevated,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
          side: const BorderSide(color: HermesTokens.borderBright, width: 0.8),
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: HermesTokens.textPrimary,
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
      dividerColor: HermesTokens.divider,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: HermesTokens.bgPrimary,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: HermesTokens.textPrimary,
        ),
        iconTheme: const IconThemeData(color: HermesTokens.textPrimary),
      ),
      textTheme: _buildTextTheme(),
      cardTheme: CardThemeData(
        elevation: 0,
        color: HermesTokens.bgSecondary,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
          side: const BorderSide(color: HermesTokens.borderBright),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HermesTokens.bgTertiary,
        hintStyle: GoogleFonts.inter(
          color: HermesTokens.textMuted,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: HermesTokens.inputPaddingH,
          vertical: HermesTokens.inputPaddingV,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
          borderSide: const BorderSide(color: Color(0x1F94A3B8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
          borderSide: const BorderSide(color: Color(0x1F94A3B8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
          borderSide: const BorderSide(color: HermesTokens.accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: HermesTokens.accent,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;

  static TextTheme _buildTextTheme() {
    return TextTheme(
      headlineLarge: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: HermesTokens.textPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: HermesTokens.textPrimary,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: HermesTokens.textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: HermesTokens.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: HermesTokens.textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: HermesTokens.textSecondary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: HermesTokens.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: HermesTokens.lineHeightChat,
        color: HermesTokens.textPrimary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: HermesTokens.textSecondary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: HermesTokens.textPrimary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: HermesTokens.textSecondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: HermesTokens.textMuted,
      ),
    );
  }
}
