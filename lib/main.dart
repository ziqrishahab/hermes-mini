import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/app.dart';
import 'src/providers/theme_provider.dart';
import 'src/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ThemeMode initialTheme = ThemeMode.system;
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_theme_mode');
    if (saved == 'dark') {
      initialTheme = ThemeMode.dark;
    } else if (saved == 'light') {
      initialTheme = ThemeMode.light;
    }
  } catch (_) {
    // Keep system default
  }

  final platformBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;
  final isDark = initialTheme == ThemeMode.dark ||
      (initialTheme == ThemeMode.system && platformBrightness == Brightness.dark);
  HermesTokens.isDark = isDark;

  runApp(
    ProviderScope(
      overrides: [
        initialThemeModeProvider.overrideWithValue(initialTheme),
      ],
      child: const HermesMobileApp(),
    ),
  );
}
