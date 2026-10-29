import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/connection_screen.dart';
import 'ui/screens/chat_screen.dart';
import 'ui/screens/main_screen.dart';
import 'ui/screens/soul_editor_screen.dart';
import 'ui/screens/user_editor_screen.dart';
import 'ui/screens/memory_editor_screen.dart';
import 'ui/screens/capabilities_screen.dart';
import 'ui/screens/model_config_screen.dart';
import 'ui/screens/schedule_detail_screen.dart';
import 'ui/screens/create_edit_schedule_screen.dart';
import 'ui/screens/chat_room_screen.dart';
import 'ui/screens/kanban_screen.dart';
import 'ui/screens/achievements_screen.dart';
import 'ui/screens/gateway_config_screen.dart';
import 'ui/screens/hermes_instance_screen.dart';
import 'ui/screens/agent_profiles_screen.dart';
import 'ui/screens/registry_discover_screen.dart';
import 'providers/connection_provider.dart';
import 'config/dev_config.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      if (devBypassConnection) return null;

      final container = ProviderScope.containerOf(context);
      final conn = container.read(connectionProvider);
      final isConnected = conn.valueOrNull != null;
      final isOffline = container.read(isOfflineModeProvider);

      final loc = state.matchedLocation;
      if (loc == '/splash' || loc == '/welcome' || loc == '/onboarding') {
        return null;
      }

      if (isConnected && loc == '/connect') return '/home';
      if (!isConnected && !isOffline && loc != '/connect') {
        container.read(isOfflineModeProvider.notifier).state = true;
        return null;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (c, s) => const WelcomeScreen()),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: '/connect', builder: (c, s) => const ConnectionScreen()),
      GoRoute(path: '/chat', builder: (c, s) => const ChatScreen()),
      GoRoute(path: '/home', builder: (c, s) => const MainScreen()),
      GoRoute(path: '/soul-editor', builder: (c, s) => SoulEditorScreen(profile: s.extra as String?)),
      GoRoute(path: '/user-editor', builder: (c, s) => const UserEditorScreen()),
      GoRoute(path: '/memory-editor', builder: (c, s) => MemoryEditorScreen(profile: s.extra as String?)),
      GoRoute(path: '/agent-profiles', builder: (c, s) => const AgentProfilesScreen()),
      GoRoute(path: '/discover', builder: (c, s) => const RegistryDiscoverScreen()),
      GoRoute(path: '/capabilities', builder: (c, s) => const CapabilitiesScreen()),
      GoRoute(
        path: '/model-config',
        builder: (c, s) => ModelConfigScreen(initialProfile: s.extra as String?),
      ),
      GoRoute(path: '/kanban', builder: (c, s) => const KanbanScreen()),
      GoRoute(path: '/achievements', builder: (c, s) => const AchievementsScreen()),
      GoRoute(path: '/hermes-instance', builder: (c, s) => const HermesInstanceScreen()),
      GoRoute(
        path: '/gateway/:id',
        builder: (c, s) => GatewayConfigScreen(
          platformId: s.pathParameters['id'] ?? '',
          initialData: s.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(path: '/schedule/new', builder: (c, s) => const CreateEditScheduleScreen()),
      GoRoute(path: '/schedule/:id', builder: (c, s) => ScheduleDetailScreen(
        scheduleId: s.pathParameters['id'] ?? '',
      )),
      GoRoute(path: '/schedule/:id/edit', builder: (c, s) => CreateEditScheduleScreen(
        scheduleId: s.pathParameters['id'],
        initialData: s.extra as Map<String, dynamic>?,
      )),
      GoRoute(path: '/chat-room', builder: (c, s) {
        final extra = s.extra;
        String? title;
        String? sessionId;
        if (extra is Map<String, dynamic>) {
          title = extra['title'] as String?;
          sessionId = extra['sessionId'] as String?;
        } else if (extra is String) {
          title = extra;
        }
        return ChatRoomScreen(
          title: title,
          sessionId: sessionId,
        );
      }),
    ],
  );
}
