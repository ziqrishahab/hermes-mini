import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/connection_config.dart';
import '../../providers/connection_provider.dart';
import '../../theme.dart';
import '../widgets/fluid_pulse_indicator.dart';
import '../widgets/hermes_toast.dart';
import '../widgets/tactile_feedback.dart';

class HermesInstanceScreen extends ConsumerStatefulWidget {
  const HermesInstanceScreen({super.key});

  @override
  ConsumerState<HermesInstanceScreen> createState() =>
      _HermesInstanceScreenState();
}

class _HermesInstanceScreenState extends ConsumerState<HermesInstanceScreen> {
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();

  bool _obscureKey = true;
  bool _testing = false;
  bool _saving = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    final config = ref.read(connectionConfigProvider);
    if (config != null) {
      _urlCtrl.text = config.apiUrl ?? '';
      _keyCtrl.text = config.apiKey ?? '';
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<bool> _runTest({required bool isSaveAction}) async {
    final url = _urlCtrl.text.trim();
    final key = _keyCtrl.text.trim();

    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Gateway URL cannot be empty.';
        _successMessage = null;
      });
      return false;
    }
    if (key.isEmpty) {
      setState(() {
        _errorMessage = 'Password or API Key is required.';
        _successMessage = null;
      });
      return false;
    }

    setState(() {
      if (isSaveAction) {
        _saving = true;
      } else {
        _testing = true;
      }
      _errorMessage = null;
      _successMessage = null;
    });

    final newConfig = ConnectionConfig(
      mode: ConnectionMode.remote,
      apiUrl: url,
      apiKey: key,
    );

    try {
      final ok = await ref
          .read(connectionProvider.notifier)
          .testAndConnect(newConfig);
      if (!mounted) return false;

      setState(() {
        _testing = false;
        _saving = false;
      });

      if (ok) {
        setState(() {
          _successMessage = 'Connection verified successfully!';
        });
        return true;
      } else {
        final connState = ref.read(connectionProvider);
        final errorDetail = connState.whenOrNull(error: (e, _) => e.toString());
        setState(() {
          _errorMessage =
              errorDetail ??
              'Connection failed. Verify host, port, and credentials.';
        });
        return false;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testing = false;
          _saving = false;
          _errorMessage = e.toString();
        });
      }
      return false;
    }
  }

  Future<void> _saveAndConnect() async {
    final success = await _runTest(isSaveAction: true);
    if (success && mounted) {
      HermesToast.show(
        context,
        message: 'Hermes instance configuration updated and connected.',
        type: HermesToastType.success,
      );
      if (context.canPop()) {
        context.pop();
      }
    }
  }

  void _showConnectionGuideModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _HermesConnectionGuideSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connState = ref.watch(connectionProvider);
    final isConnected = connState.valueOrNull != null;
    final activeConfig = ref.watch(connectionConfigProvider);

    final String hostDisplay;
    final String urlDisplay;
    if (!isConnected) {
      hostDisplay = 'Disconnected';
      urlDisplay = (activeConfig == null)
          ? 'No active instance configured'
          : 'Gateway offline • Connect to view details';
    } else if (activeConfig == null) {
      hostDisplay = 'Not Configured';
      urlDisplay = 'No active connection parameters';
    } else {
      final uri = Uri.tryParse(activeConfig.apiUrl ?? '');
      hostDisplay = (uri != null && uri.host.isNotEmpty)
          ? uri.host
          : (activeConfig.apiUrl ?? 'Remote Gateway');
      urlDisplay = activeConfig.apiUrl ?? 'http://<host-ip>:9119';
    }

    return Scaffold(
      backgroundColor: HermesTokens.bgPrimary,
      appBar: AppBar(
        backgroundColor: HermesTokens.bgPrimary,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: NeumorphicDecoration.raised(
                radius: 12,
                distance: 2.5,
                blur: 5,
              ),
              child: IconButton(
                tooltip: 'Back to settings',
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: HermesTokens.textPrimary,
                  size: 16,
                ),
                onPressed: () => context.pop(),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        title: const Text(
          'Hermes Instance',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: HermesTokens.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: NeumorphicDecoration.raised(
                  radius: 12,
                  distance: 2.5,
                  blur: 5,
                ),
                child: IconButton(
                  tooltip: 'Connection Setup Guide',
                  icon: const Icon(
                    Icons.help_outline_rounded,
                    color: HermesTokens.accent,
                    size: 20,
                  ),
                  onPressed: _showConnectionGuideModal,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Clean Status Overview Card (Text only, no green badge or noisy pills)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: NeumorphicDecoration.raised(radius: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        FluidPulseIndicator(
                          color: isConnected
                              ? HermesTokens.success
                              : HermesTokens.error,
                          size: 7,
                          animate: isConnected,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isConnected ? 'Connected' : 'Disconnected',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isConnected
                                ? HermesTokens.success
                                : HermesTokens.error,
                          ),
                        ),
                        Text(
                          isConnected ? ' • Remote Gateway' : ' • Offline',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: HermesTokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hostDisplay,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: HermesTokens.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      urlDisplay,
                      style: const TextStyle(
                        fontSize: 12,
                        color: HermesTokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 2. Form Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: NeumorphicDecoration.raised(radius: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DAEMON CONNECTION PARAMETERS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: HermesTokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Gateway URL
                    const Text(
                      'GATEWAY URL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: HermesTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: NeumorphicDecoration.recessed(radius: 14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      child: TextField(
                        controller: _urlCtrl,
                        keyboardType: TextInputType.url,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: HermesTokens.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'http://<host-ip>:9119',
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: HermesTokens.textMuted,
                          ),
                          border: InputBorder.none,
                          prefixIcon: const Icon(
                            Icons.link_rounded,
                            size: 18,
                            color: HermesTokens.textMuted,
                          ),
                          suffixIcon: _urlCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 16,
                                    color: HermesTokens.textMuted,
                                  ),
                                  onPressed: () {
                                    _urlCtrl.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Password / API Key
                    const Text(
                      'PASSWORD / API KEY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: HermesTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: NeumorphicDecoration.recessed(radius: 14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      child: TextField(
                        controller: _keyCtrl,
                        obscureText: _obscureKey,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: HermesTokens.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Password / Api Token',
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: HermesTokens.textMuted,
                          ),
                          border: InputBorder.none,
                          prefixIcon: const Icon(
                            Icons.key_outlined,
                            size: 18,
                            color: HermesTokens.textMuted,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureKey
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                              color: HermesTokens.textMuted,
                            ),
                            onPressed: () =>
                                setState(() => _obscureKey = !_obscureKey),
                          ),
                          isDense: true,
                        ),
                      ),
                    ),

                    // Success Feedback Banner
                    if (_successMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: HermesTokens.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: HermesTokens.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              color: HermesTokens.success,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: HermesTokens.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Error Feedback Banner
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: HermesTokens.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: HermesTokens.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: HermesTokens.error,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: HermesTokens.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        // Test Connection Button
                        Expanded(
                          child: TactileContainer(
                            onTap: (_testing || _saving)
                                ? null
                                : () => _runTest(isSaveAction: false),
                            child: Container(
                              height: 46,
                              alignment: Alignment.center,
                              decoration: NeumorphicDecoration.raised(
                                radius: 14,
                                distance: 2.5,
                                blur: 5,
                              ),
                              child: _testing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: HermesTokens.textSecondary,
                                      ),
                                    )
                                  : const Text(
                                      'Test Connection',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: HermesTokens.textPrimary,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Save & Connect Button
                        Expanded(
                          child: TactileContainer(
                            onTap: (_testing || _saving)
                                ? null
                                : _saveAndConnect,
                            child: Container(
                              height: 46,
                              alignment: Alignment.center,
                              decoration: NeumorphicDecoration.raised(
                                radius: 14,
                                color: HermesTokens.accent,
                                distance: 3.5,
                                blur: 7,
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Save & Connect',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Footer Note
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: NeumorphicDecoration.recessed(radius: 16),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 14,
                        color: HermesTokens.textMuted,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Direct connection to your private Hermes instance',
                        style: TextStyle(
                          fontSize: 11,
                          color: HermesTokens.textMuted,
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
    );
  }
}

// ── CONNECTION GUIDE MODAL BOTTOM SHEET ──

class _GuideStep {
  final String title;
  final String? details;
  final String? code;

  const _GuideStep({required this.title, this.details, this.code});
}

class _HermesConnectionGuideSheet extends StatefulWidget {
  const _HermesConnectionGuideSheet();

  @override
  State<_HermesConnectionGuideSheet> createState() =>
      _HermesConnectionGuideSheetState();
}

class _HermesConnectionGuideSheetState
    extends State<_HermesConnectionGuideSheet> {
  int _activeTab = 0; // 0: Local (LAN), 1: Remote Access, 2: Token / Auth

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: HermesTokens.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: HermesTokens.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header (Clean, left-aligned without redundant book icon)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hermes Connection Guide',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: HermesTokens.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Step-by-step instructions for local and remote gateway access',
                        style: TextStyle(
                          fontSize: 11,
                          color: HermesTokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: HermesTokens.textMuted,
                  ),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Segmented Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: NeumorphicDecoration.recessed(radius: 14),
              child: Row(
                children: [
                  _tabItem(0, 'Local (LAN)'),
                  _tabItem(1, 'Remote Access'),
                  _tabItem(2, 'Token / Auth'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Tab Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
              child: _activeTab == 0
                  ? _buildLanGuide()
                  : _activeTab == 1
                  ? _buildRemoteGuide()
                  : _buildAuthGuide(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabItem(int index, String label) {
    final active = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: active
              ? NeumorphicDecoration.raised(radius: 10, distance: 2, blur: 4)
              : null,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? HermesTokens.accent : HermesTokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          title: 'Same Wi-Fi Network',
          subtitle:
              'Recommended for home or office setup where mobile and computer share the same Wi-Fi router.',
          steps: const [
            _GuideStep(
              title: 'Start Hermes gateway on your computer',
              details: 'Run this command in your computer terminal:',
              code: 'hermes gateway --host 0.0.0.0 --port 9119',
            ),
            _GuideStep(
              title: 'Find your computer local IPv4 address',
              details:
                  'Windows: run "ipconfig" in Command Prompt (look for IPv4, e.g. 192.168.1.15).\nmacOS / Linux: run "ip a" or "ifconfig".',
            ),
            _GuideStep(
              title: 'Enter the Gateway URL in Hermes Mobile',
              details: 'Combine your computer IP address with port 9119:',
              code: 'http://192.168.x.x:9119',
            ),
          ],
        ),

        const SizedBox(height: 14),

        _buildSectionCard(
          title: 'Android Emulator & USB Cable',
          subtitle:
              'Direct local testing on a development workstation without requiring Wi-Fi.',
          steps: const [
            _GuideStep(
              title: 'Android Studio Emulator',
              details:
                  'Android emulators access host services through the loopback router alias:',
              code: 'http://10.0.2.2:9119',
            ),
            _GuideStep(
              title: 'Physical Phone via USB Debugging',
              details:
                  'Forward port 9119 over ADB, then connect using localhost:',
              code: 'adb reverse tcp:9119 tcp:9119',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRemoteGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          title: 'Cloudflare Quick Tunnel',
          subtitle:
              'Free, secure, and instant. Access Hermes anywhere on cellular data without port forwarding.',
          steps: const [
            _GuideStep(
              title: 'Install Cloudflared on your computer',
              details:
                  'Download cloudflared via your package manager (brew, winget, apt) or from Cloudflare.',
            ),
            _GuideStep(
              title: 'Start a free public tunnel',
              details: 'Run this command to generate an instant HTTPS URL:',
              code: 'cloudflared tunnel --url http://localhost:9119',
            ),
            _GuideStep(
              title: 'Copy the HTTPS URL into Hermes Mobile',
              details:
                  'Copy the assigned URL (e.g. https://xxxx.trycloudflare.com) and paste it into the Gateway URL field.',
            ),
          ],
        ),

        const SizedBox(height: 14),

        _buildSectionCard(
          title: 'Tailscale Mesh VPN',
          subtitle:
              'Direct encrypted connection across all your personal devices.',
          steps: const [
            _GuideStep(
              title: 'Install Tailscale on computer and mobile',
              details: 'Log into the same Tailscale account on both devices.',
            ),
            _GuideStep(
              title: 'Connect using the 100.x.y.z IP',
              details: 'Copy your computer Tailscale 100.x.y.z IP and enter:',
              code: 'http://100.x.y.z:9119',
            ),
          ],
        ),

        const SizedBox(height: 14),

        _buildSectionCard(
          title: 'Public Cloud VPS / Custom Domain',
          subtitle:
              'For permanent cloud servers on DigitalOcean, Hetzner, AWS, etc.',
          steps: const [
            _GuideStep(
              title: 'Open firewall port or reverse proxy',
              details:
                  'Allow port 9119 on cloud firewall, or configure Nginx/Caddy with SSL.',
            ),
            _GuideStep(
              title: 'Enter public domain endpoint',
              details: 'Connect using your public IP or domain name:',
              code: 'https://hermes.yourdomain.com',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAuthGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          title: 'Password & Security Token',
          subtitle:
              'Required to authenticate and authorize mobile actions with your Hermes daemon.',
          steps: const [
            _GuideStep(
              title: 'Locate authentication token',
              details:
                  'Hermes saves your dashboard and API token in the configuration file on your host machine:',
              code: '~/.hermes/hermes.json',
            ),
            _GuideStep(
              title: 'Or start gateway with a custom token',
              details:
                  'You can define an explicit token when starting the gateway service:',
              code: 'hermes gateway --token YOUR_SECRET_KEY',
            ),
            _GuideStep(
              title: 'Enter token into Hermes Mobile',
              details:
                  'Paste this token into the "Password / API Key" field on the configuration page.',
            ),
          ],
        ),

        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HermesTokens.bgPrimary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HermesTokens.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Troubleshooting Tips',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: HermesTokens.textPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '• If connection times out on Wi-Fi, verify that port 9119 is allowed through Windows Defender Firewall or Linux ufw.\n• Check that your Wi-Fi router does not enforce "Client Isolation" or "AP Isolation".\n• For immediate remote access without router configuration, use Cloudflare Tunnel.',
                style: TextStyle(
                  fontSize: 11,
                  color: HermesTokens.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required List<_GuideStep> steps,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: NeumorphicDecoration.raised(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: HermesTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: HermesTokens.textMuted,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: HermesTokens.divider),
          const SizedBox(height: 12),

          for (int i = 0; i < steps.length; i++) ...[
            _buildStepRow(index: i + 1, step: steps[i]),
            if (i < steps.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildStepRow({required int index, required _GuideStep step}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step number indicator
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: HermesTokens.bgSecondary,
            shape: BoxShape.circle,
            border: Border.all(color: HermesTokens.border),
          ),
          child: Text(
            '$index',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: HermesTokens.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HermesTokens.textPrimary,
                ),
              ),
              if (step.details != null) ...[
                const SizedBox(height: 2),
                Text(
                  step.details!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: HermesTokens.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
              if (step.code != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: NeumorphicDecoration.recessed(radius: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          step.code!,
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11,
                            color: HermesTokens.accentText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: step.code!));
                          HermesToast.show(
                            context,
                            message: 'Copied to clipboard',
                            type: HermesToastType.info,
                          );
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(3),
                          child: Icon(
                            Icons.copy_rounded,
                            size: 15,
                            color: HermesTokens.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
