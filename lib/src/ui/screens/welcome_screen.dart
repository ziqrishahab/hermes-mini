import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter/services.dart";
import "package:go_router/go_router.dart";

import "../../providers/connection_provider.dart";
import "../../providers/theme_provider.dart";
import "../../services/storage_service.dart";
import "../../theme.dart";

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _floatingCtrl;

  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _floatingAnimation;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _floatingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _entryCtrl,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: Curves.easeOutCubic,
    ));

    _floatingAnimation = Tween<double>(
      begin: -4.0,
      end: 4.0,
    ).animate(CurvedAnimation(
      parent: _floatingCtrl,
      curve: Curves.easeInOutSine,
    ));

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _floatingCtrl.dispose();
    super.dispose();
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
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // Top Hero Visual with Floating Logo
                    Center(
                      child: AnimatedBuilder(
                        animation: _floatingCtrl,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _floatingAnimation.value),
                            child: child,
                          );
                        },
                        child: Container(
                          width: 156,
                          height: 156,
                          decoration: NeumorphicDecoration.circle(
                            color: isDark ? HermesTokens.charcoalSlate : HermesTokens.coolSilver,
                            distance: 6,
                            blur: 16,
                            isDark: isDark,
                          ),
                          padding: const EdgeInsets.all(22),
                          child: Image.asset(
                            HermesTokens.brandIconSet,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Main Headline & Subtitle
                    Center(
                      child: Text(
                        "Autonomous Intelligence,\nIn Your Hands.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: HermesTokens.textPrimary,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "Connect to your MyPixie agent daemon to run autonomous workflows, terminal tools, and real-time streaming.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: HermesTokens.textMuted.withValues(alpha: 0.9),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 3 Feature Highlight Cards
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildFeatureCard(
                            title: "Autonomous Reasoning",
                            description: "Multi-turn planning, proactive decision making, and persistent memory.",
                          ),
                          const SizedBox(height: 12),
                          _buildFeatureCard(
                            title: "Terminal & Sub-Shells",
                            description: "Run CLI tasks, inspect live daemon processes, and interrupt runs anytime.",
                          ),
                          const SizedBox(height: 12),
                          _buildFeatureCard(
                            title: "Real-Time Gateway",
                            description: "Fast JSON-RPC protocol over secure WebSockets with sub-second response.",
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Primary Action Button (Connect Gateway)
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        final hasCompleted = await StorageService().isOnboardingCompleted();
                        if (!context.mounted) return;
                        if (hasCompleted) {
                          ref.read(isOfflineModeProvider.notifier).state = true;
                          context.go('/home');
                        } else {
                          context.go('/onboarding');
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              HermesTokens.accent,
                              Color(0xFF8B5CF6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: HermesTokens.accent.withValues(alpha: 0.35),
                              offset: const Offset(0, 4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Connect Gateway",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: NeumorphicDecoration.raised(
        radius: 14,
        distance: 4,
        blur: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: HermesTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 11,
              color: HermesTokens.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
