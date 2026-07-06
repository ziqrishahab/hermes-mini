import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'ui/screens/connection_screen.dart';
import 'ui/screens/chat_screen.dart';
import 'ui/screens/main_screen.dart';
import 'providers/connection_provider.dart';
import 'config/dev_config.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: devBypassConnection ? '/home' : '/connect',
    redirect: (context, state) {
      if (devBypassConnection) return null;

      final container = ProviderScope.containerOf(context);
      final conn = container.read(connectionProvider);
      final isConnected = conn.valueOrNull != null;

      if (isConnected && state.matchedLocation == '/connect') return '/home';
      if (!isConnected && state.matchedLocation != '/connect') return '/connect';
      return null;
    },
    routes: [
      GoRoute(path: '/connect', builder: (c, s) => const ConnectionScreen()),
      GoRoute(path: '/chat', builder: (c, s) => const ChatScreen()),
      GoRoute(path: '/home', builder: (c, s) => const MainScreen()),
    ],
  );
}
