import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/connection_config.dart';
import '../../providers/connection_provider.dart';
import '../../theme.dart';
import '../widgets/tactile_feedback.dart';

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
  bool _showGuide = false;

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
    final url = _apiUrlCtrl.text.trim();
    final key = _apiKeyCtrl.text.trim();

    if (url.isEmpty || key.isEmpty) {
      _showError('Please enter both Gateway URL and Password / API Key');
      return;
    }

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

  @override
  Widget build(BuildContext context) {
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
                      width: 76,
                      height: 76,
                      decoration: NeumorphicDecoration.circle(
                        distance: 5,
                        blur: 10,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/icons/hermes_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              size: 36,
                              color: HermesTokens.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Brand Title
                  const Center(
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

                  const Center(
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
                          hint: 'Hostname / IP Address',
                          icon: Icons.link_rounded,
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 18),

                        // Password / API Key Field
                        _buildNeumorphicField(
                          controller: _apiKeyCtrl,
                          focusNode: _apiKeyFocus,
                          label: 'PASSWORD / API KEY',
                          hint: 'Password / Api Token',
                          icon: Icons.key_outlined,
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

                        const SizedBox(height: 14),

                        // Toggle Connection Setup Guide
                        GestureDetector(
                          onTap: () => setState(() => _showGuide = !_showGuide),
                          child: Row(
                            children: [
                              Icon(
                                _showGuide
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.help_outline_rounded,
                                size: 15,
                                color: HermesTokens.accentText,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _showGuide
                                    ? 'Hide connection guide'
                                    : 'How does Remote Gateway work?',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: HermesTokens.accentText,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (_showGuide) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: NeumorphicDecoration.recessed(
                              radius: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "1. Local Network",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: HermesTokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Run on host: hermes dashboard --host 0.0.0.0\n"
                                  "Ensure phone and host share the same Wi-Fi. Enter host local IP, e.g. http://<host-ip>:9119.",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: HermesTokens.textMuted,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "2. Remote Access",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: HermesTokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Use Tailscale (http://100.x.y.z:9119) or Cloudflare Tunnel (https://your-domain.com).",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: HermesTokens.textMuted,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

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
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Connect',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Footer Security Note (Recessed Neumorphic Pill)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: NeumorphicDecoration.recessed(radius: 20),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 13,
                            color: HermesTokens.textMuted,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Credentials stored securely on device',
                            style: TextStyle(
                              fontSize: 11,
                              color: HermesTokens.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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
    required IconData icon,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: HermesTokens.textMuted,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          decoration: NeumorphicDecoration.recessed(radius: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: HermesTokens.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              icon: Icon(icon, size: 18, color: HermesTokens.textMuted),
              hintText: hint,
              hintStyle: const TextStyle(
                color: HermesTokens.textMuted,
                fontSize: 13,
              ),
              suffixIcon: suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}
