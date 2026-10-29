import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hermes Design Tokens - extracted from hermes-desktop main.css + base.css
/// Authentic developer-tool aesthetic: flat, dark charcoal, deep navy accent.
/// ThemeExtension that performs smooth 60fps color interpolation (lerp)
/// during theme transitions (Light <-> Dark)
@immutable
class HermesColors extends ThemeExtension<HermesColors> {
  final Color bgPrimary;
  final Color bgSecondary;
  final Color bgTertiary;
  final Color bgElevated;
  final Color bgHover;
  final Color bgActive;

  final Color neuShadowLight;
  final Color neuShadowDark;
  final Color neuShadowDarkDeep;

  final Color accent;
  final Color accentHover;
  final Color accentSubtle;
  final Color accentText;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color border;
  final Color borderBright;
  final Color borderFocus;

  final Color cardBg;
  final Color divider;
  final Color navInactive;
  final Color darkBg;

  final Color userBubble;
  final Color userBubbleText;
  final Color agentBubble;
  final Color agentBubbleText;
  final Color codeBg;
  final bool isDark;

  const HermesColors({
    required this.bgPrimary,
    required this.bgSecondary,
    required this.bgTertiary,
    required this.bgElevated,
    required this.bgHover,
    required this.bgActive,
    required this.neuShadowLight,
    required this.neuShadowDark,
    required this.neuShadowDarkDeep,
    required this.accent,
    required this.accentHover,
    required this.accentSubtle,
    required this.accentText,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderBright,
    required this.borderFocus,
    required this.cardBg,
    required this.divider,
    required this.navInactive,
    required this.darkBg,
    required this.userBubble,
    required this.userBubbleText,
    required this.agentBubble,
    required this.agentBubbleText,
    required this.codeBg,
    required this.isDark,
  });

