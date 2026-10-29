import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/src/services/storage_service.dart';
import 'package:hermes_mobile/src/ui/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService Onboarding', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('isOnboardingCompleted defaults to false', () async {
      final storage = StorageService();
      final completed = await storage.isOnboardingCompleted();
      expect(completed, isFalse);
    });

    test('setOnboardingCompleted persists true', () async {
      final storage = StorageService();
      await storage.setOnboardingCompleted(true);
      final completed = await storage.isOnboardingCompleted();
      expect(completed, isTrue);
    });
  });

  group('OnboardingScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders initial welcome slide with persistent hero and continue button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Continue'), findsOneWidget);
      expect(find.textContaining('Autonomous AI Daemon'), findsOneWidget);
    });

    testWidgets('tapping Continue advances through the 3 slides while keeping hero', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Slide 1 -> Slide 2
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Remote Vibe Coding'), findsOneWidget);

      // Slide 2 -> Slide 3
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Android Device'), findsOneWidget);
      expect(find.text('Enable Accessibility Service'), findsOneWidget);
      expect(find.text('Configure later in Settings'), findsOneWidget);
    });

    testWidgets('positions slide header and body text comfortably below the hero without jumping to the bottom', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 880));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final heroBottom = tester.getBottomLeft(find.byType(Image)).dy;
      final headlineTop =
          tester.getTopLeft(find.textContaining('Autonomous AI Daemon')).dy;
      final continueTop = tester.getTopLeft(find.text('Continue')).dy;

      // Headline sits naturally below the hero (~48-60px gap) instead of stuck at the bottom
      expect(headlineTop - heroBottom, greaterThan(35));
      expect(headlineTop - heroBottom, lessThan(80));
      expect(headlineTop, lessThan(continueTop));
      expect(tester.takeException(), isNull);
    });
  });
}
