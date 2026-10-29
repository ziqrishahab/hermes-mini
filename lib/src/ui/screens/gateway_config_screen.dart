import "package:flutter/material.dart";
import "dart:convert";
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
  Map<String, dynamic>? _whatsappStatus;
  bool _loadingWhatsAppStatus = false;

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

    if (widget.platformId.toLowerCase() == 'whatsapp') {
      _fetchWhatsAppStatus();
    }

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

  Future<void> _fetchWhatsAppStatus() async {
    setState(() => _loadingWhatsAppStatus = true);
    try {
      final conn = ref.read(connectionProvider).valueOrNull;
      if (conn != null) {
        final st = await conn.getWhatsAppBridgeStatus();
        if (mounted) {
          setState(() {
            _whatsappStatus = st;
            _loadingWhatsAppStatus = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingWhatsAppStatus = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingWhatsAppStatus = false);
    }
  }

  Widget _buildWhatsAppQrSection() {
    final status = _whatsappStatus;
    final isPaired = status != null &&
        (status['authenticated'] == true ||
            status['connected'] == true ||
            status['status'] == 'authenticated' ||
            status['status'] == 'connected');
    final rawQr = status?['qr'] ?? status?['qr_code'];
    String? qrBase64;
    if (rawQr is String && rawQr.isNotEmpty) {
      if (rawQr.startsWith('data:image')) {
        final commaIndex = rawQr.indexOf(',');
        if (commaIndex != -1) {
          qrBase64 = rawQr.substring(commaIndex + 1);
        }
      } else {
        qrBase64 = rawQr;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        _sectionLabel("WHATSAPP BRIDGE STATUS & PAIRING"),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: NeumorphicDecoration.raised(radius: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPaired ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isPaired
                          ? "Connected and Authenticated"
                          : (_loadingWhatsAppStatus
                              ? "Checking WhatsApp status..."
                              : "Not Paired / Waiting for QR Scan"),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isPaired ? const Color(0xFF10B981) : HermesTokens.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: _loadingWhatsAppStatus
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.refresh_rounded, size: 20, color: HermesTokens.accent),
                    tooltip: "Refresh WhatsApp Status",
                    onPressed: _loadingWhatsAppStatus ? null : _fetchWhatsAppStatus,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isPaired
                    ? "Your WhatsApp bridge daemon is linked and ready to route messages to and from Hermes."
                    : "Scan the QR code below using WhatsApp on your phone (Linked Devices) to pair.",
                style: TextStyle(fontSize: 12, color: HermesTokens.textMuted, height: 1.4),
              ),
              if (qrBase64 != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(qrBase64),
                        width: 180,
                        height: 180,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 180,
                          height: 180,
                          alignment: Alignment.center,
                          child: Text(
                            "Invalid QR data",
                            style: TextStyle(fontSize: 11, color: HermesTokens.textMuted),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    "Scan with WhatsApp > Linked Devices",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: HermesTokens.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
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
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: HermesTokens.textPrimary, size: 16),
                onPressed: () => context.pop(),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        title: Text(
          _platformName,
          style: TextStyle(
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
              // Hero Status Card (Clean, minimalist typography without AI-slop icon tile)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: NeumorphicDecoration.raised(radius: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _platformName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: HermesTokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _platformSubtitle,
                            style: TextStyle(fontSize: 12, color: HermesTokens.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
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
                          Text(
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
                            style: TextStyle(fontSize: 11, color: HermesTokens.textMuted),
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

              if (widget.platformId.toLowerCase() == 'whatsapp')
                _buildWhatsAppQrSection(),

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
                        Icon(Icons.info_outline_rounded, size: 16, color: HermesTokens.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "How to configure $_platformName",
                            style: TextStyle(
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
                      style: TextStyle(
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
          style: TextStyle(
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

    String hintText = prompt;
    TextInputType keyboardType = TextInputType.text;
    final lowerKey = key.toLowerCase();
    final lowerPrompt = prompt.toLowerCase();
    if (lowerKey.contains('port') ||
        lowerKey.contains('phone') ||
        lowerKey.contains('number') ||
        lowerKey.contains('timeout') ||
        lowerPrompt.contains('port') ||
        lowerPrompt.contains('number')) {
      keyboardType = TextInputType.number;
    } else if (isPassword) {
      keyboardType = TextInputType.visiblePassword;
    } else if (lowerKey.contains('url') ||
        lowerKey.contains('webhook') ||
        lowerKey.contains('endpoint') ||
        lowerPrompt.contains('url')) {
      keyboardType = TextInputType.url;
    } else if (lowerKey.contains('email') || lowerPrompt.contains('email')) {
      keyboardType = TextInputType.emailAddress;
    }
    if (isSet) {
      hintText = redacted != null ? "Set: $redacted" : "Configured";
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
              style: TextStyle(
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
                  style: TextStyle(
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
            style: TextStyle(fontSize: 11, color: HermesTokens.textMuted),
          ),
        ],
        const SizedBox(height: 8),
        Container(
          decoration: NeumorphicDecoration.recessed(radius: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: HermesTokens.textPrimary,
            ),
            decoration: InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: hintText,
              hintStyle: TextStyle(fontSize: 12, color: HermesTokens.textMuted),
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
                          icon: Icon(Icons.clear_rounded, size: 16, color: HermesTokens.textMuted),
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
