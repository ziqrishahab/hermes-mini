import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../providers/connection_provider.dart";
import "../../theme.dart";

class GatewayConfigScreen extends ConsumerStatefulWidget {
  final String platformId;
  final Map<String, dynamic>? initialData;

  const GatewayConfigScreen({
    super.key,
    required this.platformId,
    this.initialData,
  });

  @override
  ConsumerState<GatewayConfigScreen> createState() => _GatewayConfigScreenState();
}

class _GatewayConfigScreenState extends ConsumerState<GatewayConfigScreen> {
  late bool _enabled;
  bool _saving = false;
  String? _errorMessage;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _obscureText = {};
  late List<Map<String, dynamic>> _fields;

  String get _platformName {
    switch (widget.platformId.toLowerCase()) {
      case "telegram":
        return "Telegram Bot";
      case "discord":
        return "Discord Bot";
      case "whatsapp":
        return "WhatsApp Bridge";
      default:
        return "${widget.platformId[0].toUpperCase()}${widget.platformId.substring(1)} Gateway";
    }
  }

  IconData get _platformIcon {
    switch (widget.platformId.toLowerCase()) {
      case "telegram":
        return Icons.send_rounded;
      case "discord":
        return Icons.forum_rounded;
      case "whatsapp":
        return Icons.chat_bubble_outline_rounded;
      default:
        return Icons.cell_tower_rounded;
    }
  }

  String get _platformSubtitle {
    switch (widget.platformId.toLowerCase()) {
      case "telegram":
        return "Hermes chat bot and instant alerts bridge";
      case "discord":
        return "Hermes agent in Discord servers and channels";
      case "whatsapp":
        return "Messaging assistant bridge for WhatsApp";
      default:
        return "Messaging gateway connection";
    }
  }

  String get _setupGuide {
    switch (widget.platformId.toLowerCase()) {
      case "telegram":
        return "1. Open Telegram and search for @BotFather.\n"
            "2. Send /newbot and choose a name for your bot.\n"
            "3. Copy the HTTP API token into TELEGRAM_BOT_TOKEN below.\n"
            "4. (Optional) Enter your numeric Telegram User ID in TELEGRAM_ALLOWED_USERS to restrict access.";
      case "discord":
        return "1. Visit the Discord Developer Portal (discord.com/developers).\n"
            "2. Create a new Application and add a Bot in the Bot section.\n"
            "3. Enable 'Message Content Intent' under Privileged Gateway Intents.\n"
            "4. Reset and copy the Bot Token into DISCORD_BOT_TOKEN below.\n"
            "5. Invite the bot to your Discord server.";
      case "whatsapp":
        return "1. Ensure the WhatsApp bridge daemon is running on your host.\n"
            "2. Enter allowed phone numbers in international format (e.g. 6281234567890).\n"
            "3. Hermes will only process commands from authorized numbers.";
      default:
        return "Configure your messaging gateway credentials and permissions below.";
    }
  }

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialData?['enabled'] == true;

