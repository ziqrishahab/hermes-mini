import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../providers/connection_provider.dart";
import "../../providers/theme_provider.dart";
import "../../services/accessibility_service.dart";
import "../../services/shell_executor_service.dart";
import "../../theme.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../widgets/hermes_toast.dart";
import "../widgets/tactile_feedback.dart";

// App version provider
final appVersionProvider = Provider<String>((ref) => '1.0.0');

// Discovered plugins from backend
final settingsPluginsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return [];
  try {
    return await conn.getPlugins();
  } catch (_) {
    return [];
  }
});

// User profile provider
final userProfileProvider = FutureProvider<String>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return '';
  try {
    return await conn.readUserProfile();
  } catch (_) {
    return '';
  }
});

// Parse username from profile
final userNameProvider = Provider<String>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.when(
    data: (profile) {
      if (profile.isEmpty) return 'Operator';
      final nameMatch = RegExp(r'^#\s*(.+)$', multiLine: true).firstMatch(profile);
      return nameMatch?.group(1)?.trim() ?? 'Operator';
    },
    loading: () => 'Loading...',
    error: (_, _) => 'Operator',
  );
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  bool _cronNotify = true;
  bool _agentNotify = true;
  bool _isAccessibilityActive = false;
  ShellPrivilegeStatus _shellStatus = const ShellPrivilegeStatus.inactive();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNotificationPreferences();
    _checkAccessibility();
    _checkShellStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccessibility();
      _checkShellStatus();
    }
  }

  Future<void> _checkAccessibility() async {
    final active = await AccessibilityService.isEnabled();
    if (!mounted) return;
    setState(() => _isAccessibilityActive = active);
  }

  Future<void> _checkShellStatus() async {
    final status = await ShellExecutorService.getStatus();
    if (!mounted) return;
    setState(() => _shellStatus = status);
  }

  Future<void> _loadNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _cronNotify = prefs.getBool('pref_cron_notify') ?? true;
        _agentNotify = prefs.getBool('pref_agent_notify') ?? true;
      });
    }
  }

  Future<void> _setCronNotify(bool value) async {
    setState(() => _cronNotify = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_cron_notify', value);
  }

  Future<void> _setAgentNotify(bool value) async {
    setState(() => _agentNotify = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_agent_notify', value);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(isDarkProvider);
    final currentThemeMode = ref.watch(themeModeProvider);
    final connState = ref.watch(connectionProvider);
    final isConnected = connState.valueOrNull != null;
    final config = ref.watch(connectionConfigProvider);

    final String daemonTitle;
    final String daemonSubtitle;

    if (!isConnected) {
      daemonTitle = "Hermes Instance";
      daemonSubtitle = (config == null)
          ? "Not configured • Tap to setup"
          : "Disconnected • Tap to setup";
    } else if (config == null) {
      daemonTitle = "Hermes Instance";
      daemonSubtitle = "Not connected";
    } else {
      final uri = Uri.tryParse(config.apiUrl ?? '');
      final host = (uri != null && uri.host.isNotEmpty)
          ? uri.host
          : (config.apiUrl ?? 'Remote Gateway');
      daemonTitle = host;
      daemonSubtitle = "${config.apiUrl ?? ''} • Remote Gateway";
    }

    final isDark = ref.watch(isDarkProvider);
    final bgColor = isDark ? HermesColors.dark.bgPrimary : HermesColors.light.bgPrimary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
      color: bgColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          title: Text(
            "Settings",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: HermesTokens.textPrimary,
            ),
          ),
        ),
      body: SafeArea(
        child: SingleChildScrollView(
          key: const PageStorageKey('settings_scroll_view'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. AGENTS & MODELS
              _sectionLabel("AGENTS & MODELS"),
              const SizedBox(height: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.fastOutSlowIn,
                decoration: NeumorphicDecoration.raised(radius: 18, isDark: isDark),
                child: _navRow(
                  title: "Agent Profiles & Models",
                  subtitle: "Manage personas, soul, memory, LLM providers & API keys",
                  enabled: isConnected,
                  onTap: () => context.push("/agent-profiles"),
                ),
              ),
              const SizedBox(height: 22),

              // 2. CAPABILITIES & TOOLS (Skills, MCP, Plugins)
              _sectionLabel("CAPABILITIES"),
              const SizedBox(height: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.fastOutSlowIn,
                decoration: NeumorphicDecoration.raised(radius: 18, isDark: isDark),
                child: _navRow(
                  title: "Capabilities & Tools",
                  subtitle: "Skills, MCP servers, and active extensions",
                  enabled: isConnected,
                  onTap: () => context.push("/capabilities"),
                ),
              ),
              const SizedBox(height: 22),

              // 4. PLUGINS (Kanban, Achievements - Dynamic from Backend)
              _sectionLabel(
                "PLUGINS",
                trailing: InkWell(
                  onTap: () {
                    ref.invalidate(settingsPluginsProvider);
                    HermesToast.show(
                      context,
                      message: "Rechecking plugins from Hermes...",
                      type: HermesToastType.info,
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 13, color: HermesTokens.textMuted),
                        SizedBox(width: 4),
                        Text("Refresh", style: TextStyle(fontSize: 10, color: HermesTokens.textMuted)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildPluginsSection(isConnected),
              const SizedBox(height: 22),

              // GATEWAYS & BRIDGES
              _sectionLabel(
                "GATEWAYS & BRIDGES",
                trailing: InkWell(
                  onTap: () => ref.invalidate(gatewaysProvider),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text("Refresh", style: TextStyle(fontSize: 10, color: HermesTokens.textMuted)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildGatewaysSection(isConnected),
              const SizedBox(height: 22),

              // 4. HERMES INSTANCE (Clean, Minimalist, Dynamic, Editable)
              _sectionLabel("HERMES INSTANCE"),
              const SizedBox(height: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.fastOutSlowIn,
                decoration: NeumorphicDecoration.raised(radius: 18, isDark: isDark),
                child: _navRow(
                  title: daemonTitle,
                  subtitle: daemonSubtitle,
                  enabled: true,
                  onTap: () => context.push('/hermes-instance'),
                  trailing: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: HermesTokens.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // PREFERENCES
              _sectionLabel("PREFERENCES"),
              const SizedBox(height: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.fastOutSlowIn,
                decoration: NeumorphicDecoration.raised(radius: 18, isDark: isDark),
                child: Column(
                  children: [
                    // Theme Mode Selector
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      child: _buildThemeSelector(
                        currentMode: currentThemeMode,
                        isDark: isDark,
                      ),
                    ),
                    Divider(height: 1, color: HermesTokens.divider),
                    // Option 1: Scheduled Tasks (Cron)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Scheduled Tasks (Cron)",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: HermesTokens.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Alerts when background scheduled jobs run or fail",
                                  style: TextStyle(fontSize: 11, color: HermesTokens.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _cronNotify,
                            activeThumbColor: Colors.white,
                            activeTrackColor: HermesTokens.accent,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFCAD4E0),
                            trackOutlineColor: WidgetStateProperty.all(isDark ? const Color(0x26FFFFFF) : const Color(0x1F94A3B8)),
                            onChanged: _setCronNotify,
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: HermesTokens.divider),
                    // Option 2: Agent Task Completion
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Agent Task Completion",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: HermesTokens.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Alerts when background agent workflows complete",
                                  style: TextStyle(fontSize: 11, color: HermesTokens.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _agentNotify,
                            activeThumbColor: Colors.white,
                            activeTrackColor: HermesTokens.accent,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFCAD4E0),
                            trackOutlineColor: WidgetStateProperty.all(isDark ? const Color(0x26FFFFFF) : const Color(0x1F94A3B8)),
                            onChanged: _setAgentNotify,
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: HermesTokens.divider),
                    // Device Automation (Accessibility Service)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Device Automation",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: HermesTokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isAccessibilityActive
                                      ? "Hermes Accessibility Service active"
                                      : "Enable service to permit autonomous mobile gestures",
                                  style: TextStyle(fontSize: 11, color: HermesTokens.textMuted),
                                ),
                              ],
                            ),
                          ),
                          TactileContainer(
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              await AccessibilityService.openSettings();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: NeumorphicDecoration.raised(
                                radius: 8,
                                distance: 1.5,
                                blur: 3,
                                isDark: isDark,
                              ),
                              child: Text(
                                _isAccessibilityActive ? "Settings" : "Enable",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _isAccessibilityActive ? HermesTokens.textSecondary : HermesTokens.accent,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: HermesTokens.divider),
                    // System Shell Bridge (Shizuku Next)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "System Shell Bridge",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: HermesTokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _shellStatus.authorized
                                      ? _shellStatus.modeLabel
                                      : (_shellStatus.running
                                          ? "Service running, tap Authorize to grant shell access"
                                          : "Connect Shizuku Next for ADB shell tasks"),
                                  style: TextStyle(fontSize: 11, color: HermesTokens.textMuted),
                                ),
                              ],
                            ),
                          ),
                          TactileContainer(
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              if (_shellStatus.running && !_shellStatus.authorized) {
                                final perm = await ShellExecutorService.requestPermission();
                                await _checkShellStatus();
                                if (!context.mounted) return;
                                HermesToast.show(
                                  context,
                                  message: perm.message,
                                  type: perm.granted ? HermesToastType.success : HermesToastType.error,
                                );
                              } else {
                                _showShellBridgeDialog();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: NeumorphicDecoration.raised(
                                radius: 8,
                                distance: 1.5,
                                blur: 3,
                                isDark: isDark,
                              ),
                              child: Text(
                                _shellStatus.authorized
                                    ? "Details"
                                    : (_shellStatus.running ? "Authorize" : "Setup"),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _shellStatus.authorized
                                      ? HermesTokens.textSecondary
                                      : HermesTokens.accent,
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
              const SizedBox(height: 22),

              // DISCONNECT SESSION
              TactileContainer(
                onTap: _showDisconnectDialog,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.fastOutSlowIn,
                  decoration: NeumorphicDecoration.raised(radius: 14, isDark: isDark),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    child: Center(
                      child: Text(
                        "Disconnect Session",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: HermesTokens.error,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _buildVersionInfo(),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildVersionInfo() {
    final version = ref.watch(appVersionProvider);
    return Center(
      child: Text(
        "Hermes Mobile v$version",
        style: TextStyle(fontSize: 11, color: HermesTokens.textMuted),
      ),
    );
  }


  void _showDisconnectDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HermesTokens.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          "Disconnect Session?",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
        ),
        content: Text(
          "You will need to re-authenticate or re-enter Gateway URL to connect again.",
          style: TextStyle(fontSize: 13, color: HermesTokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: TextStyle(color: HermesTokens.textMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: HermesTokens.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Disconnect"),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(connectionProvider.notifier).disconnect();
      ref.read(isOfflineModeProvider.notifier).state = true;
      if (mounted) context.push("/hermes-instance");
    }
  }

  Future<void> _showShellBridgeDialog() async {
    await _checkShellStatus();
    if (!mounted) return;
    final status = _shellStatus;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HermesTokens.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          "System Shell Bridge",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: HermesTokens.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Status: ${status.modeLabel}",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: status.authorized ? HermesTokens.accent : HermesTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Allows your remote Hermes daemon to run approved Android shell commands on this device:",
              style: TextStyle(fontSize: 12, color: HermesTokens.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              "1. Shizuku Next: Enable Wireless Debugging in Developer Options, pair once, and start the service.\n"
              "2. After a reboot, start the Shizuku Next service again (not needed on rooted devices).\n"
              "3. Every shell command requested by Hermes requires manual confirmation before running.",
              style: TextStyle(fontSize: 11.5, height: 1.45, color: HermesTokens.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Close", style: TextStyle(color: HermesTokens.textMuted)),
          ),
          if (status.running && !status.authorized)
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final perm = await ShellExecutorService.requestPermission();
                await _checkShellStatus();
                if (!mounted) return;
                HermesToast.show(
                  context,
                  message: perm.message,
                  type: perm.granted ? HermesToastType.success : HermesToastType.error,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: HermesTokens.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Authorize"),
            )
          else if (status.installedBackend != 'none')
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ShellExecutorService.openManagerApp();
              },
              style: FilledButton.styleFrom(
                backgroundColor: HermesTokens.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Open Manager"),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String t, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 2),
    child: Row(
      children: [
        Text(
          t,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: HermesTokens.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ],
      ],
    ),
  );

  Widget _buildPluginsSection(bool isConnected) {
    final pluginsAsync = ref.watch(settingsPluginsProvider);
    final plugins = pluginsAsync.valueOrNull ?? [];
    final isLoading = pluginsAsync.isLoading;

    final kanbanPlugin = plugins.cast<Map<String, dynamic>?>().firstWhere(
      (p) => p != null && (
        p['name']?.toString().toLowerCase() == 'kanban' ||
        p['label']?.toString().toLowerCase() == 'kanban'
      ),
      orElse: () => null,
    );
    final bool isKanbanActive = isConnected && kanbanPlugin != null;

    final achievementsPlugin = plugins.cast<Map<String, dynamic>?>().firstWhere(
      (p) => p != null && (
        p['name']?.toString().toLowerCase() == 'hermes-achievements' ||
        p['name']?.toString().toLowerCase() == 'achievements' ||
        p['label']?.toString().toLowerCase() == 'achievements'
      ),
      orElse: () => null,
    );
    final bool isAchievementsActive = isConnected && achievementsPlugin != null;

    final isDark = ref.watch(isDarkProvider);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
      decoration: NeumorphicDecoration.raised(radius: 18, isDark: isDark),
      child: Column(
        children: [
          // 1. Kanban
          _navRow(
            title: "Kanban",
            subtitle: isKanbanActive
                ? (kanbanPlugin['description']?.toString() ?? "Multi-agent collaboration board")
                : "Not installed on Hermes host • Inactive",
            enabled: isKanbanActive,
            trailing: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: HermesTokens.accent),
                  )
                : null,
            onTap: () {
              if (isKanbanActive) {
                context.push('/kanban');
              } else {
                _showInactivePluginDialog(
                  title: "Kanban",
                  pluginCatalogName: "kanban",
                  cliCommand: "hermes plugins install kanban",
                  description: "Multi-agent task collaboration board with customizable columns and background execution.",
                );
              }
            },
          ),
          Divider(height: 1, color: HermesTokens.divider),
          // 2. Achievements
          _navRow(
            title: "Achievements",
            subtitle: isAchievementsActive
                ? (achievementsPlugin['description']?.toString() ?? "Steam-style achievements & milestone badges")
                : "Not installed on Hermes host • Inactive",
            enabled: isAchievementsActive,
            trailing: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: HermesTokens.accent),
                  )
                : null,
            onTap: () {
              if (isAchievementsActive) {
                context.push('/achievements');
              } else {
                _showInactivePluginDialog(
                  title: "Achievements",
                  pluginCatalogName: "hermes-achievements",
                  cliCommand: "hermes plugins install hermes-achievements",
                  description: "Steam-style achievements, session milestones, and badges for agentic Hermes workflows.",
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGatewaysSection(bool isConnected) {
    final gatewaysAsync = ref.watch(gatewaysProvider);
    final platforms = gatewaysAsync.valueOrNull ?? [];

    Map<String, dynamic> getPlatform(String id) {
      return platforms.firstWhere(
        (e) => e['id']?.toString().toLowerCase() == id.toLowerCase(),
        orElse: () => <String, dynamic>{'id': id},
      );
    }

    final telegramData = getPlatform('telegram');
    final discordData = getPlatform('discord');
    final whatsappData = getPlatform('whatsapp');

    final bool telegramActive = telegramData['enabled'] == true;
    final bool discordActive = discordData['enabled'] == true;
    final bool whatsappActive = whatsappData['enabled'] == true;

    final bool telegramConfigured = telegramData['configured'] == true;
    final bool discordConfigured = discordData['configured'] == true;
    final bool whatsappConfigured = whatsappData['configured'] == true;

    final isDark = ref.watch(isDarkProvider);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
      decoration: NeumorphicDecoration.raised(radius: 18, isDark: isDark),
      child: Column(
        children: [
          // 1. Telegram
          _navRow(
            title: "Telegram Bot",
            subtitle: telegramActive
                ? "Active • Hermes chat bot & notifications"
                : (telegramConfigured
                    ? "Disabled • Configured"
                    : "Not configured • Tap to setup"),
            enabled: isConnected,
            onTap: () => context.push('/gateway/telegram', extra: telegramData),
          ),
          Divider(height: 1, color: HermesTokens.divider),
          // 2. Discord
          _navRow(
            title: "Discord Bot",
            subtitle: discordActive
                ? "Active • Hermes agent in Discord"
                : (discordConfigured
                    ? "Disabled • Configured"
                    : "Not configured • Tap to setup"),
            enabled: isConnected,
            onTap: () => context.push('/gateway/discord', extra: discordData),
          ),
          Divider(height: 1, color: HermesTokens.divider),
          // 3. WhatsApp
          _navRow(
            title: "WhatsApp Bridge",
            subtitle: whatsappActive
                ? "Active • Messaging assistant bridge"
                : (whatsappConfigured
                    ? "Disabled • Configured"
                    : "Not configured • Tap to setup"),
            enabled: isConnected,
            onTap: () => context.push('/gateway/whatsapp', extra: whatsappData),
          ),
        ],
      ),
    );
  }

  void _showInactivePluginDialog({
    required String title,
    required String pluginCatalogName,
    required String cliCommand,
    required String description,
  }) {
    bool isInstalling = false;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: HermesTokens.bgElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: NeumorphicDecoration.recessed(radius: 10),
                child: Icon(Icons.extension_outlined, color: HermesTokens.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "$title Inactive",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "This plugin is not yet installed on your connected Hermes host.",
                style: TextStyle(fontSize: 13, color: HermesTokens.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: TextStyle(fontSize: 11, color: HermesTokens.textMuted),
              ),
              const SizedBox(height: 14),
              Text(
                "Manual CLI Command:",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HermesTokens.textMuted),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: NeumorphicDecoration.recessed(radius: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        cliCommand,
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
                        Clipboard.setData(ClipboardData(text: cliCommand));
                        HermesToast.show(
                          context,
                          message: "Command copied to clipboard",
                          type: HermesToastType.info,
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.copy_rounded, size: 16, color: HermesTokens.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isInstalling ? null : () => Navigator.pop(ctx),
              child: Text("Cancel", style: TextStyle(color: HermesTokens.textMuted)),
            ),
            FilledButton(
              onPressed: isInstalling
                  ? null
                  : () async {
                      setDialogState(() => isInstalling = true);
                      final conn = ref.read(connectionProvider).valueOrNull;
                      final ok = await conn?.installPlugin(pluginCatalogName) ?? false;
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        if (ok) {
                          ref.invalidate(settingsPluginsProvider);
                          HermesToast.show(
                            context,
                            message: "$title installed successfully on host",
                            type: HermesToastType.success,
                          );
                        } else {
                          HermesToast.show(
                            context,
                            message: "Failed to install $title: ${conn?.lastPluginError ?? 'Host rejected installation'}",
                            type: HermesToastType.error,
                          );
                        }
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: HermesTokens.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isInstalling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text("1-Tap Remote Install"),
            ),
          ],
        ),
      ),
    );
  }


  Widget _navRow({
    IconData? icon,
    required String title,
    String? subtitle,
    String? value,
    Widget? trailing,
    Color? iconColor,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return TactileContainer(
      onTap: enabled ? onTap : null,
      pressedScale: 0.985,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.38,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: enabled ? (iconColor ?? HermesTokens.textSecondary) : HermesTokens.textMuted,
                  size: 18,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: enabled ? HermesTokens.textPrimary : HermesTokens.textMuted,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: enabled ? HermesTokens.textMuted : HermesTokens.textMuted.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled ? HermesTokens.textSecondary : HermesTokens.textMuted,
                    ),
                  ),
                ),
              trailing ??
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: enabled ? HermesTokens.textMuted : HermesTokens.textMuted.withValues(alpha: 0.3),
                  ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildThemeSelector({
    required ThemeMode currentMode,
    required bool isDark,
  }) {
    final int selectedIndex = switch (currentMode) {
      ThemeMode.system => 0,
      ThemeMode.light => 1,
      ThemeMode.dark => 2,
    };

    final items = const [
      (label: "System", icon: Icons.brightness_auto_rounded, mode: ThemeMode.system),
      (label: "Light", icon: Icons.light_mode_rounded, mode: ThemeMode.light),
      (label: "Dark", icon: Icons.dark_mode_rounded, mode: ThemeMode.dark),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Theme Mode",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: HermesTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "Select app appearance theme",
          style: TextStyle(fontSize: 11, color: HermesTokens.textMuted),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const trackPadding = 4.0;
            final innerWidth = constraints.maxWidth - (trackPadding * 2);
            final segmentWidth = innerWidth / items.length;
            const height = 40.0;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.fastOutSlowIn,
              height: height,
              decoration: NeumorphicDecoration.recessed(
                radius: 12,
                isDark: isDark,
              ),
              padding: const EdgeInsets.all(trackPadding),
              child: Stack(
                children: [
                  // Smoothly sliding indicator pill
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.fastOutSlowIn,
                    left: selectedIndex * segmentWidth,
                    top: 0,
                    bottom: 0,
                    width: segmentWidth,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.fastOutSlowIn,
                      decoration: NeumorphicDecoration.switcherThumb(
                        radius: 8,
                        isDark: isDark,
                      ),
                    ),
                  ),
                  // Segment labels & tap targets
                  Row(
                    children: List.generate(items.length, (index) {
                      final item = items[index];
                      final isSelected = selectedIndex == index;

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (currentMode != item.mode) {
                              HapticFeedback.selectionClick();
                              ref.read(themeModeProvider.notifier).setThemeMode(item.mode);
                            }
                          },
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TweenAnimationBuilder<Color?>(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.fastOutSlowIn,
                                  tween: ColorTween(
                                    end: isSelected ? HermesTokens.accent : HermesTokens.textMuted,
                                  ),
                                  builder: (context, color, _) => Icon(
                                    item.icon,
                                    size: 14,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.fastOutSlowIn,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected
                                        ? HermesTokens.textPrimary
                                        : HermesTokens.textMuted,
                                    letterSpacing: -0.2,
                                  ),
                                  child: Text(item.label),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}