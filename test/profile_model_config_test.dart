import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/src/models/agent_profile.dart';
import 'package:hermes_mobile/src/providers/chat_provider.dart';
import 'package:hermes_mobile/src/providers/profiles_provider.dart';
import 'package:hermes_mobile/src/services/hermes_connection.dart';
import 'package:hermes_mobile/src/theme.dart';
import 'package:hermes_mobile/src/ui/screens/agent_profiles_screen.dart';
import 'package:hermes_mobile/src/ui/screens/model_config_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'AgentProfilesScreen renders Soul, Memory, and Model buttons without overflow on narrow mobile',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const profiles = [
      AgentProfile(
        id: 'default',
        name: 'Default Agent',
        model: 'openai/gpt-4o',
        isDefault: true,
        skillCount: 12,
      ),
      AgentProfile(
        id: 'maintenance',
        name: 'maintenance',
        model: 'anthropic/claude-3-7-sonnet',
        isDefault: false,
        skillCount: 58,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profilesListProvider.overrideWith((ref) async => profiles),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AgentProfilesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Default Agent'), findsOneWidget);
    expect(find.text('maintenance'), findsOneWidget);
    expect(find.text('Soul'), findsNWidgets(2));
    expect(find.text('Memory'), findsNWidgets(2));
    expect(find.text('Model'), findsNWidgets(2));
    // Only non-default profile gets a delete icon button
    expect(find.byTooltip('Delete profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ModelConfigScreen scopes to initialProfile, renders sync toggle, and omits decorative badges',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const profiles = [
      AgentProfile(
        id: 'default',
        name: 'Default Agent',
        model: 'openai/gpt-4o',
        isDefault: true,
        skillCount: 10,
      ),
      AgentProfile(
        id: 'maintenance',
        name: 'maintenance',
        model: 'deepseek/deepseek-chat',
        isDefault: false,
        skillCount: 58,
      ),
    ];

    const maintModels = [
      ModelConfig(
        name: 'deepseek/deepseek-chat',
        provider: 'OpenRouter',
        model: 'deepseek/deepseek-chat',
        baseUrl: 'https://openrouter.ai/api/v1',
        enabled: true,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profilesListProvider.overrideWith((ref) async => profiles),
          profileModelsProvider('maintenance')
              .overrideWith((ref) async => maintModels),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ModelConfigScreen(initialProfile: 'maintenance'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Model (maintenance)'), findsOneWidget);
    expect(find.text('Apply to all agent profiles'), findsOneWidget);
    // Ensure old decorative status badge was removed
    expect(find.text('In Use'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
