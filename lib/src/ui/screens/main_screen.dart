import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';
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
    final isDark = ref.watch(isDarkProvider);
    return _mainBody(isDark);
  }

  Widget _mainBody(bool isDark) {
    final bgColor = isDark ? HermesColors.dark.bgPrimary : HermesColors.light.bgPrimary;
    final navBg = isDark ? HermesColors.dark.bgSecondary : HermesColors.light.bgSecondary;
    final accentColor = isDark ? HermesColors.dark.accent : HermesColors.light.accent;
    final inactiveColor = isDark ? HermesColors.dark.navInactive : HermesColors.light.navInactive;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
      color: bgColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(
          index: _tab,
          children: const [
            ChatScreen(),
            SchedulesScreen(),
            SettingsScreen(),
          ],
        ),
        bottomNavigationBar: RepaintBoundary(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.fastOutSlowIn,
          color: bgColor,
          child: SafeArea(
            top: false,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.fastOutSlowIn,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              height: 64,
              decoration: NeumorphicDecoration.raised(
                radius: 22,
                distance: 5,
                blur: 10,
                isDark: isDark,
                color: navBg,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tabWidth = constraints.maxWidth / _tabs.length;
                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.fastOutSlowIn,
                        left: _tab * tabWidth + 6,
                        top: 6,
                        width: tabWidth - 12,
                        height: constraints.maxHeight - 12,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.fastOutSlowIn,
                          decoration: NeumorphicDecoration.switcherThumb(
                            isDark: isDark,
                            radius: 16,
                          ),
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
                                duration: const Duration(milliseconds: 250),
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
                                            ? accentColor
                                            : inactiveColor,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeOutQuad,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? accentColor
                                            : inactiveColor,
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
      ),
      ),
      ),
    );
  }
}
