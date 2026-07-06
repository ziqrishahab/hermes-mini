import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../providers/connection_provider.dart";
import "../../providers/chat_provider.dart";
import "../../services/hermes_connection.dart";

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pushEnabled = true;

  @override
  Widget build(BuildContext context) {
    final modelsAsync = ref.watch(modelsProvider);
    final selected = ref.watch(selectedModelProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Settings",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFECECEC))),
              const SizedBox(height: 28),

              _sectionLabel("PROFILE"),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: _cardDeco,
                child: const Row(
                  children: [
                    CircleAvatar(radius: 22, backgroundColor: Color(0xFF2F2F2F),
                        child: Icon(Icons.person, color: Color(0xFFB4B4B4), size: 24)),
                    SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("Muhammad Ziqri",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFECECEC))),
                      Row(children: [
                        Icon(Icons.circle, size: 8, color: Color(0xFF22C55E)),
                        SizedBox(width: 6),
                        Text("Online", style: TextStyle(fontSize: 12, color: Color(0xFF22C55E))),
                      ]),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _sectionLabel("PROVIDER"),
              const SizedBox(height: 8),
              Container(
                decoration: _cardDeco,
                child: Column(children: [
                  _navRow(
                    icon: Icons.dns,
                    title: "Provider / Model",
                    subtitle: "Config Provider and Model",
                    value: modelsAsync.when(data: (_) => selected, loading: () => "...", error: (_, __) => "N/A"),
                    onTap: () => _showProviderSheet(),
                  ),
                  _divider,
                  _navRow(
                    icon: Icons.psychology,
                    title: "Soul Editor",
                    subtitle: "Your soul agent editor is here",
                    onTap: () => context.push("/soul-editor"),
                  ),
                  _divider,
                  _navRow(
                    icon: Icons.shield,
                    title: "Capabilities",
                    subtitle: "Config your Agent Skills, MCP Server and Plugin",
                    onTap: () => context.push("/capabilities"),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              _sectionLabel("SYSTEM"),
              const SizedBox(height: 8),
              Container(
                decoration: _cardDeco,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    const Icon(Icons.notifications_outlined, color: Color(0xFF8E8E8E), size: 22),
                    const SizedBox(width: 12),
                    const Expanded(child: Text("Push Notifications",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFECECEC)))),
                    Switch(value: _pushEnabled, activeColor: const Color(0xFF003F7A),
                        onChanged: (v) => setState(() => _pushEnabled = v)),
                  ]),
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF212121),
                      title: const Text("Disconnect?", style: TextStyle(color: Color(0xFFECECEC))),
                      content: const Text("You will need to re-enter your connection details.",
                          style: TextStyle(color: Color(0xFFB4B4B4))),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false),
                            child: const Text("Cancel", style: TextStyle(color: Color(0xFF8E8E8E)))),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                            child: const Text("Disconnect")),
                      ],
                    ));
                    if (ok == true && context.mounted) {
                      await ref.read(connectionProvider.notifier).disconnect();
                      if (context.mounted) context.go("/connect");
                    }
                  },
                  icon: const Icon(Icons.logout, size: 18, color: Color(0xFFEF4444)),
                  label: const Text("Logout Session",
                      style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w500)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Center(child: Text("Hermes Mobile v1.0.0 (Dev Build)",
                  style: TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)))),
            ],
          ),
        ),
      ),
    );
  }

  void _showProviderSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171717),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (_) => const _ProviderSheet(),
    );
  }

  static const _cardDeco = BoxDecoration(color: Color(0xFF171717), borderRadius: BorderRadius.all(Radius.circular(10)));
  static const _divider = Divider(height: 1, color: Color(0xFF2A2A2A));

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8E8E8E), letterSpacing: 0.8)),
  );

  Widget _navRow({required IconData icon, required String title, String? subtitle, String? value, Widget? trailing, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF8E8E8E), size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFECECEC))),
            if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E8E))),
          ])),
          if (value != null) Padding(padding: const EdgeInsets.only(right: 8),
              child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFFB4B4B4)))),
          trailing ?? const Icon(Icons.chevron_right, size: 20, color: Color(0xFF8E8E8E)),
        ]),
      ),
    );
  }
}

// ── PROVIDER BOTTOM SHEET ──

enum _Step { info, editUrl, editModel, confirm }

class _ProviderSheet extends ConsumerStatefulWidget {
  const _ProviderSheet();
  @override
  ConsumerState<_ProviderSheet> createState() => _ProviderSheetState();
}

class _ProviderSheetState extends ConsumerState<_ProviderSheet> {
  _Step _step = _Step.info;
  final _urlCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  String _savedUrl = "";
  String _savedModel = "";

