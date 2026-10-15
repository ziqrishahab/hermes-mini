import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../providers/connection_provider.dart";
import "../../theme.dart";

final scheduleDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return null;

  final schedules = await conn.getSchedules();
  try {
    return schedules.firstWhere((s) => s['id'] == id);
  } catch (_) {
    return null;
  }
});

String _formatTimezone(String? timezone) {
  if (timezone == null || timezone.isEmpty) return 'Asia/Jakarta (GMT+07:00)';
  return timezone;
}

String _getCronDescription(String cron) {
  final parts = cron.split(' ');
  if (parts.length < 5) return cron;

  final minute = parts[0];
  final hour = parts[1];
  final day = parts[2];
  final month = parts[3];
  final weekday = parts[4];

  if (minute == "0" && hour == "9" && day == "*" && month == "*" && weekday == "*") {
    return "Daily at 09:00 AM";
  }
  if (minute == "0" && hour == "0" && day == "*" && month == "*" && weekday == "*") {
    return "Daily at midnight";
  }
  if (minute == "0" && hour == "12" && day == "*" && month == "*" && weekday == "*") {
    return "Daily at 12:00 PM";
  }
  if (minute.startsWith("*/") && hour == "*" && day == "*" && month == "*" && weekday == "*") {
    final interval = minute.substring(2);
    return "Every $interval minutes";
  }
  if (weekday == "Sun" && hour == "0" && minute == "0") {
    return "Every Sunday at midnight";
  }

  return cron;
}

DateTime? _getNextRun(String cron) {
  final parts = cron.split(' ');
  if (parts.length < 5) return null;

  final minute = int.tryParse(parts[0]) ?? 0;
  final hour = int.tryParse(parts[1]) ?? 0;
  final weekday = int.tryParse(parts[4]) ?? -1;

  final now = DateTime.now();

  if (weekday >= 0) {
    var next = now;
    while (true) {
      next = next.add(const Duration(days: 1));
      if (next.weekday % 7 == weekday) {
        return DateTime(next.year, next.month, next.day, hour, minute);
      }
    }
  }

  var next = DateTime(now.year, now.month, now.day, hour, minute);
  if (next.isBefore(now)) {
    next = next.add(const Duration(days: 1));
  }
  return next;
}

String _formatNextRun(DateTime? dt) {
  if (dt == null) return '-';

  final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final ampm = dt.hour >= 12 ? "PM" : "AM";

  final now = DateTime.now();
  final diff = dt.difference(now);

  if (diff.inDays == 0) {
    return "Today, ${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm";
  }
  if (diff.inDays == 1) {
    return "Tomorrow, ${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm";
  }

  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return "${dt.day} ${months[dt.month - 1]}, ${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm";
}

String _formatTimeUntil(DateTime? dt) {
  if (dt == null) return '-';
  final now = DateTime.now();
  final diff = dt.difference(now);

  if (diff.inHours < 1) {
    return "In ${diff.inMinutes} mins";
  }
  if (diff.inHours < 24) {
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    return "In $hours hrs $mins mins";
  }
  final days = diff.inDays;
  final hours = diff.inHours % 24;
  return "In $days days $hours hrs";
}

class ScheduleDetailScreen extends ConsumerStatefulWidget {
  final String scheduleId;

  const ScheduleDetailScreen({super.key, required this.scheduleId});
  @override
  ConsumerState<ScheduleDetailScreen> createState() => _ScheduleDetailScreenState();
}

class _ScheduleDetailScreenState extends ConsumerState<ScheduleDetailScreen> {
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    final scheduleAsync = ref.watch(scheduleDetailProvider(widget.scheduleId));

