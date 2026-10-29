import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/src/providers/theme_provider.dart';
import 'package:hermes_mobile/src/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('test decoration colors', () {
    HermesTokens.isDark = false;
    final lightRaised = NeumorphicDecoration.raised();
    final lightRecessed = NeumorphicDecoration.recessed();
    expect(lightRaised.color, const Color(0xFFE0E5EC));
    expect(lightRecessed.color, const Color(0xFFD6DFEB));
    expect(HermesTokens.brandLogo, HermesTokens.brandLogoLight);

    HermesTokens.isDark = true;
    final darkRaised = NeumorphicDecoration.raised();
    final darkRecessed = NeumorphicDecoration.recessed();
    expect(darkRaised.color, const Color(0xFF1A1F26));
    expect(darkRecessed.color, const Color(0xFF12161C));
    expect(HermesTokens.brandLogo, HermesTokens.brandLogoDark);

    // Test explicit override
    final explicitLight = NeumorphicDecoration.raised(isDark: false);
    expect(explicitLight.color, const Color(0xFFE0E5EC));

    final explicitDark = NeumorphicDecoration.raised(isDark: true);
    expect(explicitDark.color, const Color(0xFF1A1F26));
  });

  test('isDarkProvider syncs with platformBrightness and themeMode', () {
    final container = ProviderContainer(
      overrides: [
        initialThemeModeProvider.overrideWithValue(ThemeMode.system),
      ],
    );
    addTearDown(container.dispose);

    // 1. System mode with Light platform
    container.read(platformBrightnessProvider.notifier).state = Brightness.light;
    container.read(themeModeProvider.notifier).state = ThemeMode.system;
    expect(container.read(isDarkProvider), false);
    expect(HermesTokens.isDark, false);

    // 2. System mode with Dark platform
    container.read(platformBrightnessProvider.notifier).state = Brightness.dark;
    expect(container.read(isDarkProvider), true);
    expect(HermesTokens.isDark, true);

    // 3. User override to Light mode (even when platform is Dark)
    container.read(themeModeProvider.notifier).state = ThemeMode.light;
    expect(container.read(isDarkProvider), false);
    expect(HermesTokens.isDark, false);

    // 4. User override to Dark mode (even when platform is Light)
    container.read(platformBrightnessProvider.notifier).state = Brightness.light;
    container.read(themeModeProvider.notifier).state = ThemeMode.dark;
    expect(container.read(isDarkProvider), true);
    expect(HermesTokens.isDark, true);
  });
}
