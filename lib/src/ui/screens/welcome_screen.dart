import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:go_router/go_router.dart";

import "../../theme.dart";

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
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

  void _showQuickSetupSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          decoration: const BoxDecoration(
            color: HermesTokens.bgPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(HermesTokens.radiusLg)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HermesTokens.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "MyPixie Gateway Setup",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: HermesTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Run the dashboard command on your server or PC terminal to start the mobile gateway:",
                style: TextStyle(
                  fontSize: 12,
                  color: HermesTokens.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: NeumorphicDecoration.recessed(radius: 12),
                child: const SelectableText(
                  "hermes dashboard --host 0.0.0.0 --port 9119",
                  style: TextStyle(
                    fontFamily: "monospace",
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: HermesTokens.accent,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HermesTokens.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/connect');
                  },
                  child: const Text(
                    "Ready to Connect",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
                          width: 84,
                          height: 84,
                          decoration: NeumorphicDecoration.circle(
                            distance: 6,
                            blur: 14,
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/icons/hermes_logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.auto_awesome_rounded,
                                size: 36,
                                color: HermesTokens.accent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Main Headline & Subtitle
                    const Center(
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
                            icon: Icons.psychology_rounded,
                            iconColor: HermesTokens.accent,
                            title: "Autonomous Reasoning",
                            description: "Multi-turn planning, proactive decision making, and persistent memory.",
                          ),
                          const SizedBox(height: 12),
                          _buildFeatureCard(
                            icon: Icons.terminal_rounded,
                            iconColor: const Color(0xFF0EA5E9), // Cyan / Sky Blue
                            title: "Terminal & Sub-Shells",
                            description: "Run CLI tasks, inspect live daemon processes, and interrupt runs anytime.",
                          ),
                          const SizedBox(height: 12),
                          _buildFeatureCard(
                            icon: Icons.hub_rounded,
                            iconColor: const Color(0xFF10B981), // Emerald Green
                            title: "Real-Time Gateway",
                            description: "Fast JSON-RPC protocol over secure WebSockets with sub-second response.",
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Primary Action Button (Connect Gateway)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        context.go('/connect');
                      },
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
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

                    const SizedBox(height: 8),

                    // Secondary Text Button (Setup Guide)
                    Center(
                      child: TextButton(
                        onPressed: _showQuickSetupSheet,
                        child: const Text(
                          "How to start Hermes Gateway?",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: HermesTokens.textMuted,
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
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: NeumorphicDecoration.raised(
        radius: 14,
        distance: 4,
        blur: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: HermesTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: HermesTokens.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
