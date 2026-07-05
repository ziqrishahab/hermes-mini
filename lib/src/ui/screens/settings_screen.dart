import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../services/hermes_connection.dart";
import "../../providers/connection_provider.dart";
import "../../providers/chat_provider.dart";

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final modelsAsync = ref.watch(modelsProvider);
    final config = ref.watch(connectionConfigProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Settings", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("Gateway, models, provider, and preferences.", style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 24),
              _sectionHeader("Connection", tt),
              const SizedBox(height: 8),
              _card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                _infoRow(Icons.link, "Mode", config?.mode.name ?? "N/A"),
                const Divider(height: 24, color: Color(0xFF2A2A2A)),
                _infoRow(Icons.dns, "Server", config?.sshHost ?? config?.apiUrl ?? "N/A"),
                const Divider(height: 24, color: Color(0xFF2A2A2A)),
                _infoRow(Icons.info_outline, "Version", "1.0.0"),
              ]))),
              const SizedBox(height: 24),
              _sectionHeader("Models", tt),
              const SizedBox(height: 4),
              Text("Toggle and configure AI providers.", style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 12),
              modelsAsync.when(
                data: (models) => models.isEmpty
                    ? _card(child: Padding(padding: const EdgeInsets.all(20), child: Center(child: Text("No models configured.", style: TextStyle(color: cs.onSurfaceVariant)))))
                    : Column(children: models.map((m) => _modelTile(m, cs, ref)).toList()),
                loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => _card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                  const Icon(Icons.error_outline, color: Color(0xFFE57373), size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Failed to load models", style: TextStyle(color: cs.onSurfaceVariant))),
                ]))),
              ),
              const SizedBox(height: 32),
              _sectionHeader("Danger Zone", tt),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                    title: const Text("Disconnect?"),
                    content: const Text("You will need to re-enter your connection details."),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE57373)), child: const Text("Disconnect")),
                    ],
                  ));
                  if (ok == true && context.mounted) {
                    await ref.read(connectionProvider.notifier).disconnect();
                    if (context.mounted) context.go("/connect");
                  }
                },
                icon: const Icon(Icons.logout, color: Color(0xFFE57373)),
                label: const Text("Disconnect", style: TextStyle(color: Color(0xFFE57373))),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF3A2020)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String t, TextTheme tt) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(t, style: tt.titleSmall?.copyWith(color: const Color(0xFF948F99), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
  );

  Widget _card({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(14)),
    child: child,
  );

  Widget _infoRow(IconData icon, String label, String value) => Row(children: [
    Icon(icon, color: const Color(0xFFC7B8EA), size: 20),
    const SizedBox(width: 12),
    Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF948F99))),
    const Spacer(),
    Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
  ]);

  Widget _modelTile(ModelConfig m, ColorScheme cs, WidgetRef ref) => _card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: const Color(0xFFC7B8EA).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : "?", style: const TextStyle(color: Color(0xFFC7B8EA), fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 2),
          Text([m.provider, if (m.apiKeyHint != null) m.apiKeyHint].where((e) => e != null && e.isNotEmpty).join(" · "), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ])),
        Switch(value: m.enabled, activeColor: const Color(0xFFC7B8EA), onChanged: (v) {
          ref.read(connectionProvider).valueOrNull?.setModelEnabled(m.name, v);
          ref.invalidate(modelsProvider);
        }),
      ]),
    ),
  );
}