    return Scaffold(
      backgroundColor: HermesTokens.bgPrimary,
      appBar: AppBar(
        backgroundColor: HermesTokens.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HermesTokens.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          "Schedule Detail",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
        ),
        centerTitle: false,
      ),
      body: scheduleAsync.when(
        data: (schedule) {
          if (schedule == null) {
            return _buildNotFound();
          }
          return _buildContent(schedule);
        },
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: HermesTokens.accent)),
        error: (e, _) => _buildError(e.toString()),
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: HermesTokens.bgSecondary,
              borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
              border: Border.all(color: HermesTokens.border),
            ),
            child: const Icon(Icons.search_off, size: 24, color: HermesTokens.textMuted),
          ),
          const SizedBox(height: 16),
          const Text("Schedule not found", style: TextStyle(color: HermesTokens.textMuted, fontSize: 14)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.pop(),
            style: FilledButton.styleFrom(
              backgroundColor: HermesTokens.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HermesTokens.radiusSm)),
            ),
            child: const Text("Go Back"),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: HermesTokens.error),
          const SizedBox(height: 16),
          Text("Error: $error", style: const TextStyle(color: HermesTokens.error, fontSize: 13)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.pop(),
            style: FilledButton.styleFrom(
              backgroundColor: HermesTokens.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HermesTokens.radiusSm)),
            ),
            child: const Text("Go Back"),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> schedule) {
    final name = schedule['name'] as String? ?? "Unnamed";
    final cron = schedule['cron'] as String? ?? "";
    final target = schedule['target'] as String? ?? "";
    final enabled = schedule['enabled'] as bool? ?? false;
    final timezone = schedule['timezone'] as String?;
    final lastRun = schedule['lastRun'] as String?;

    final nextRun = _getNextRun(cron);
    final description = _getCronDescription(cron);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: HermesTokens.bgSecondary,
                    borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
                    border: Border.all(color: HermesTokens.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: HermesTokens.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: enabled
                                  ? HermesTokens.success.withValues(alpha: 0.12)
                                  : HermesTokens.bgTertiary,
                              borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
                              border: Border.all(
                                color: enabled
                                    ? HermesTokens.success.withValues(alpha: 0.3)
                                    : HermesTokens.border,
                              ),
                            ),
                            child: Text(
                              enabled ? "Active" : "Inactive",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: enabled ? HermesTokens.success : HermesTokens.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (lastRun != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Last executed: $lastRun",
                          style: const TextStyle(fontSize: 12, color: HermesTokens.textMuted),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Schedule Status",
                            style: TextStyle(fontSize: 12, color: HermesTokens.textSecondary),
                          ),
                          Switch(
                            value: enabled,
                            activeThumbColor: Colors.white,
                            activeTrackColor: const Color(0xFF0066CC),
                            inactiveThumbColor: const Color(0xFF8E8E93),
                            inactiveTrackColor: const Color(0xFF262626),
                            trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return Colors.transparent;
                              }
                              return const Color(0xFF404040);
                            }),
                            onChanged: (v) => _toggleSchedule(schedule, v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // CRON CONFIGURATION
                const Text(
                  "CRON CONFIGURATION",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: HermesTokens.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(child: _cronItem(Icons.code_outlined, "Expression", cron)),
                    const SizedBox(width: 8),
                    Expanded(child: _cronItem(Icons.repeat, "Frequency", description)),
                    const SizedBox(width: 8),
                    Expanded(child: _cronItem(Icons.public, "Timezone", _formatTimezone(timezone))),
                  ],
                ),

                const SizedBox(height: 18),

                // NEXT RUN
                const Text(
                  "NEXT RUN ESTIMATE",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: HermesTokens.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(child: _executionItem(Icons.schedule, "Scheduled Time", _formatNextRun(nextRun))),
                    const SizedBox(width: 8),
                    Expanded(child: _executionItem(Icons.timer_outlined, "Time Until Run", _formatTimeUntil(nextRun))),
                  ],
                ),

                if (target.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text(
                    "TARGET DESTINATION",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: HermesTokens.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: HermesTokens.bgSecondary,
                      borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
                      border: Border.all(color: HermesTokens.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.send_outlined, size: 16, color: HermesTokens.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          target,
                          style: const TextStyle(fontSize: 13, color: HermesTokens.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Bottom actions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: HermesTokens.bgSecondary,
            border: Border(top: BorderSide(color: HermesTokens.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _running ? null : () => _runNow(schedule),
                  icon: _running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow, size: 18),
                  label: Text(_running ? "Executing..." : "Trigger Run Now", style: const TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    backgroundColor: HermesTokens.accent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HermesTokens.radiusSm)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editSchedule(schedule),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text("Edit Schedule", style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: HermesTokens.borderBright),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HermesTokens.radiusSm)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteSchedule(schedule),
                      icon: const Icon(Icons.delete_outline, size: 16, color: HermesTokens.error),
                      label: const Text("Delete", style: TextStyle(fontSize: 13, color: HermesTokens.error)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: BorderSide(color: HermesTokens.error.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HermesTokens.radiusSm)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cronItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: HermesTokens.bgSecondary,
        borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
        border: Border.all(color: HermesTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: HermesTokens.textSecondary),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: HermesTokens.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: HermesTokens.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _executionItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: HermesTokens.bgSecondary,
        borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
        border: Border.all(color: HermesTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: HermesTokens.textSecondary),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: HermesTokens.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: HermesTokens.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSchedule(Map<String, dynamic> schedule, bool enabled) async {
    try {
      final conn = ref.read(connectionProvider).valueOrNull;
      if (conn != null) {
        await conn.updateSchedule(widget.scheduleId, {...schedule, 'enabled': enabled});
        ref.invalidate(scheduleDetailProvider(widget.scheduleId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update status: $e"),
            backgroundColor: HermesTokens.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _runNow(Map<String, dynamic> schedule) async {
    setState(() => _running = true);
    try {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Schedule run triggered successfully"),
            backgroundColor: HermesTokens.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to run schedule: $e"),
            backgroundColor: HermesTokens.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _editSchedule(Map<String, dynamic> schedule) {
    context.push('/schedule/${widget.scheduleId}/edit');
  }

  Future<void> _deleteSchedule(Map<String, dynamic> schedule) async {
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
          style: TextStyle(color: HermesTokens.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          "This schedule will be permanently removed. This action cannot be undone.",
          style: TextStyle(color: HermesTokens.textSecondary, fontSize: 13),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HermesTokens.radiusSm)),
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final conn = ref.read(connectionProvider).valueOrNull;
        if (conn != null) {
          await conn.deleteSchedule(widget.scheduleId);
          if (mounted) context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to delete: $e"),
              backgroundColor: HermesTokens.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}
