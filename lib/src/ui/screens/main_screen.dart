import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/connection_provider.dart';
import 'kanban_screen.dart';
import 'capabilities_screen.dart';
import 'chat_screen.dart';
import 'schedules_screen.dart';
import 'settings_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});
  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _tab = 0;

  static const _tabs = [
    ('Kanban', Icons.view_kanban),
    ('Capabilities', Icons.auto_awesome),
    ('Chat', Icons.chat_bubble),
    ('Schedules', Icons.schedule),
    ('Settings', Icons.settings),
  ];

  final _screens = const [
    KanbanScreen(),
    CapabilitiesScreen(),
    ChatScreen(),
    SchedulesScreen(),
    SettingsScreen(),
  ];

  void _switchTab(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final connState = ref.watch(connectionProvider);

    if (connState.isLoading) {
      return _splash('Connecting...');
    }

    if (connState.valueOrNull == null) {
      if (connState.hasError) {
        return _splash('Connection failed', onRetry: () {
          final config = ref.read(connectionConfigProvider);
          if (config != null) {
            ref.read(connectionProvider.notifier).testAndConnect(config);
          }
        });
      }
      // Still initializing, show splash
      return _splash('Connecting...');
    }

    return _mainBody();
  }

  Widget _mainBody() {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(key: ValueKey(_tab), child: _screens[_tab]),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
          ),
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final sel = _tab == i;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _switchTab(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        height: 3, width: sel ? 32 : 0,
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: sel ? const Color(0xFFC7B8EA) : Colors.transparent,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
                        ),
                      ),
                      Icon(_tabs[i].$2, size: 22,
                          color: sel ? const Color(0xFFC7B8EA) : const Color(0xFF666666)),
                      const SizedBox(height: 2),
                      Text(_tabs[i].$1,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                              color: sel ? const Color(0xFFC7B8EA) : const Color(0xFF666666))),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _splash(String msg, {VoidCallback? onRetry}) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.bolt, size: 64, color: Color(0xFFC7B8EA)),
          const SizedBox(height: 24),
          Text('Hermes', style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFFE5E2E1))),
          const SizedBox(height: 16),
          Text(msg, style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: const Color(0xFF948F99))),
          const SizedBox(height: 24),
          if (onRetry != null)
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC7B8EA),
                  foregroundColor: const Color(0xFF121212)),
            )
          else
            const SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFC7B8EA))),
        ]),
      ),
    );
  }
}