    final rawVars = widget.initialData?['env_vars'];
    if (rawVars is List && rawVars.isNotEmpty) {
      _fields = rawVars
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['key'] != null && e['advanced'] != true)
          .toList();
    } else {
      if (widget.platformId == 'telegram') {
        _fields = [
          {
            'key': 'TELEGRAM_BOT_TOKEN',
            'prompt': 'Telegram Bot Token',
            'description': 'Token created with @BotFather',
            'is_password': true,
            'required': true,
          },
          {
            'key': 'TELEGRAM_ALLOWED_USERS',
            'prompt': 'Allowed User IDs',
            'description': 'Comma-separated numeric user IDs (optional)',
            'is_password': false,
            'required': false,
          },
        ];
      } else if (widget.platformId == 'discord') {
        _fields = [
          {
            'key': 'DISCORD_BOT_TOKEN',
            'prompt': 'Discord Bot Token',
            'description': 'Bot token from Discord Developer Portal',
            'is_password': true,
            'required': true,
          },
          {
            'key': 'DISCORD_ALLOWED_USERS',
            'prompt': 'Allowed Users / Channels',
            'description': 'Comma-separated Discord IDs (optional)',
            'is_password': false,
            'required': false,
          },
        ];
      } else if (widget.platformId == 'whatsapp') {
        _fields = [
          {
            'key': 'WHATSAPP_ALLOWED_USERS',
            'prompt': 'Allowed Phone Numbers',
            'description': 'Comma-separated phone numbers with country code',
            'is_password': false,
            'required': false,
          },
        ];
      } else {
        _fields = [];
      }
    }

    for (final field in _fields) {
      final key = field['key'] as String;
      final val = field['value']?.toString() ?? '';
      _controllers[key] = TextEditingController(text: val);
      if (field['is_password'] == true) {
        _obscureText[key] = true;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final envUpdates = <String, String>{};
    for (final entry in _controllers.entries) {
      final text = entry.value.text.trim();
      if (text.isNotEmpty) {
        envUpdates[entry.key] = text;
      }
    }

    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) {
      setState(() {
        _saving = false;
        _errorMessage = "Not connected to Hermes host";
      });
      return;
    }

    try {
      final ok = await conn.updateMessagingPlatform(
        widget.platformId,
        enabled: _enabled,
        env: envUpdates.isNotEmpty ? envUpdates : null,
      );

      if (!mounted) return;

      if (ok) {
        ref.invalidate(gatewaysProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$_platformName configuration saved successfully"),
            backgroundColor: HermesTokens.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      } else {
        setState(() {
          _saving = false;
          _errorMessage = "Failed to update gateway configuration on Hermes host.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HermesTokens.bgPrimary,
      appBar: AppBar(
        backgroundColor: HermesTokens.bgPrimary,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 54,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: NeumorphicDecoration.raised(radius: 12, distance: 2.5, blur: 5),
              child: IconButton(
                tooltip: "Back",
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: HermesTokens.textPrimary, size: 16),
                onPressed: () => context.pop(),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        title: Text(
          _platformName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: HermesTokens.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Status Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: NeumorphicDecoration.raised(radius: 18),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: NeumorphicDecoration.recessed(radius: 14),
                      child: Icon(_platformIcon, color: HermesTokens.accent, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _platformName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: HermesTokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _platformSubtitle,
                            style: const TextStyle(fontSize: 12, color: HermesTokens.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: NeumorphicDecoration.recessed(radius: 10),
                      child: Text(
                        _enabled ? "Active" : "Disabled",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _enabled ? HermesTokens.accent : HermesTokens.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Master Switch Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: NeumorphicDecoration.raised(radius: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Enable Gateway Bridge",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: HermesTokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _enabled
                                ? "Daemon will listen and respond on $_platformName"
                                : "Messaging bridge is currently inactive",
                            style: const TextStyle(fontSize: 11, color: HermesTokens.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _enabled,
                      activeThumbColor: Colors.white,
                      activeTrackColor: HermesTokens.accent,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFCAD4E0),
                      trackOutlineColor: WidgetStateProperty.all(const Color(0x1F94A3B8)),
                      onChanged: (val) => setState(() => _enabled = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Configuration Fields Section
              _sectionLabel("CREDENTIALS & ACCESS CONTROL"),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: NeumorphicDecoration.raised(radius: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < _fields.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      _buildFieldItem(_fields[i]),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Quick Setup Guide Card
              _sectionLabel("SETUP INSTRUCTIONS"),
              const SizedBox(height: 8),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: NeumorphicDecoration.recessed(radius: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: HermesTokens.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "How to configure $_platformName",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: HermesTokens.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _setupGuide,
                      style: const TextStyle(
                        fontSize: 11,
                        color: HermesTokens.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HermesTokens.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 11, color: HermesTokens.error),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: InkWell(
                  onTap: _saving ? null : _save,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: NeumorphicDecoration.raised(
                      radius: 14,
                      color: HermesTokens.accent,
                      distance: 3,
                      blur: 6,
                    ),
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              "Save Configuration",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
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

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 2),
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: HermesTokens.textMuted,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _buildFieldItem(Map<String, dynamic> field) {
    final key = field['key'] as String;
    final prompt = field['prompt']?.toString() ?? key;
    final description = field['description']?.toString() ?? '';
    final isPassword = field['is_password'] == true;
    final isSet = field['is_set'] == true;
    final redacted = field['redacted_value']?.toString();
    final controller = _controllers[key]!;
    final obscure = _obscureText[key] ?? false;

    String hintText = "Enter $prompt";
    if (isSet) {
      hintText = redacted != null ? "Set: $redacted" : "Configured (leave blank to keep)";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              prompt,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: HermesTokens.textPrimary,
              ),
            ),
            if (key.isNotEmpty && key != prompt)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: NeumorphicDecoration.recessed(radius: 6),
                child: Text(
                  key,
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 9,
                    color: HermesTokens.textMuted,
                  ),
                ),
              ),
          ],
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            description,
            style: const TextStyle(fontSize: 11, color: HermesTokens.textMuted),
          ),
        ],
        const SizedBox(height: 8),
        Container(
          decoration: NeumorphicDecoration.recessed(radius: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: HermesTokens.textPrimary,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: const TextStyle(fontSize: 12, color: HermesTokens.textMuted),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                        color: HermesTokens.textMuted,
                      ),
                      onPressed: () => setState(() => _obscureText[key] = !obscure),
                    )
                  : (controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16, color: HermesTokens.textMuted),
                          onPressed: () => setState(() => controller.clear()),
                        )
                      : null),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}
