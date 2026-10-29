import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/connection_config.dart';
import '../../models/config_health_item.dart';
import '../../providers/connection_provider.dart';
import '../../theme.dart';
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

  int? _measuredLatency;
  bool _measuringLatency = false;

  Future<void> _pingInstance() async {
    setState(() => _measuringLatency = true);
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn != null) {
      final sw = Stopwatch()..start();
      try {
        await conn.health();
      } catch (_) {}
      sw.stop();
      if (mounted) {
        setState(() {
          _measuredLatency = sw.elapsedMilliseconds;
          _measuringLatency = false;
        });
      }
    } else {
      if (mounted) setState(() => _measuringLatency = false);
    }
  }

  List<ConfigHealthItem>? _diagnosticsResults;
  bool _runningDiagnostics = false;

  Future<void> _runDiagnostics() async {
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) {
      HermesToast.show(
        context,
        message: "Instance is not connected",
        type: HermesToastType.error,
      );
      return;
    }

    setState(() => _runningDiagnostics = true);
    try {
      final results = await conn.runConfigHealthAudit();
      if (mounted) {
        setState(() {
          _diagnosticsResults = results;
          _runningDiagnostics = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _runningDiagnostics = false);
        HermesToast.show(
          context,
          message: "Diagnostics check failed: $e",
          type: HermesToastType.error,
        );
      }
    }
  }

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
    var url = _urlCtrl.text.trim().replaceAll(RegExp(r'\s+'), '');
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

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    _urlCtrl.text = url;

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
      urlDisplay = activeConfig.apiUrl ?? 'Not configured';
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
                icon: Icon(
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
        title: Text(
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
                  icon: Icon(
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
              // 1. Clean Status Overview Card with Latency Ping
              Container(
                padding: const EdgeInsets.all(18),
                decoration: NeumorphicDecoration.raised(radius: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
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
                                isConnected ? ' • Remote' : ' • Offline',
                                style: TextStyle(
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
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: HermesTokens.textPrimary,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            urlDisplay,
                            style: TextStyle(
                              fontSize: 12,
                              color: HermesTokens.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 88,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: NeumorphicDecoration.recessed(radius: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'LATENCY',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: HermesTokens.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _measuredLatency != null ? '$_measuredLatency ms' : 'Untested',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _measuredLatency != null
                                      ? (_measuredLatency! < 150
                                          ? HermesTokens.success
                                          : (_measuredLatency! < 400
                                              ? const Color(0xFFF59E0B)
                                              : HermesTokens.error))
                                      : HermesTokens.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        TactileContainer(
                          onTap: _measuringLatency ? null : _pingInstance,
                          child: Container(
                            width: 88,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: NeumorphicDecoration.raised(
                              radius: 8,
                              distance: 1.5,
                              blur: 3,
                            ),
                            child: _measuringLatency
                                ? SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: HermesTokens.accent,
                                    ),
                                  )
                                : Text(
                                    'Test Latency',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: HermesTokens.textPrimary,
                                    ),
                                  ),
                          ),
                        ),
                      ],
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
                    Text(
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
                    Text(
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
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: HermesTokens.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'http://host:port',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: HermesTokens.textMuted,
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.link_rounded,
                            size: 18,
                            color: HermesTokens.textMuted,
                          ),
                          suffixIcon: _urlCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
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
                    Text(
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
                        keyboardType: TextInputType.visiblePassword,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: HermesTokens.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Password or API key',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: HermesTokens.textMuted,
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          prefixIcon: Icon(
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
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: HermesTokens.textSecondary,
                                      ),
                                    )
                                  : Text(
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

              const SizedBox(height: 18),

              // 3. System Diagnostics & Audit Card
              _buildDiagnosticsSection(isConnected),

              const SizedBox(height: 20),

              // Footer Note
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: NeumorphicDecoration.recessed(radius: 16),
                  child: Row(
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

  Widget _buildDiagnosticsSection(bool isConnected) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: NeumorphicDecoration.raised(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SYSTEM DIAGNOSTICS & AUDIT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: HermesTokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Audit inference API keys, gateway state, and MCP health.',
                      style: TextStyle(
                        fontSize: 12,
                        color: HermesTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TactileContainer(
                onTap: (isConnected && !_runningDiagnostics)
                    ? _runDiagnostics
                    : null,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: NeumorphicDecoration.raised(
                    radius: 10,
                    distance: 2,
                    blur: 4,
                  ),
                  child: _runningDiagnostics
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: HermesTokens.accent,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.health_and_safety_outlined,
                              size: 15,
                              color: isConnected
                                  ? HermesTokens.accent
                                  : HermesTokens.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _diagnosticsResults == null ? 'Run Audit' : 'Re-run',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isConnected
                                    ? HermesTokens.textPrimary
                                    : HermesTokens.textMuted,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
          if (_diagnosticsResults != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _diagnosticsResults!.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final item = _diagnosticsResults![i];
                final IconData iconData;
                final Color statusColor;

                switch (item.severity) {
                  case HealthSeverity.healthy:
                    iconData = Icons.check_circle_outline_rounded;
                    statusColor = HermesTokens.success;
                    break;
                  case HealthSeverity.warning:
                    iconData = Icons.warning_amber_rounded;
                    statusColor = const Color(0xFFF59E0B);
                    break;
                  case HealthSeverity.error:
                    iconData = Icons.error_outline_rounded;
                    statusColor = HermesTokens.error;
                    break;
                }

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HermesTokens.bgPrimary,
                    borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
                    border: Border.all(color: HermesTokens.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(iconData, size: 18, color: statusColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: HermesTokens.textPrimary,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.severity.name.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: HermesTokens.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
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
      decoration: BoxDecoration(
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
                Expanded(
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
                        'Step-by-step remote setup via Tailscale Mesh VPN or Cloudflare Tunnel',
                        style: TextStyle(
                          fontSize: 11,
                          color: HermesTokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
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
                  _tabItem(0, 'Tailscale (VPN)'),
                  _tabItem(1, 'Cloudflare Tunnel'),
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
                  ? _buildTailscaleGuide()
                  : _activeTab == 1
                  ? _buildCloudflareGuide()
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
              ? NeumorphicDecoration.switcherThumb(radius: 10)
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

  Widget _buildTailscaleGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          title: 'Tailscale Mesh VPN (Recommended)',
          subtitle:
              'Direct encrypted peer-to-peer connection. Works anywhere over 4G/5G without port forwarding or public domain setup.',
          steps: const [
            _GuideStep(
              title: 'Install Tailscale on computer and mobile',
              details:
                  'Install Tailscale on both devices and sign in using the same account (Google, GitHub, etc.).',
            ),
            _GuideStep(
              title: 'Start Hermes daemon on your computer',
              details: 'Run Hermes dashboard in your host terminal:',
              code: 'hermes dashboard --port 9119',
            ),
            _GuideStep(
              title: 'Connect using the 100.x.y.z Tailscale IP',
              details:
                  'Copy your computer Tailscale IP address from the Tailscale app, and enter:',
              code: 'http://100.x.y.z:9119',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCloudflareGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          title: 'Cloudflare Quick Tunnel',
          subtitle:
              'Instant public HTTPS tunnel without port forwarding, domain purchase, or router firewall configuration.',
          steps: const [
            _GuideStep(
              title: 'Run Cloudflare tunnel on your computer',
              details:
                  'Run this single command in your host terminal. No account or domain required:',
              code: 'cloudflared tunnel --url http://localhost:9119',
            ),
            _GuideStep(
              title: 'Copy the assigned public HTTPS URL',
              details:
                  'Cloudflared outputs an assigned URL (e.g. https://xxxx.trycloudflare.com).',
              code: 'https://xxxx.trycloudflare.com',
            ),
            _GuideStep(
              title: 'Paste into Gateway URL',
              details:
                  'Enter this HTTPS URL into the Gateway URL field along with your Hermes password.',
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
          child: Column(
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: HermesTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: HermesTokens.textMuted,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: HermesTokens.divider),
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
            style: TextStyle(
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HermesTokens.textPrimary,
                ),
              ),
              if (step.details != null) ...[
                const SizedBox(height: 2),
                Text(
                  step.details!,
                  style: TextStyle(
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
                          style: TextStyle(
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
                        child: Padding(
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
