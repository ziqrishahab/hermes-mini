import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/connection_config.dart';
import '../../providers/connection_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme.dart';
import '../widgets/tactile_feedback.dart';
import '../widgets/hermes_setup_guide.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  final _apiUrlCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();

  final _apiUrlFocus = FocusNode();
  final _apiKeyFocus = FocusNode();

  bool _testing = false;
  bool _showApiKey = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(connectionConfigProvider);
    if (saved != null) {
      _apiUrlCtrl.text = saved.apiUrl ?? '';
      _apiKeyCtrl.text = saved.apiKey ?? '';
    } else {
      _apiUrlCtrl.text = '';
      _apiKeyCtrl.text = '';
    }
  }

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _apiUrlFocus.dispose();
    _apiKeyFocus.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    var url = _apiUrlCtrl.text.trim().replaceAll(RegExp(r'\s+'), '');
    final key = _apiKeyCtrl.text.trim();

    if (url.isEmpty || key.isEmpty) {
      _showError('Please enter both Gateway URL and Password / API Key');
      return;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    _apiUrlCtrl.text = url;

    final config = ConnectionConfig(
      mode: ConnectionMode.remote,
      apiUrl: url,
      apiKey: key,
    );

    setState(() => _testing = true);

    final ok = await ref
        .read(connectionProvider.notifier)
        .testAndConnect(config);

    if (!mounted) return;
    setState(() => _testing = false);

    if (ok) {
      context.go('/home');
    } else {
      final err = ref
          .read(connectionProvider)
          .whenOrNull(error: (e, _) => e.toString());
      _showError(err ?? 'Connection failed. Verify host and credentials.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: HermesTokens.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showGatewaySetupSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          decoration: BoxDecoration(
            color: HermesTokens.bgPrimary,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(HermesTokens.radiusLg),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
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
              Text(
                'Remote Gateway Setup Guide',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: HermesTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              const HermesSetupGuide(),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HermesTokens.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.w600),
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
    final isDark = ref.watch(isDarkProvider);
    return Scaffold(
      backgroundColor: HermesTokens.bgPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo Container (Neumorphic Raised with Hermes Asset)
                  Center(
                    child: Container(
                      width: 132,
                      height: 132,
                      decoration: NeumorphicDecoration.circle(
                        color: isDark ? HermesTokens.charcoalSlate : HermesTokens.coolSilver,
                        distance: 6,
                        blur: 14,
                        isDark: isDark,
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Image.asset(
                        HermesTokens.brandIconSet,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Brand Title
                  Center(
                    child: Text(
                      'MyPixie',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: HermesTokens.textPrimary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Center(
                    child: Text(
                      'Remote Gateway Connection',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: HermesTokens.textSecondary,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Main Form Card (Neumorphic Raised Container)
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: NeumorphicDecoration.raised(
                      radius: 22,
                      distance: 5.5,
                      blur: 11,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Gateway URL Field
                        _buildNeumorphicField(
                          controller: _apiUrlCtrl,
                          focusNode: _apiUrlFocus,
                          label: 'GATEWAY URL',
                          hint: 'http://host:port',
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 18),

                        // Password / API Key Field
                        _buildNeumorphicField(
                          controller: _apiKeyCtrl,
                          focusNode: _apiKeyFocus,
                          label: 'PASSWORD / API KEY',
                          hint: 'Password or API key',
                          keyboardType: TextInputType.visiblePassword,
                          obscureText: !_showApiKey,
                          suffix: IconButton(
                            icon: Icon(
                              _showApiKey
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 18,
                              color: HermesTokens.textMuted,
                            ),
                            onPressed: () =>
                                setState(() => _showApiKey = !_showApiKey),
                          ),
                        ),

                        const SizedBox(height: 22),

                        // Connect Button (Neumorphic Primary Button)
                        TactileContainer(
                          onTap: _testing ? null : _connect,
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            decoration: NeumorphicDecoration.raised(
                              radius: 14,
                              color: HermesTokens.accent,
                              distance: 3.5,
                              blur: 7,
                            ),
                            child: _testing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Connect',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Gateway Setup Modal Button (Neumorphic Raised Template)
                        TactileContainer(
                          onTap: _showGatewaySetupSheet,
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: NeumorphicDecoration.raised(
                              radius: 14,
                              distance: 2.5,
                              blur: 5,
                            ),
                            child: Text(
                              'Gateway Setup Guide',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: HermesTokens.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Center(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ref.read(isOfflineModeProvider.notifier).state = true;
                              GoRouter.maybeOf(context)?.go('/home');
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                              child: Text(
                                'Explore in Offline Mode',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: HermesTokens.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeumorphicField({
    required TextEditingController controller,
    required String label,
    required String hint,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) {
    final isDark = HermesTokens.isDark;

    final borderSide = BorderSide(
      color: isDark ? const Color(0x22FFFFFF) : const Color(0x2294A3B8),
      width: 1.0,
    );

    final focusBorderSide = BorderSide(
      color: HermesTokens.accent,
      width: 1.4,
    );

    final borderRadius = BorderRadius.circular(12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: HermesTokens.textMuted,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: TextStyle(
            color: HermesTokens.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: HermesTokens.bgTertiary,
            hintText: hint,
            hintStyle: TextStyle(
              color: HermesTokens.textMuted,
              fontSize: 13,
            ),
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: borderSide,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: borderSide,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: focusBorderSide,
            ),
          ),
        ),
      ],
    );
  }
}
