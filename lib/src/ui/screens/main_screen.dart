import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import 'chat_screen.dart';
import 'schedules_screen.dart';
import 'settings_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});
  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _tab = 0; // Default to Chat tab

  static const _tabs = [
    ('Chat', Icons.chat_bubble_outline, Icons.chat_bubble),
    ('Schedules', Icons.schedule_outlined, Icons.schedule),
    ('Settings', Icons.settings_outlined, Icons.settings),
  ];


  @override
  Widget build(BuildContext context) {
    return _mainBody();
  }

  Widget _mainBody() {
    return Scaffold(
      backgroundColor: HermesTokens.bgPrimary,
      body: IndexedStack(
        index: _tab,
        children: const [
          ChatScreen(),
          SchedulesScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: SafeArea(
              top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          height: 64,
          decoration: NeumorphicDecoration.raised(
            radius: 22,
            distance: 4,
            blur: 8,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / _tabs.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    left: _tab * tabWidth + 6,
                    top: 6,
                    width: tabWidth - 12,
                    height: constraints.maxHeight - 12,
                    child: Container(
                      decoration: NeumorphicDecoration.recessed(radius: 14),
                    ),
                  ),
                  Row(
                    children: List.generate(_tabs.length, (index) {
                      final item = _tabs[index];
                      final isSelected = _tab == index;

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (_tab != index) {
                              HapticFeedback.selectionClick();
                              setState(() => _tab = index);
                            }
                          },
                          child: Center(
                            child: AnimatedScale(
                              scale: isSelected ? 1.06 : 0.94,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutBack,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child: Icon(
                                      isSelected ? item.$3 : item.$2,
                                      key: ValueKey(isSelected),
                                      size: 20,
                                      color: isSelected
                                          ? HermesTokens.accent
                                          : HermesTokens.navInactive,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOutQuad,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? HermesTokens.accent
                                          : HermesTokens.navInactive,
                                    ),
                                    child: Text(
                                      item.$1,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
