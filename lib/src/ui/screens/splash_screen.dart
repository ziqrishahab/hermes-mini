import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../config/dev_config.dart";
import "../../providers/connection_provider.dart";
import "../../theme.dart";
import "../widgets/hermes_loading_indicator.dart";

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textFade;
  late final Animation<double> _indicatorFade;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _logoScale = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
    );

    _logoFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
    ));

    _textFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
    );

    _indicatorFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
    );

    _pulseAnimation = CurvedAnimation(
      parent: _pulseCtrl,
      curve: Curves.easeInOutSine,
    );

    _entryCtrl.forward();
    _startNavigationTimer();
  }

  void _startNavigationTimer() {
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;

      final isConnected = ref.read(connectionProvider).valueOrNull != null;
      if (devBypassConnection || isConnected) {
        context.go('/home');
      } else {
        context.go('/welcome');
      }
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: HermesTokens.bgPrimary,
      ),
      child: Scaffold(
        backgroundColor: HermesTokens.bgPrimary,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // Animated Hero Logo with Neumorphic Surface & Glowing Aura
              Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_entryCtrl, _pulseCtrl]),
                  builder: (context, child) {
                    final pulseScale = 1.0 + (_pulseAnimation.value * 0.08);
                    final auraOpacity = 0.25 + (_pulseAnimation.value * 0.25);

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Dynamic Aura Glow matching the cyan fairy wing glow
                        Transform.scale(
                          scale: pulseScale,
                          child: Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF38BDF8).withValues(alpha: auraOpacity),
                                  HermesTokens.accent.withValues(alpha: auraOpacity * 0.5),
                                  Colors.transparent,
                                ],
                                stops: const [0.2, 0.6, 1.0],
                              ),
                            ),
                          ),
                        ),

                        // Logo Card with Spring Entry
                        FadeTransition(
                          opacity: _logoFade,
                          child: ScaleTransition(
                            scale: _logoScale,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: NeumorphicDecoration.circle(
                                distance: 8,
                                blur: 16,
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/icons/hermes_logo.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: HermesTokens.bgSecondary,
                                    child: const Center(
                                      child: Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 48,
                                        color: HermesTokens.accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 32),

              // App Title & Tagline with Staggered Slide-Fade
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textFade,
                  child: Column(
                    children: [
                      const Text(
                        "M Y P I X I E",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 8,
                          color: HermesTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "AUTONOMOUS AGENT COMPANION",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.5,
                          color: HermesTokens.textMuted.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Custom Shimmering Liquid Capsule Bar (Replacing spinner)
              FadeTransition(
                opacity: _indicatorFade,
                child: const HermesLoadingIndicator(
                  width: 130,
                  height: 4.5,
                  statusText: "Initializing MyPixie Engine...",
                ),
              ),

              const Spacer(flex: 4),

              // Bottom subtle version info
              FadeTransition(
                opacity: _indicatorFade,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    "v1.0.0 • MyPixie",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: HermesTokens.textMuted.withValues(alpha: 0.6),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
