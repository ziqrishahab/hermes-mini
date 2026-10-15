import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../models/connection_config.dart";
import "../../providers/connection_provider.dart";
import "../../theme.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../widgets/fluid_pulse_indicator.dart";
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

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _cronNotify = true;
  bool _agentNotify = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
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
    } else if (config.mode == ConnectionMode.remote) {
      final uri = Uri.tryParse(config.apiUrl ?? '');
      final host = (uri != null && uri.host.isNotEmpty)
          ? uri.host
          : (config.apiUrl ?? 'Remote Gateway');
      daemonTitle = host;
      daemonSubtitle = "${config.apiUrl ?? ''} • Remote Gateway";
    } else {
      final host = config.sshHost ?? 'localhost';
      final port = config.remoteHermesPort ?? 8642;
      daemonTitle = "$host:$port";
      daemonSubtitle = "${config.sshUsername ?? 'user'}@$host • SSH Tunnel";
    }

    return Scaffold(
      backgroundColor: HermesTokens.bgPrimary,
      appBar: AppBar(
        backgroundColor: HermesTokens.bgPrimary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. AGENT PERSONA (Soul, Memory, User)
              _sectionLabel("AGENT PERSONA"),
              const SizedBox(height: 8),
              Container(
                decoration: NeumorphicDecoration.raised(radius: 18),
                child: Column(
                  children: [
                    _navRow(
                      title: "Soul Configuration",
                      subtitle: "Personality, tone & system directives (SOUL.md)",
                      enabled: isConnected,
                      onTap: () => context.push("/soul-editor"),
                    ),
                    const Divider(height: 1, color: HermesTokens.divider),
                    _navRow(
                      title: "Agent Memory",
                      subtitle: "Long-term persistent facts & notes (MEMORY.md)",
                      enabled: isConnected,
                      onTap: () => context.push("/memory-editor"),
                    ),
                    const Divider(height: 1, color: HermesTokens.divider),
                    _navRow(
                      title: "User Profile",
                      subtitle: "Operator context, identity & instructions (USER.md)",
                      enabled: isConnected,
                      onTap: () => context.push("/user-editor"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // 2. MODEL CONFIGURATION (LLM, Base URL, API Key)
              _sectionLabel("MODEL CONFIGURATION"),
              const SizedBox(height: 8),
              Container(
                decoration: NeumorphicDecoration.raised(radius: 18),
                child: _navRow(
                  title: "Model & Inference",
                  subtitle: "LLM provider, custom base URL & API keys",
                  enabled: isConnected,
                  onTap: () => context.push("/model-config"),
                ),
              ),
              const SizedBox(height: 22),

              // 3. CAPABILITIES & TOOLS (Skills, MCP, Plugins)
              _sectionLabel("CAPABILITIES"),
              const SizedBox(height: 8),
              Container(
                decoration: NeumorphicDecoration.raised(radius: 18),
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
                  child: const Padding(
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
                  child: const Padding(
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
              Container(
                decoration: NeumorphicDecoration.raised(radius: 18),
                child: _navRow(
                  title: daemonTitle,
                  subtitle: daemonSubtitle,
                  enabled: true,
                  onTap: () => context.push('/hermes-instance'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FluidPulseIndicator(
                        color: isConnected ? HermesTokens.success : HermesTokens.error,
                        size: 6,
                        animate: isConnected,
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: HermesTokens.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // PREFERENCES
              _sectionLabel("PREFERENCES"),
              const SizedBox(height: 8),
              Container(
                decoration: NeumorphicDecoration.raised(radius: 18),
                child: Column(
                  children: [
                    // Option 1: Scheduled Tasks (Cron)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      child: Row(
                        children: [
                          const Expanded(
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
                            inactiveTrackColor: const Color(0xFFCAD4E0),
                            trackOutlineColor: WidgetStateProperty.all(const Color(0x1F94A3B8)),
                            onChanged: _setCronNotify,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: HermesTokens.divider),
                    // Option 2: Agent Task Completion
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      child: Row(
                        children: [
                          const Expanded(
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
                            inactiveTrackColor: const Color(0xFFCAD4E0),
                            trackOutlineColor: WidgetStateProperty.all(const Color(0x1F94A3B8)),
                            onChanged: _setAgentNotify,
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
                child: Container(
                  decoration: NeumorphicDecoration.raised(radius: 14),
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
    );
  }

  Widget _buildVersionInfo() {
    final version = ref.watch(appVersionProvider);
    return Center(
      child: Text(
        "Hermes Mobile v$version",
        style: const TextStyle(fontSize: 11, color: HermesTokens.textMuted),
      ),
    );
  }


  void _showDisconnectDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFE0E5EC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          "Disconnect Session?",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
        ),
        content: const Text(
          "You will need to re-authenticate or re-enter Gateway URL to connect again.",
          style: TextStyle(fontSize: 13, color: HermesTokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: HermesTokens.textMuted)),
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
      if (mounted) context.go("/connect");
    }
  }

  Widget _sectionLabel(String t, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 2),
    child: Row(
      children: [
        Text(
          t,
          style: const TextStyle(
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

    return Container(
      decoration: NeumorphicDecoration.raised(radius: 18),
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
                ? const SizedBox(
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
                  cliCommand: "hermes plugins install kanban",
                  description: "Multi-agent task collaboration board with customizable columns and background execution.",
                );
              }
            },
          ),
          const Divider(height: 1, color: HermesTokens.divider),
          // 2. Achievements
          _navRow(
            title: "Achievements",
            subtitle: isAchievementsActive
                ? (achievementsPlugin['description']?.toString() ?? "Steam-style achievements & milestone badges")
                : "Not installed on Hermes host • Inactive",
            enabled: isAchievementsActive,
            trailing: isLoading
                ? const SizedBox(
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

    return Container(
      decoration: NeumorphicDecoration.raised(radius: 18),
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
          const Divider(height: 1, color: HermesTokens.divider),
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
          const Divider(height: 1, color: HermesTokens.divider),
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
    required String cliCommand,
    required String description,
  }) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFE0E5EC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: NeumorphicDecoration.recessed(radius: 10),
              child: const Icon(Icons.info_outline_rounded, color: HermesTokens.textSecondary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "$title Inactive",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "This plugin is not installed or currently disabled on your connected Hermes daemon.",
              style: TextStyle(fontSize: 13, color: HermesTokens.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(fontSize: 11, color: HermesTokens.textMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              "Install command for host:",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HermesTokens.textMuted),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: NeumorphicDecoration.recessed(radius: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      cliCommand,
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
                      Clipboard.setData(ClipboardData(text: cliCommand));
                      Navigator.pop(ctx);
                      HermesToast.show(
                        context,
                        message: "Command copied to clipboard",
                        type: HermesToastType.info,
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Got it", style: TextStyle(color: HermesTokens.textPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
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
}
