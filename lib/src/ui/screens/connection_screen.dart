import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import '../../models/connection_config.dart';
import '../../providers/connection_provider.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  ConnectionMode _mode = ConnectionMode.remote;

  final _apiUrlCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _sshHostCtrl = TextEditingController();
  final _sshPortCtrl = TextEditingController(text: '22');
  final _sshUserCtrl = TextEditingController();
  final _remotePortCtrl = TextEditingController(text: '8642');
  final _privateKeyCtrl = TextEditingController();

  final _apiUrlFocus = FocusNode();
  final _apiKeyFocus = FocusNode();
  final _sshHostFocus = FocusNode();
  final _sshPortFocus = FocusNode();
  final _sshUserFocus = FocusNode();
  final _remotePortFocus = FocusNode();

  String? _privateKeyPath;
  bool _testing = false;
  String? _focusedField;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(connectionConfigProvider);
    if (saved != null) _fillFromConfig(saved);

    for (final fn in [
      _apiUrlFocus,
      _apiKeyFocus,
      _sshHostFocus,
      _sshPortFocus,
      _sshUserFocus,
      _remotePortFocus,
    ]) {
      fn.addListener(_onFocusChange);
    }
  }

  void _onFocusChange() {
    setState(() {
      if (_apiUrlFocus.hasFocus) {
        _focusedField = 'apiUrl';
      } else if (_apiKeyFocus.hasFocus) {
        _focusedField = 'apiKey';
      } else if (_sshHostFocus.hasFocus) {
        _focusedField = 'sshHost';
      } else if (_sshPortFocus.hasFocus || _remotePortFocus.hasFocus) {
        _focusedField = 'ports';
      } else if (_sshUserFocus.hasFocus) {
        _focusedField = 'sshUser';
      } else {
        _focusedField = null;
      }
    });
  }

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _sshHostCtrl.dispose();
    _sshPortCtrl.dispose();
    _sshUserCtrl.dispose();
    _remotePortCtrl.dispose();
    _privateKeyCtrl.dispose();
    _apiUrlFocus.dispose();
    _apiKeyFocus.dispose();
    _sshHostFocus.dispose();
    _sshPortFocus.dispose();
    _sshUserFocus.dispose();
    _remotePortFocus.dispose();
    super.dispose();
  }

  void _fillFromConfig(ConnectionConfig c) {
    _mode = c.mode;
    _apiUrlCtrl.text = c.apiUrl ?? '';
    _apiKeyCtrl.text = c.apiKey ?? '';
    _sshHostCtrl.text = c.sshHost ?? '';
    _sshPortCtrl.text = c.sshPort?.toString() ?? '22';
    _sshUserCtrl.text = c.sshUsername ?? '';
    _remotePortCtrl.text = c.remoteHermesPort?.toString() ?? '8642';
    _privateKeyPath = c.privateKeyPath;
    _privateKeyCtrl.text = c.privateKeyPath != null
        ? path.basename(c.privateKeyPath!)
        : '';
  }

  Future<void> _pickKey() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final picked = result.files.single.path!;
      setState(() {
        _privateKeyPath = picked;
        _privateKeyCtrl.text = path.basename(picked);
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    final config = _buildConfig();
    final ok = await ref
        .read(connectionProvider.notifier)
        .testAndConnect(config);
    setState(() => _testing = false);
    if (ok && mounted) {
      context.go('/home');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection failed. Check your settings.'),
        ),
      );
    }
  }

  ConnectionConfig _buildConfig() {
    return ConnectionConfig(
      mode: _mode,
      apiUrl: _apiUrlCtrl.text.trim(),
      apiKey: _apiKeyCtrl.text.trim(),
      sshHost: _sshHostCtrl.text.trim(),
      sshPort: int.tryParse(_sshPortCtrl.text),
      sshUsername: _sshUserCtrl.text.trim(),
      privateKeyPath: _privateKeyPath,
      remoteHermesPort: int.tryParse(_remotePortCtrl.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const lavender = Color(0xFFC7B8EA);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [lavender, Color(0xFFEADD95)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: lavender.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.bolt,
                        size: 32,
                        color: Color(0xFF121212),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Hermes',
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connect to your agent',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              _buildModeToggle(),
              const SizedBox(height: 20),

              Text(
                _mode == ConnectionMode.remote ? 'Remote API' : 'SSH Tunnel',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _mode == ConnectionMode.remote
                    ? 'Connect directly to a public Hermes API endpoint.'
                    : 'Forward a remote Hermes instance through an SSH tunnel.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  key: ValueKey(_mode),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF242424),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _mode == ConnectionMode.remote
                        ? _remoteFields
                        : _sshFields,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: lavender.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  style: FilledButton.styleFrom(
                    backgroundColor: lavender,
                    foregroundColor: const Color(0xFF121212),
                    disabledBackgroundColor: lavender.withValues(alpha: 0.5),
                    disabledForegroundColor: const Color(
                      0xFF121212,
                    ).withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: const Size(double.infinity, 0),
                  ),
                  icon: _testing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.link),
                  label: Text(
                    _testing ? 'Connecting...' : 'Test & Connect',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: Text(
                  'Your credentials are stored securely on this device.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    final colorScheme = Theme.of(context).colorScheme;
    const lavender = Color(0xFFC7B8EA);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _mode = ConnectionMode.remote),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _mode == ConnectionMode.remote
                      ? lavender
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(
                    'Remote',
                    style: TextStyle(
                      color: _mode == ConnectionMode.remote
                          ? const Color(0xFF121212)
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _mode = ConnectionMode.sshTunnel),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _mode == ConnectionMode.sshTunnel
                      ? lavender
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(
                    'SSH Tunnel',
                    style: TextStyle(
                      color: _mode == ConnectionMode.sshTunnel
                          ? const Color(0xFF121212)
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool readOnly = false,
    VoidCallback? onTap,
    IconData? icon,
    String? focusId,
    FocusNode? focusNode,
  }) {
    final isFocused = _focusedField == focusId;
    final iconColor = isFocused
        ? const Color(0xFFC7B8EA)
        : const Color(0xFF948F99);

    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      obscureText: obscureText,
      keyboardType: keyboardType,
      focusNode: focusNode,
      style: const TextStyle(color: Color(0xFFE5E2E1)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: iconColor)
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  List<Widget> get _remoteFields => [
    _gridField(
      controller: _apiUrlCtrl,
      label: 'Hermes API URL',
      hint: 'https://your-server:8642',
      keyboardType: TextInputType.url,
      focusId: 'apiUrl',
      focusNode: _apiUrlFocus,
    ),
    const SizedBox(height: 12),
    _gridField(
      controller: _apiKeyCtrl,
      label: 'API Key',
      obscureText: true,
      focusId: 'apiKey',
      focusNode: _apiKeyFocus,
    ),
  ];

  List<Widget> get _sshFields => [
    _gridField(
      controller: _sshHostCtrl,
      label: 'SSH Host',
      hint: 'your-vps.com',
      keyboardType: TextInputType.url,
      focusId: 'sshHost',
      focusNode: _sshHostFocus,
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(
          child: _gridField(
            controller: _sshPortCtrl,
            label: 'Port',
            keyboardType: TextInputType.number,
            focusId: 'ports',
            focusNode: _sshPortFocus,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _gridField(
            controller: _remotePortCtrl,
            label: 'Hermes',
            keyboardType: TextInputType.number,
            focusId: 'ports',
            focusNode: _remotePortFocus,
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    _gridField(
      controller: _sshUserCtrl,
      label: 'Username',
      focusId: 'sshUser',
      focusNode: _sshUserFocus,
    ),
    const SizedBox(height: 12),
    _gridField(
      controller: _privateKeyCtrl,
      label: 'Private Key',
      hint: 'Tap to pick a key file',
      readOnly: true,
      onTap: _pickKey,
    ),
  ];
}
