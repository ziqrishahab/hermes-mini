import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../services/hermes_connection.dart";
import "../../providers/connection_provider.dart";
final skillsProvider = FutureProvider<List<SkillInfo>>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return [];
  return conn.getSkills();
});
final toolsetsProvider = FutureProvider<List<ToolsetInfo>>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return [];
  return conn.getToolsets();
});
class CapabilitiesScreen extends ConsumerWidget {
  const CapabilitiesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final skillsAsync = ref.watch(skillsProvider);
    final toolsetsAsync = ref.watch(toolsetsProvider);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Capabilities", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("Manage skills, tools, MCP, and agent workflow.", style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 24),
              _sectionLabel("Skills", tt),
              const SizedBox(height: 8),
              skillsAsync.when(
                data: (skills) => Column(children: skills.map((s) => _toggleTile(s.name, s.description, Icons.auto_awesome, s.enabled, cs, (v) {
                  ref.read(connectionProvider).valueOrNull?.setSkillEnabled(s.name, v);
                  ref.invalidate(skillsProvider);
                })).toList()),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text("Failed: $e"),
              ),
              const SizedBox(height: 16),
              _sectionLabel("Tools", tt),
              const SizedBox(height: 8),
              toolsetsAsync.when(
                data: (tools) => Column(children: tools.map((t) => _toggleTile(t.key, t.description, Icons.build, t.enabled, cs, (v) {
                  ref.read(connectionProvider).valueOrNull?.setToolsetEnabled(t.key, v);
                  ref.invalidate(toolsetsProvider);
                })).toList()),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text("Failed: $e"),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _sectionLabel(String title, TextTheme tt) {
    return Text(title, style: tt.labelSmall?.copyWith(color: const Color(0xFF948F99), fontWeight: FontWeight.w600, letterSpacing: 0.5));
  }
  Widget _toggleTile(
    String title, String subtitle, IconData icon, bool value, ColorScheme cs, ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFC7B8EA), size: 22),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        trailing: Switch(value: value, activeColor: const Color(0xFFC7B8EA), onChanged: onChanged),
      ),
    );
  }
}
