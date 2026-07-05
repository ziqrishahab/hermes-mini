import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../providers/connection_provider.dart";
final schedulesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return [];
  return conn.getSchedules();
});
class SchedulesScreen extends ConsumerWidget {
  const SchedulesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final schedulesAsync = ref.watch(schedulesProvider);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Schedules", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("Create and manage cron jobs with delivery targets.", style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showCreateDialog(context, ref),
                  icon: const Icon(Icons.add, color: Color(0xFFC7B8EA)),
                  label: const Text("New Schedule", style: TextStyle(color: Color(0xFFC7B8EA))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2A2A2A)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              schedulesAsync.when(
                data: (schedules) => schedules.isEmpty
                    ? Center(child: Text("No schedules yet.", style: TextStyle(color: cs.onSurfaceVariant)))
                    : Column(children: schedules.map((s) => _scheduleTile(s, cs, ref)).toList()),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text("Failed: $e")),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _scheduleTile(Map<String, dynamic> s, ColorScheme cs, WidgetRef ref) {
    final id = s["id"] as String? ?? "";
    final name = s["name"] as String? ?? "Unnamed";
    final cron = s["cron"] as String? ?? "";
    final target = s["target"] as String? ?? "";
    final enabled = s["enabled"] as bool? ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(enabled ? Icons.timer : Icons.timer_off, color: enabled ? const Color(0xFFC7B8EA) : const Color(0xFF948F99)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text("$cron → $target", style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: enabled,
              activeColor: const Color(0xFFC7B8EA),
              onChanged: (v) {
                final conn = ref.read(connectionProvider).valueOrNull;
                conn?.updateSchedule(id, {"enabled": v});
                ref.invalidate(schedulesProvider);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFE57373), size: 20),
              onPressed: () {
                final conn = ref.read(connectionProvider).valueOrNull;
                conn?.deleteSchedule(id);
                ref.invalidate(schedulesProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final cronCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New Schedule"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: "Name")),
            TextField(controller: cronCtrl, decoration: const InputDecoration(hintText: "Cron (e.g. 0 9 * * *)")),
            TextField(controller: targetCtrl, decoration: const InputDecoration(hintText: "Target (e.g. Discord)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () {
              final conn = ref.read(connectionProvider).valueOrNull;
              conn?.createSchedule({
                "name": nameCtrl.text,
                "cron": cronCtrl.text,
                "target": targetCtrl.text,
                "enabled": true,
              });
              ref.invalidate(schedulesProvider);
              Navigator.pop(ctx);
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }
}