  static const light = HermesColors(
    bgPrimary: Color(0xFFE0E5EC),
    bgSecondary: Color(0xFFE0E5EC),
    bgTertiary: Color(0xFFD6DFEB),
    bgElevated: Color(0xFFE0E5EC),
    bgHover: Color(0xFFE6EBF2),
    bgActive: Color(0xFFC8D3E0),
    neuShadowLight: Color(0xFFFFFFFF),
    neuShadowDark: Color(0x66A3B1C6),
    neuShadowDarkDeep: Color(0x888B9BB0),
    accent: Color(0xFF2563EB),
    accentHover: Color(0xFF1D4ED8),
    accentSubtle: Color(0x1F2563EB),
    accentText: Color(0xFF2563EB),
    textPrimary: Color(0xFF1E293B),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF64748B),
    border: Color(0x1494A3B8),
    borderBright: Color(0x66FFFFFF),
    borderFocus: Color(0xFF2563EB),
    cardBg: Color(0xFFE0E5EC),
    divider: Color(0x1F94A3B8),
    navInactive: Color(0xFF64748B),
    darkBg: Color(0xFFE0E5EC),
    userBubble: Color(0xFF2563EB),
    userBubbleText: Color(0xFFFFFFFF),
    agentBubble: Color(0xFFE8EEF5),
    agentBubbleText: Color(0xFF1E293B),
    codeBg: Color(0xFFD7E0EB),
    isDark: false,
  );

  static const dark = HermesColors(
    bgPrimary: Color(0xFF161B22),
    bgSecondary: Color(0xFF1A1F26),
    bgTertiary: Color(0xFF12161C),
    bgElevated: Color(0xFF1F242C),
    bgHover: Color(0xFF262C36),
    bgActive: Color(0xFF101317),
    neuShadowLight: Color(0x14FFFFFF),
    neuShadowDark: Color(0x99000000),
    neuShadowDarkDeep: Color(0xCC000000),
    accent: Color(0xFF3B82F6),
    accentHover: Color(0xFF2563EB),
    accentSubtle: Color(0x263B82F6),
    accentText: Color(0xFF60A5FA),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    border: Color(0x26FFFFFF),
    borderBright: Color(0x1AFFFFFF),
    borderFocus: Color(0xFF3B82F6),
    cardBg: Color(0xFF1A1F26),
    divider: Color(0x26FFFFFF),
    navInactive: Color(0xFF64748B),
    darkBg: Color(0xFF161B22),
    userBubble: Color(0xFF2563EB),
    userBubbleText: Color(0xFFFFFFFF),
    agentBubble: Color(0xFF1E242D),
    agentBubbleText: Color(0xFFF1F5F9),
    codeBg: Color(0xFF101419),
    isDark: true,
  );

  @override
  HermesColors copyWith({
    Color? bgPrimary,
    Color? bgSecondary,
    Color? bgTertiary,
    Color? bgElevated,
    Color? bgHover,
    Color? bgActive,
    Color? neuShadowLight,
    Color? neuShadowDark,
    Color? neuShadowDarkDeep,
    Color? accent,
    Color? accentHover,
    Color? accentSubtle,
    Color? accentText,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? borderBright,
    Color? borderFocus,
    Color? cardBg,
    Color? divider,
    Color? navInactive,
    Color? darkBg,
    Color? userBubble,
    Color? userBubbleText,
    Color? agentBubble,
    Color? agentBubbleText,
    Color? codeBg,
    bool? isDark,
  }) {
    return HermesColors(
      bgPrimary: bgPrimary ?? this.bgPrimary,
      bgSecondary: bgSecondary ?? this.bgSecondary,
      bgTertiary: bgTertiary ?? this.bgTertiary,
      bgElevated: bgElevated ?? this.bgElevated,
      bgHover: bgHover ?? this.bgHover,
      bgActive: bgActive ?? this.bgActive,
      neuShadowLight: neuShadowLight ?? this.neuShadowLight,
      neuShadowDark: neuShadowDark ?? this.neuShadowDark,
      neuShadowDarkDeep: neuShadowDarkDeep ?? this.neuShadowDarkDeep,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      accentText: accentText ?? this.accentText,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      borderBright: borderBright ?? this.borderBright,
      borderFocus: borderFocus ?? this.borderFocus,
      cardBg: cardBg ?? this.cardBg,
      divider: divider ?? this.divider,
      navInactive: navInactive ?? this.navInactive,
      darkBg: darkBg ?? this.darkBg,
      userBubble: userBubble ?? this.userBubble,
      userBubbleText: userBubbleText ?? this.userBubbleText,
      agentBubble: agentBubble ?? this.agentBubble,
      agentBubbleText: agentBubbleText ?? this.agentBubbleText,
      codeBg: codeBg ?? this.codeBg,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  HermesColors lerp(ThemeExtension<HermesColors>? other, double t) {
    if (other is! HermesColors) return this;
    final interpolated = HermesColors(
      bgPrimary: Color.lerp(bgPrimary, other.bgPrimary, t) ?? bgPrimary,
      bgSecondary: Color.lerp(bgSecondary, other.bgSecondary, t) ?? bgSecondary,
      bgTertiary: Color.lerp(bgTertiary, other.bgTertiary, t) ?? bgTertiary,
      bgElevated: Color.lerp(bgElevated, other.bgElevated, t) ?? bgElevated,
      bgHover: Color.lerp(bgHover, other.bgHover, t) ?? bgHover,
      bgActive: Color.lerp(bgActive, other.bgActive, t) ?? bgActive,
      neuShadowLight: Color.lerp(neuShadowLight, other.neuShadowLight, t) ?? neuShadowLight,
      neuShadowDark: Color.lerp(neuShadowDark, other.neuShadowDark, t) ?? neuShadowDark,
      neuShadowDarkDeep: Color.lerp(neuShadowDarkDeep, other.neuShadowDarkDeep, t) ?? neuShadowDarkDeep,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      accentHover: Color.lerp(accentHover, other.accentHover, t) ?? accentHover,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t) ?? accentSubtle,
      accentText: Color.lerp(accentText, other.accentText, t) ?? accentText,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      border: Color.lerp(border, other.border, t) ?? border,
      borderBright: Color.lerp(borderBright, other.borderBright, t) ?? borderBright,
      borderFocus: Color.lerp(borderFocus, other.borderFocus, t) ?? borderFocus,
      cardBg: Color.lerp(cardBg, other.cardBg, t) ?? cardBg,
      divider: Color.lerp(divider, other.divider, t) ?? divider,
      navInactive: Color.lerp(navInactive, other.navInactive, t) ?? navInactive,
      darkBg: Color.lerp(darkBg, other.darkBg, t) ?? darkBg,
      userBubble: Color.lerp(userBubble, other.userBubble, t) ?? userBubble,
      userBubbleText: Color.lerp(userBubbleText, other.userBubbleText, t) ?? userBubbleText,
      agentBubble: Color.lerp(agentBubble, other.agentBubble, t) ?? agentBubble,
      agentBubbleText: Color.lerp(agentBubbleText, other.agentBubbleText, t) ?? agentBubbleText,
      codeBg: Color.lerp(codeBg, other.codeBg, t) ?? codeBg,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
    return interpolated;
  }
}


class HermesTokens {
  static bool isDark = false;
  static HermesColors get current => isDark ? HermesColors.dark : HermesColors.light;

  // 1. Neumorphic Canvas & Surface Hierarchy
  static Color get bgPrimary => current.bgPrimary;
  static Color get bgSecondary => current.bgSecondary;
  static Color get bgTertiary => current.bgTertiary;
  static Color get bgElevated => current.bgElevated;
  static Color get bgHover => current.bgHover;
  static Color get bgActive => current.bgActive;

  // 2. Dual Shadow System
  static Color get neuShadowLight => current.neuShadowLight;
  static Color get neuShadowDark => current.neuShadowDark;
  static Color get neuShadowDarkDeep => current.neuShadowDarkDeep;

  // 3. Accent System
  static Color get accent => current.accent;
  static Color get accentHover => current.accentHover;
  static Color get accentSubtle => current.accentSubtle;
  static Color get accentText => current.accentText;

  // 4. Text Hierarchy
  static Color get textPrimary => current.textPrimary;
  static Color get textSecondary => current.textSecondary;
  static Color get textMuted => current.textMuted;

  // 5. Border System
  static Color get border => current.border;
  static Color get borderBright => current.borderBright;
  static Color get borderFocus => current.borderFocus;

  // 6. Semantic Colors
  static const success = Color(0xFF10B981);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const highlight = Color(0xFFF59E0B);

  // 7. Brand Assets & Recommendation Colors
  static const Color coolSilver = Color(0xFFE8ECF2);
  static const Color charcoalSlate = Color(0xFF1F2229);

  static const String brandIconSet = 'assets/icons/icon_set.png';
  static String get brandLogo => brandIconSet;
  static const String brandLogoGeneral = brandIconSet;
  static const String brandLogoDark = brandIconSet;
  static const String brandLogoLight = brandIconSet;

  // Additional UI surfaces
  static Color get cardBg => current.cardBg;
  static Color get divider => current.divider;
  static Color get navInactive => current.navInactive;
  static Color get darkBg => current.darkBg;

  // Chat bubbles & code blocks
  static Color get userBubble => current.userBubble;
  static Color get userBubbleText => current.userBubbleText;
  static Color get agentBubble => current.agentBubble;
  static Color get agentBubbleText => current.agentBubbleText;
  static Color get codeBg => current.codeBg;

  // Border radius scale
  static const radiusSm = 12.0;
  static const radiusMd = 18.0;
  static const radiusLg = 24.0;

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

/// Hermes Dark Mode Tokens
/// Dark Neumorphic Developer Canvas (#161B22 / #1A1F26)
class HermesDarkTokens {
  // 1. Dark Neumorphic Canvas & Surface Hierarchy
  static const bgPrimary = Color(0xFF161B22);
  static const bgSecondary = Color(0xFF1A1F26);
  static const bgTertiary = Color(0xFF12161C);
  static const bgElevated = Color(0xFF1F242C);
  static const bgHover = Color(0xFF262C36);
  static const bgActive = Color(0xFF101317);

  // 2. Dual Shadow System for Dark Mode
  static const neuShadowLight = Color(0x14FFFFFF); // 8% specular rim highlight
  static const neuShadowDark = Color(0x99000000);  // 60% ambient occlusion shadow
  static const neuShadowDarkDeep = Color(0xCC000000);

  // 3. Accent System
  static const accent = Color(0xFF3B82F6);
  static const accentHover = Color(0xFF2563EB);
  static const accentSubtle = Color(0x263B82F6);
  static const accentText = Color(0xFF60A5FA);

  // 4. Text Hierarchy
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);

  // 5. Border System
  static const border = Color(0x26FFFFFF);
  static const borderBright = Color(0x1AFFFFFF);
  static const borderFocus = Color(0xFF3B82F6);

  // 6. Semantic Colors
  static const success = Color(0xFF10B981);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const highlight = Color(0xFFF59E0B);

  // 7. Brand Assets
  static const brandLogo = 'assets/icons/icon_set.png';
  static const brandLogoGeneral = 'assets/icons/icon_set.png';

  // Additional UI surfaces
  static const cardBg = Color(0xFF1A1F26);
  static const divider = Color(0x26FFFFFF);
  static const navInactive = Color(0xFF64748B);
  static const darkBg = Color(0xFF161B22);

  // Chat bubbles & code blocks
  static const userBubble = Color(0xFF2563EB);
  static const userBubbleText = Color(0xFFFFFFFF);
  static const agentBubble = Color(0xFF1E242D);
  static const agentBubbleText = Color(0xFFF1F5F9);
  static const codeBg = Color(0xFF101419);
}

/// Helper for authentic Neumorphic dual shadows and debossed wells
class NeumorphicDecoration {
  /// Extruded / Raised surface (cards, buttons, containers)
  static BoxDecoration raised({
    double radius = HermesTokens.radiusMd,
    Color? color,
    double distance = 5.0,
    double blur = 10.0,
    Border? border,
    bool? isDark,
  }) {
    final dark = isDark ?? HermesTokens.isDark;
    final bg = color ?? (dark ? HermesColors.dark.bgSecondary : HermesColors.light.bgSecondary);
    final shadowLight = dark ? HermesColors.dark.neuShadowLight : HermesColors.light.neuShadowLight;
    final shadowDark = dark ? HermesColors.dark.neuShadowDark : HermesColors.light.neuShadowDark;
    final borderDef = border ?? Border.all(
      color: dark ? HermesColors.dark.borderBright : HermesColors.light.borderBright,
      width: 0.8,
    );

    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      border: borderDef,
      boxShadow: [
        BoxShadow(
          color: shadowLight,
          offset: Offset(-distance, -distance),
          blurRadius: blur,
        ),
        BoxShadow(
          color: shadowDark,
          offset: Offset(distance, distance),
          blurRadius: blur,
        ),
      ],
    );
  }

  /// Recessed / Inset / Debossed surface (text inputs, search bars, toggle tracks)
  static BoxDecoration recessed({
    double radius = HermesTokens.radiusSm,
    Color? color,
    Border? border,
    bool? isDark,
  }) {
    final dark = isDark ?? HermesTokens.isDark;
    final bg = color ?? (dark ? HermesColors.dark.bgTertiary : HermesColors.light.bgTertiary);
    final borderDef = border ?? Border.all(
      color: dark ? const Color(0x26FFFFFF) : const Color(0x1F94A3B8),
      width: 1.0,
    );

    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      border: borderDef,
      boxShadow: dark
          ? [
              const BoxShadow(
                color: Color(0x80000000),
                offset: Offset(1.5, 1.5),
                blurRadius: 3,
              ),
              const BoxShadow(
                color: Color(0x0FFFFFFF),
                offset: Offset(-1, -1),
                blurRadius: 2,
              ),
            ]
          : [
              const BoxShadow(
                color: Color(0x2E94A3B8),
                offset: Offset(1.5, 1.5),
                blurRadius: 3,
              ),
              const BoxShadow(
                color: Colors.white,
                offset: Offset(-1, -1),
                blurRadius: 2,
              ),
            ],
    );
  }

  /// Circular raised icon button or avatar
  static BoxDecoration circle({
    Color? color,
    double distance = 4.0,
    double blur = 8.0,
    Border? border,
    bool? isDark,
  }) {
    final dark = isDark ?? HermesTokens.isDark;
    final bg = color ?? (dark ? HermesColors.dark.bgSecondary : HermesColors.light.bgSecondary);
    final shadowLight = dark ? HermesColors.dark.neuShadowLight : HermesColors.light.neuShadowLight;
    final shadowDark = dark ? HermesColors.dark.neuShadowDark : HermesColors.light.neuShadowDark;
    final borderDef = border ?? Border.all(
      color: dark ? HermesColors.dark.borderBright : HermesColors.light.borderBright,
      width: 0.8,
    );

    return BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: bg,
      border: borderDef,
      boxShadow: [
        BoxShadow(
          color: shadowLight,
          offset: Offset(-distance, -distance),
          blurRadius: blur,
        ),
        BoxShadow(
          color: shadowDark,
          offset: Offset(distance, distance),
          blurRadius: blur,
        ),
      ],
    );
  }

  /// Tactile Neumorphic Switcher / Segment Indicator Thumb
  static BoxDecoration switcherThumb({
    double radius = 16.0,
    bool? isDark,
  }) {
    final dark = isDark ?? HermesTokens.isDark;
    return dark
        ? BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF222831),
                Color(0xFF161A21),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: const Color(0x1CFFFFFF),
              width: 0.8,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12FFFFFF),
                offset: Offset(-1.5, -1.5),
                blurRadius: 3,
              ),
              BoxShadow(
                color: Color(0x99000000),
                offset: Offset(2, 3),
                blurRadius: 5,
              ),
            ],
          )
        : BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFEDF2F7),
                Color(0xFFD6DFEB),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: const Color(0x80FFFFFF),
              width: 0.8,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0xB3FFFFFF),
                offset: Offset(-2, -2),
                blurRadius: 4,
              ),
              BoxShadow(
                color: Color(0x2E8B9BB0),
                offset: Offset(2, 3),
                blurRadius: 5,
              ),
            ],
          );
  }

  /// Context-aware raised decoration
  static BoxDecoration of(
    BuildContext context, {
    double radius = HermesTokens.radiusMd,
    Color? color,
    double distance = 5.0,
    double blur = 10.0,
    Border? border,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return raised(
      radius: radius,
      color: color,
      distance: distance,
      blur: blur,
      border: border,
      isDark: isDark,
    );
  }
}