  @override
  void dispose() { _urlCtrl.dispose(); _modelCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final modelsAsync = ref.watch(modelsProvider);
    final selected = ref.watch(selectedModelProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AnimatedSize(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _buildBody(modelsAsync, selected)),
      ),
    );
  }

  Widget _buildBody(AsyncValue<List<ModelConfig>> models, String sel) {
    switch (_step) {
      case _Step.info: return _infoView(models, sel);
      case _Step.editUrl: return _editUrlView();
      case _Step.editModel: return _editModelView();
      case _Step.confirm: return _confirmView();
    }
  }

  Widget _infoView(AsyncValue<List<ModelConfig>> modelsAsync, String selected) {
    final provider = modelsAsync.when(
      data: (models) => models.where((x) => x.name == selected).firstOrNull?.provider ?? "N/A",
      loading: () => "...", error: (_, __) => "N/A",
    );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Padding(padding: EdgeInsets.all(16), child: Text("Provider / Model",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFECECEC)))),
      const Divider(color: Color(0xFF2A2A2A), height: 1),
      _row(Icons.dns, "Provider", provider),
      _row(Icons.bolt, "Model", selected),
      _row(Icons.link, "Base URL", _savedUrl.isEmpty ? "Default" : _savedUrl),
      const SizedBox(height: 8),
      Row(children: [
        const SizedBox(width: 16),
        Expanded(child: OutlinedButton(
          onPressed: () => setState(() => _step = _Step.editUrl),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF003F7A)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.edit, size: 16, color: Color(0xFF003F7A)),
            SizedBox(width: 6),
            Text("Edit", style: TextStyle(color: Color(0xFF003F7A), fontWeight: FontWeight.w500)),
          ]),
        )),
        const SizedBox(width: 12),
        Expanded(child: FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text("OK", style: TextStyle(fontWeight: FontWeight.w500)),
        )),
        const SizedBox(width: 16),
      ]),
      const SizedBox(height: 16),
    ]);
  }

  Widget _editUrlView() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF8E8E8E)),
            onPressed: () => setState(() => _step = _Step.info), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        const SizedBox(width: 8),
        const Expanded(child: Text("Base URL",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFECECEC)))),
      ])),
      const Divider(color: Color(0xFF2A2A2A), height: 1),
      const SizedBox(height: 16),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(
        controller: _urlCtrl, autofocus: true,
        style: const TextStyle(color: Color(0xFFECECEC), fontSize: 14),
        decoration: InputDecoration(
          hintText: "https://your-provider.com/v1", hintStyle: const TextStyle(color: Color(0xFF8E8E8E)),
          filled: true, fillColor: const Color(0xFF212121),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0x1AFFFFFF))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF003F7A))),
        ),
      )),
      const SizedBox(height: 16),
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: SizedBox(width: double.infinity, child: FilledButton(
        onPressed: () { _savedUrl = _urlCtrl.text.trim(); setState(() => _step = _Step.editModel); },
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        child: const Text("OK", style: TextStyle(fontWeight: FontWeight.w500)),
      ))),
    ]);
  }

  Widget _editModelView() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF8E8E8E)),
            onPressed: () => setState(() => _step = _Step.editUrl), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        const SizedBox(width: 8),
        const Expanded(child: Text("Model Name",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFECECEC)))),
      ])),
      const Divider(color: Color(0xFF2A2A2A), height: 1),
      const SizedBox(height: 16),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(
        controller: _modelCtrl, autofocus: true,
        style: const TextStyle(color: Color(0xFFECECEC), fontSize: 14),
        decoration: InputDecoration(
          hintText: "e.g. gpt-4, deepseek-v3", hintStyle: const TextStyle(color: Color(0xFF8E8E8E)),
          filled: true, fillColor: const Color(0xFF212121),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0x1AFFFFFF))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF003F7A))),
        ),
      )),
      const SizedBox(height: 16),
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: SizedBox(width: double.infinity, child: FilledButton(
        onPressed: () { _savedModel = _modelCtrl.text.trim(); setState(() => _step = _Step.confirm); },
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        child: const Text("OK", style: TextStyle(fontWeight: FontWeight.w500)),
      ))),
    ]);
  }

  Widget _confirmView() {
    final changed = _savedModel.isNotEmpty || _savedUrl.isNotEmpty;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF8E8E8E)),
            onPressed: () => setState(() => _step = _Step.editModel), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        const SizedBox(width: 8),
        const Expanded(child: Text("Confirm Changes",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFECECEC)))),
      ])),
      const Divider(color: Color(0xFF2A2A2A), height: 1),
      const SizedBox(height: 12),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF212121), borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          if (_savedUrl.isNotEmpty) _cRow("Base URL", _savedUrl),
          if (_savedModel.isNotEmpty) _cRow("Model", _savedModel),
          if (!changed) const Text("No changes.", style: TextStyle(color: Color(0xFF8E8E8E))),
        ]),
      )),
      const SizedBox(height: 16),
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF2A2A2A)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text("Cancel", style: TextStyle(color: Color(0xFF8E8E8E))),
        )),
        const SizedBox(width: 12),
        Expanded(child: FilledButton(
          onPressed: () {
            if (_savedModel.isNotEmpty) ref.read(selectedModelProvider.notifier).state = _savedModel;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Provider configuration saved."), backgroundColor: Color(0xFF22C55E),
              behavior: SnackBarBehavior.floating));
            Navigator.pop(context);
          },
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text("OK", style: TextStyle(fontWeight: FontWeight.w500)),
        )),
      ])),
    ]);
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      Icon(icon, color: const Color(0xFF8E8E8E), size: 20),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFECECEC))),
    ]),
  );

  Widget _cRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Text("$label: ", style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFECECEC)))),
    ]),
  );
}
