import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../providers/connection_provider.dart";
import "../../theme.dart";

final schedulesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return [];
  return conn.getSchedules();
});

// Cron expression validator
class CronValidator {
  static final _cronRegex = RegExp(
    r'^(\*|([0-9]|[1-5][0-9])|\*\/([0-9]|[1-5][0-9]))\s+'
    r'(\*|([0-9]|1[0-9]|2[0-3])|\*\/([0-9]|1[0-9]|2[0-3]))\s+'
    r'(\*|([1-9]|[12][0-9]|3[01])|\*\/([1-9]|[12][0-9]|3[01]))\s+'
    r'(\*|([1-9]|1[0-2])|\*\/([1-9]|1[0-2]))\s+'
    r'(\*|[0-6]|\*\/[0-6])$',
  );

  static String? validate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Cron expression is required';
    }
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length != 5) {
      return 'Cron must have 5 parts: minute hour day month weekday';
    }
    if (!_cronRegex.hasMatch(value.trim())) {
      return 'Invalid cron format';
    }
    return null;
  }

  static String toHumanReadable(String cron) {
    final parts = cron.split(' ');
    if (parts.length < 5) return cron;

    final minute = parts[0];
    final hour = parts[1];
    final day = parts[2];
    final month = parts[3];
    final weekday = parts[4];

    if (minute == "0" && hour == "9" && day == "*" && month == "*" && weekday == "*") {
      return "Daily at 9:00 AM";
    }
    if (minute == "0" && hour == "0" && day == "*" && month == "*" && weekday == "*") {
      return "Daily at midnight";
    }
    if (minute == "0" && hour == "12" && day == "*" && month == "*" && weekday == "*") {
      return "Daily at noon";
    }
    if (parts.every((p) => p == "*")) {
      return "Every minute";
    }
    if (minute.startsWith("*/") && hour == "*" && day == "*" && month == "*" && weekday == "*") {
      final interval = minute.substring(2);
      return "Every $interval minutes";
    }
    if (hour.startsWith("*/") && minute == "0" && day == "*" && month == "*" && weekday == "*") {
      final interval = hour.substring(2);
      return "Every $interval hours";
    }

    return cron;
  }
}