class AppTheme {
  static final _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: HermesColors.light.accent,
    onPrimary: Colors.white,
    secondary: HermesColors.light.textSecondary,
    onSecondary: HermesColors.light.bgTertiary,
    surface: HermesColors.light.bgPrimary,
    onSurface: HermesColors.light.textPrimary,
    error: HermesTokens.error,
    onError: Colors.white,
  );

  static final _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: HermesDarkTokens.accent,
    onPrimary: Colors.white,
    secondary: HermesDarkTokens.textSecondary,
    onSecondary: HermesDarkTokens.bgTertiary,
    surface: HermesDarkTokens.bgPrimary,
    onSurface: HermesDarkTokens.textPrimary,
    error: HermesDarkTokens.error,
    onError: Colors.white,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      extensions: const [HermesColors.light],
      brightness: Brightness.light,
      colorScheme: _lightColorScheme,
      scaffoldBackgroundColor: HermesColors.light.bgPrimary,
      canvasColor: HermesColors.light.bgPrimary,
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: HermesColors.light.bgPrimary,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: HermesColors.light.bgElevated,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: HermesColors.light.bgElevated,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
          side: const BorderSide(color: Color(0x66FFFFFF), width: 0.8),
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: HermesColors.light.textPrimary,
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
      dividerColor: HermesColors.light.divider,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: HermesColors.light.bgPrimary,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: HermesColors.light.textPrimary,
        ),
        iconTheme: IconThemeData(color: HermesColors.light.textPrimary),
      ),
      textTheme: _buildLightTextTheme(),
      cardTheme: CardThemeData(
        elevation: 0,
        color: HermesColors.light.bgSecondary,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
          side: const BorderSide(color: Color(0x66FFFFFF)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        hintStyle: GoogleFonts.inter(
          color: HermesColors.light.textMuted,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: HermesTokens.inputPaddingH,
          vertical: HermesTokens.inputPaddingV,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: HermesColors.light.accent,
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

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      extensions: const [HermesColors.dark],
      brightness: Brightness.dark,
      colorScheme: _darkColorScheme,
      scaffoldBackgroundColor: HermesDarkTokens.bgPrimary,
      canvasColor: HermesDarkTokens.bgPrimary,
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: HermesDarkTokens.bgPrimary,
        elevation: 0,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: HermesDarkTokens.bgElevated,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: HermesDarkTokens.bgElevated,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
          side: const BorderSide(color: HermesDarkTokens.border, width: 0.8),
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: HermesDarkTokens.textPrimary,
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
      dividerColor: HermesDarkTokens.divider,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: HermesDarkTokens.bgPrimary,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: HermesDarkTokens.textPrimary,
        ),
        iconTheme: const IconThemeData(color: HermesDarkTokens.textPrimary),
      ),
      textTheme: _buildDarkTextTheme(),
      cardTheme: CardThemeData(
        elevation: 0,
        color: HermesDarkTokens.bgSecondary,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
          side: const BorderSide(color: HermesDarkTokens.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        hintStyle: GoogleFonts.inter(
          color: HermesDarkTokens.textMuted,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: HermesTokens.inputPaddingH,
          vertical: HermesTokens.inputPaddingV,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: HermesDarkTokens.accent,
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

  static TextTheme _buildDarkTextTheme() {
    return TextTheme(
      headlineLarge: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: HermesDarkTokens.textPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: HermesDarkTokens.textPrimary,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: HermesDarkTokens.textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: HermesDarkTokens.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: HermesDarkTokens.textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: HermesDarkTokens.textSecondary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: HermesDarkTokens.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: HermesTokens.lineHeightChat,
        color: HermesDarkTokens.textPrimary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: HermesDarkTokens.textSecondary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: HermesDarkTokens.textPrimary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: HermesDarkTokens.textSecondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: HermesDarkTokens.textMuted,
      ),
    );
  }

  static TextTheme _buildLightTextTheme() {
    return TextTheme(
      headlineLarge: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: HermesColors.light.textPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: HermesColors.light.textPrimary,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: HermesColors.light.textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: HermesColors.light.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: HermesColors.light.textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: HermesColors.light.textSecondary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: HermesColors.light.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: HermesTokens.lineHeightChat,
        color: HermesColors.light.textPrimary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: HermesColors.light.textSecondary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: HermesColors.light.textPrimary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: HermesColors.light.textSecondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: HermesColors.light.textMuted,
      ),
    );
  }
}
