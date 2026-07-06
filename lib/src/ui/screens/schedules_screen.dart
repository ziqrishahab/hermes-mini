import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../providers/connection_provider.dart";

final schedulesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return [];
  return conn.getSchedules();
});

class SchedulesScreen extends ConsumerStatefulWidget {
  const SchedulesScreen({super.key});
  @override
  ConsumerState<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends ConsumerState<SchedulesScreen> {
  @override
  Widget build(BuildContext context) {
    final schedulesAsync = ref.watch(schedulesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Cron Scheduler",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFECECEC))),
              const SizedBox(height: 4),
              const Text("Create and manage cron jobs with delivery targets.",
                  style: TextStyle(fontSize: 13, color: Color(0xFFB4B4B4))),
              const SizedBox(height: 20),

              // New Schedule button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showCreateSheet(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("New Schedule"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF003F7A),
                    side: const BorderSide(color: Color(0xFF003F7A)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Schedule list
              schedulesAsync.when(
                data: (schedules) => schedules.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(Icons.schedule, size: 48, color: Color(0xFF8E8E8E)),
                              SizedBox(height: 16),
                              Text("No schedules yet.",
                                  style: TextStyle(fontSize: 14, color: Color(0xFF8E8E8E))),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: schedules.map((s) => _scheduleCard(s)).toList(),
                      ),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF003F7A)),
                ),
                error: (e, _) => Center(
                  child: Text("Failed: $e", style: const TextStyle(color: Color(0xFFEF4444))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scheduleCard(Map<String, dynamic> s) {
    final id = s["id"] as String? ?? "";
    final name = s["name"] as String? ?? "Unnamed";
    final cron = s["cron"] as String? ?? "";
    final target = s["target"] as String? ?? "";
    final enabled = s["enabled"] as bool? ?? false;

    // Parse cron for human-readable
    final cronParts = cron.split(" ");
    String nextRun = "";
    if (cronParts.length >= 5) {
      if (cronParts[0] == "0" && cronParts[1] == "9" && cronParts[2] == "*" && cronParts[3] == "*" && cronParts[4] == "*") {
        nextRun = "Daily at 9:00 AM";
      } else if (cronParts.every((p) => p == "*")) {
        nextRun = "Every minute";
      } else {
        nextRun = cron;
      }
    } else {
      nextRun = cron;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: enabled
                      ? const Color(0xFF003F7A).withValues(alpha: 0.15)
                      : const Color(0xFF2F2F2F),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  enabled ? Icons.timer : Icons.timer_off,
                  color: enabled ? const Color(0xFF003F7A) : const Color(0xFF8E8E8E),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFECECEC))),
                    const SizedBox(height: 2),
                    Text(nextRun,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                activeColor: const Color(0xFF003F7A),
                onChanged: (v) {
                  final conn = ref.read(connectionProvider).valueOrNull;
                  conn?.updateSchedule(id, {"enabled": v});
                  ref.invalidate(schedulesProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.send, size: 13, color: Color(0xFF8E8E8E)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  "→ $target",
                  style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E8E)),
                ),
              ),
              GestureDetector(
                onTap: () {
                  final conn = ref.read(connectionProvider).valueOrNull;
                  conn?.deleteSchedule(id);
                  ref.invalidate(schedulesProvider);
                },
                child: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateSheet(BuildContext ctx) {
    final nameCtrl = TextEditingController();
    final cronCtrl = TextEditingController();
    final targetCtrl = TextEditingController();

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171717),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text("New Schedule",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFECECEC))),
              ),
              const Divider(color: Color(0xFF2A2A2A), height: 1),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _sheetField(nameCtrl, "Schedule Name", Icons.label_outline),
                    const SizedBox(height: 12),
                    _sheetField(cronCtrl, "Cron Expression (e.g. 0 9 * * *)", Icons.schedule),
                    const SizedBox(height: 12),
                    _sheetField(targetCtrl, "Delivery Target (e.g. telegram)", Icons.send),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
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
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Create Schedule"),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Color(0xFFECECEC), fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF8E8E8E)),
        prefixIcon: Icon(icon, color: const Color(0xFF8E8E8E), size: 20),
        filled: true,
        fillColor: const Color(0xFF212121),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF003F7A)),
        ),
      ),
    );
  }
}
