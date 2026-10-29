import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../theme.dart";

const String _themePrefKey = "app_theme_mode";

final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

class PlatformBrightnessNotifier extends StateNotifier<Brightness>
    with WidgetsBindingObserver {
  PlatformBrightnessNotifier()
      : super(
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
        ) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangePlatformBrightness() {
    state = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final platformBrightnessProvider =
    StateNotifierProvider<PlatformBrightnessNotifier, Brightness>((ref) {
  return PlatformBrightnessNotifier();
});

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
      final initial = ref.watch(initialThemeModeProvider);
      return ThemeModeNotifier(initial);
    });

final isDarkProvider = Provider<bool>((ref) {
  final themeMode = ref.watch(themeModeProvider);
  final platformBrightness = ref.watch(platformBrightnessProvider);
  final isDark = themeMode == ThemeMode.dark ||
      (themeMode == ThemeMode.system && platformBrightness == Brightness.dark);
  HermesTokens.isDark = isDark;
  return isDark;
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  SharedPreferences? _prefs;

  ThemeModeNotifier([super.initial = ThemeMode.system]) {
    _load();
  }

  Future<void> _load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final saved = _prefs?.getString(_themePrefKey);
      if (saved == "light") {
        state = ThemeMode.light;
      } else if (saved == "dark") {
        state = ThemeMode.dark;
      } else {
        state = ThemeMode.system;
      }
    } catch (_) {
      // Keep system default
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    // Persist asynchronously in background so disk I/O does not drop animation frames
    Future.microtask(() async {
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        _prefs = prefs;
        if (mode == ThemeMode.light) {
          await prefs.setString(_themePrefKey, "light");
        } else if (mode == ThemeMode.dark) {
          await prefs.setString(_themePrefKey, "dark");
        } else {
          await prefs.remove(_themePrefKey);
        }
      } catch (_) {
        // SharedPreferences failure non-fatal
      }
    });
  }
}
