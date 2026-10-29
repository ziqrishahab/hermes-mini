import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/src/providers/connection_provider.dart';
import 'package:hermes_mobile/src/ui/screens/connection_screen.dart';
import 'package:hermes_mobile/src/ui/screens/chat_screen.dart';
import 'package:hermes_mobile/src/ui/screens/settings_screen.dart';
import 'package:hermes_mobile/src/ui/widgets/fluid_pulse_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ConnectionScreen UX Refinements', () {
    testWidgets('renders Explore in Offline Mode button and simple placeholders', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ConnectionScreen(),
          ),
        ),
      );
      await tester.pump();

      // Check simple, non-hardcoded placeholders
      expect(find.text('Explore in Offline Mode'), findsOneWidget);
      expect(find.text('http://host:port'), findsOneWidget);
      expect(find.text('Password or API key'), findsOneWidget);

      // Verify no hardcoded dummy IPs remain
      expect(find.textContaining('192.168.1.100'), findsNothing);
    });

    testWidgets('tapping Explore in Offline Mode updates isOfflineModeProvider', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ConnectionScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(container.read(isOfflineModeProvider), isFalse);

      await tester.ensureVisible(find.text('Explore in Offline Mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explore in Offline Mode'));
      await tester.pump();

      expect(container.read(isOfflineModeProvider), isTrue);
    });
  });

  group('SettingsScreen Pure Neumorphic & Device Automation', () {
    testWidgets('renders Device Automation row and omits pulse indicator dots', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check Device Automation row
      expect(find.text('Device Automation'), findsOneWidget);

      // Verify FluidPulseIndicator is removed from SettingsScreen
      expect(find.byType(FluidPulseIndicator), findsNothing);
    });
  });

  group('ChatScreen Offline Mode & Navigation', () {
    testWidgets('shows Offline Mode banner with Connect button when offline', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isOfflineModeProvider.overrideWith((ref) => true),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("Offline Mode: Showing saved history"), findsOneWidget);
      expect(find.text("Connect"), findsOneWidget);
    });
  });
}