class SchedulesScreen extends ConsumerStatefulWidget {
  const SchedulesScreen({super.key});
  @override
  ConsumerState<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends ConsumerState<SchedulesScreen> {
  final _searchCtrl = TextEditingController();
  String _search = "";

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schedulesAsync = ref.watch(schedulesProvider);

    return Scaffold(
      backgroundColor: HermesTokens.bgPrimary,
      appBar: AppBar(
        backgroundColor: HermesTokens.bgPrimary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Cron Scheduler",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: HermesTokens.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search input
                  Container(
                    decoration: NeumorphicDecoration.recessed(radius: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: HermesTokens.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: "Search schedules...",
                        hintStyle: TextStyle(color: HermesTokens.textMuted, fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: HermesTokens.textMuted, size: 18),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Section count header
                  schedulesAsync.when(
                    data: (schedules) => Padding(
                      padding: const EdgeInsets.only(bottom: 2, left: 2),
                      child: Text(
                        "SCHEDULES (${schedules.length})",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: HermesTokens.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // Schedules list or centered empty state
            Expanded(
              child: RefreshIndicator(
                color: HermesTokens.accent,
                backgroundColor: HermesTokens.bgElevated,
                onRefresh: () async {
                  ref.invalidate(schedulesProvider);
                  try {
                    await ref.read(schedulesProvider.future);
                  } catch (_) {}
                },
                child: schedulesAsync.when(
                  data: (schedules) {
                    final filtered = _search.isEmpty
                        ? schedules
                        : schedules.where((s) {
                            final name = (s["name"] as String? ?? "").toLowerCase();
                            final cron = (s["cron"] as String? ?? "").toLowerCase();
                            return name.contains(_search) || cron.contains(_search);
                          }).toList();

                    if (filtered.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: NeumorphicDecoration.raised(radius: 16),
                                    child: const Icon(Icons.schedule, size: 26, color: HermesTokens.accent),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    "No schedules found",
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    "Pull down to refresh or create a cron schedule.",
                                    style: TextStyle(fontSize: 12, color: HermesTokens.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => _scheduleCard(filtered[index]),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: HermesTokens.accent),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 40, color: HermesTokens.error),
                          const SizedBox(height: 12),
                          const Text("Failed to load schedules", style: TextStyle(fontSize: 14, color: HermesTokens.error)),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => ref.invalidate(schedulesProvider),
                            child: const Text("Retry", style: TextStyle(color: HermesTokens.accentText)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: NeumorphicDecoration.raised(
          radius: 28,
          color: HermesTokens.accent,
          distance: 3.5,
          blur: 7,
        ),
        child: IconButton(
          onPressed: () => context.push('/schedule/new'),
          icon: const Icon(Icons.add, size: 24, color: Colors.white),
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

    final nextRun = CronValidator.toHumanReadable(cron);

    return GestureDetector(
      onTap: () => _openScheduleDetail(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: NeumorphicDecoration.raised(
          radius: 16,
          distance: 3.5,
          blur: 7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: HermesTokens.bgTertiary,
                    borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
                    border: Border.all(color: HermesTokens.borderBright),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    enabled ? Icons.timer_outlined : Icons.timer_off_outlined,
                    color: enabled ? HermesTokens.textPrimary : HermesTokens.textMuted,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: HermesTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: HermesTokens.codeBg,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: HermesTokens.border),
                            ),
                            child: Text(
                              cron,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: HermesTokens.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              nextRun,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: HermesTokens.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _actionButton(Icons.play_arrow, HermesTokens.success, () => _runNow(id)),
                    const SizedBox(width: 4),
                    _actionButton(Icons.edit_outlined, HermesTokens.textSecondary, () => _editSchedule(id)),
                    const SizedBox(width: 4),
                    _actionButton(Icons.delete_outline, HermesTokens.error, () => _deleteSchedule(id)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (target.isNotEmpty)
                  Expanded(
                    child: Text(
                      "Target: $target",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: HermesTokens.textMuted),
                    ),
                  )
                else
                  const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: enabled
                        ? HermesTokens.success.withValues(alpha: 0.12)
                        : HermesTokens.bgTertiary,
                    borderRadius: BorderRadius.circular(HermesTokens.radiusSm - 2),
                    border: Border.all(
                      color: enabled
                          ? HermesTokens.success.withValues(alpha: 0.3)
                          : HermesTokens.border,
                    ),
                  ),
                  child: Text(
                    enabled ? "Enabled" : "Disabled",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: enabled ? HermesTokens.success : HermesTokens.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: HermesTokens.bgTertiary,
          borderRadius: BorderRadius.circular(HermesTokens.radiusSm - 2),
          border: Border.all(color: HermesTokens.borderBright),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }

  void _openScheduleDetail(String id) {
    context.push('/schedule/$id');
  }

  Future<void> _runNow(String id) async {
    try {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Schedule triggered successfully"),
            backgroundColor: HermesTokens.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Trigger failed: $e"),
            backgroundColor: HermesTokens.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _editSchedule(String id) {
    context.push('/schedule/$id/edit');
  }

  Future<void> _deleteSchedule(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HermesTokens.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
          side: const BorderSide(color: HermesTokens.borderBright),
        ),
        title: const Text(
          "Delete Schedule?",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: HermesTokens.textPrimary),
        ),
        content: const Text(
          "This schedule will be permanently deleted. This action cannot be undone.",
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
                borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
              ),
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final conn = ref.read(connectionProvider).valueOrNull;
        if (conn != null) {
          await conn.deleteSchedule(id);
          ref.invalidate(schedulesProvider);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to delete schedule: $e"),
              backgroundColor: HermesTokens.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}
