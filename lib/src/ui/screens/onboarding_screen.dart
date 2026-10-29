import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/theme_provider.dart';
import '../../services/accessibility_service.dart';
import '../../services/storage_service.dart';
import '../../theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final StorageService _storageService = StorageService();

  late final AnimationController _floatingCtrl;
  late final Animation<double> _floatingAnimation;

  int _currentPage = 0;
  bool _isAccessibilityActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _floatingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _floatingAnimation = Tween<double>(
      begin: -6.0,
      end: 6.0,
    ).animate(CurvedAnimation(
      parent: _floatingCtrl,
      curve: Curves.easeInOutSine,
    ));

    _checkAccessibility();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _floatingCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccessibility();
    }
  }

  Future<void> _checkAccessibility() async {
    final active = await AccessibilityService.isEnabled();
    if (!mounted) return;

    if (active && !_isAccessibilityActive) {
      HapticFeedback.mediumImpact();
    }

    setState(() {
      _isAccessibilityActive = active;
    });
  }

  Future<void> _completeOnboarding() async {
    HapticFeedback.mediumImpact();
    await _storageService.setOnboardingCompleted(true);
    if (!mounted) return;
    context.go('/connect');
  }

  void _nextPage() {
    HapticFeedback.selectionClick();
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _openAccessibilitySettings() async {
    HapticFeedback.selectionClick();
    await AccessibilityService.openSettings();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: HermesTokens.bgPrimary,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: HermesTokens.bgPrimary,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 48),
              _buildPersistentHero(isDark),
              const SizedBox(height: 28),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (idx) {
                    setState(() => _currentPage = idx);
                    if (idx == 2) {
                      _checkAccessibility();
                    }
                  },
                  children: [
                    _buildContentSlide1(),
                    _buildContentSlide2(),
                    _buildContentSlide3(),
                  ],
                ),
              ),
              _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersistentHero(bool isDark) {
    return AnimatedBuilder(
      animation: _floatingAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatingAnimation.value),
          child: Container(
            width: 186,
            height: 186,
            decoration: NeumorphicDecoration.raised(
              color: isDark ? HermesTokens.charcoalSlate : HermesTokens.coolSilver,
              radius: 93,
              distance: 6,
              blur: 16,
              isDark: isDark,
            ),
            padding: const EdgeInsets.all(22),
            child: Center(
              child: Image.asset(
                HermesTokens.brandIconSet,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSlideContainer({required Widget child}) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
      child: child,
    );
  }

  Widget _buildContentSlide1() {
    return _buildSlideContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Autonomous AI Daemon\nin Your Pocket',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: HermesTokens.textPrimary,
              height: 1.25,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Direct, sovereign connection to your private Hermes daemon. Full control over models, skills, memory, and scheduled automations with zero cloud intermediaries.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: HermesTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSlide2() {
    return _buildSlideContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Remote Vibe Coding &\nGateway Bridges',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: HermesTokens.textPrimary,
              height: 1.25,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Edit workspace code remotely, execute scheduled cron tasks 24/7, and route conversational workflows across WhatsApp, Telegram, and Discord simultaneously.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: HermesTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSlide3() {
    return _buildSlideContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isAccessibilityActive
                ? 'Device Automation\nis Configured'
                : 'Android Device\nAutomation',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: HermesTokens.textPrimary,
              height: 1.25,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _isAccessibilityActive
                ? 'Hermes Accessibility Service is verified and running. Your agent can execute taps, inputs, and mobile gestures on this device.'
                : 'Enable the Hermes Accessibility Service to allow your agent to navigate apps, tap buttons, and execute actions on this phone.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: HermesTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: NeumorphicDecoration.recessed(radius: 14),
            child: Row(
              children: [
                Icon(
                  _isAccessibilityActive
                      ? Icons.check_circle_outline_rounded
                      : Icons.shield_outlined,
                  size: 18,
                  color: _isAccessibilityActive
                      ? HermesTokens.success
                      : HermesTokens.accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isAccessibilityActive
                        ? 'Ready for autonomous mobile gestures'
                        : 'Local on-device execution with zero external logging',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: HermesTokens.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final isCurrent = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isCurrent ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? HermesTokens.accent
                      : HermesTokens.textMuted.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          _buildActionButton(),
          if (_currentPage == 2 && !_isAccessibilityActive) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _completeOnboarding,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Configure later in Settings',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: HermesTokens.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final isLastPage = _currentPage == 2;

    String label;
    IconData icon;
    VoidCallback onTap;

    if (!isLastPage) {
      label = 'Continue';
      icon = Icons.arrow_forward_rounded;
      onTap = _nextPage;
    } else {
      if (!_isAccessibilityActive) {
        label = 'Enable Accessibility Service';
        icon = Icons.settings_outlined;
        onTap = _openAccessibilitySettings;
      } else {
        label = 'Connect Gateway';
        icon = Icons.arrow_forward_rounded;
        onTap = _completeOnboarding;
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isAccessibilityActive && isLastPage
                ? [
                    HermesTokens.accent,
                    const Color(0xFF10B981),
                  ]
                : [
                    HermesTokens.accent,
                    const Color(0xFF8B5CF6),
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (_isAccessibilityActive && isLastPage
                      ? const Color(0xFF10B981)
                      : HermesTokens.accent)
                  .withValues(alpha: 0.35),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                icon,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
