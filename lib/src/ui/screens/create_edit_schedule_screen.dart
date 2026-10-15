import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../providers/connection_provider.dart";
import "../../theme.dart";
import "schedules_screen.dart";

class CreateEditScheduleScreen extends ConsumerStatefulWidget {
  final String? scheduleId;

  const CreateEditScheduleScreen({super.key, this.scheduleId});
  @override
  ConsumerState<CreateEditScheduleScreen> createState() => _CreateEditScheduleScreenState();
}

class _CreateEditScheduleScreenState extends ConsumerState<CreateEditScheduleScreen> {
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();

  int _selectedHour = 9;
  int _selectedMinute = 0;
  List<int> _selectedDays = [0, 1, 2, 3, 4, 5, 6];
  bool _saving = false;

  bool get isEditing => widget.scheduleId != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = isEditing ? "Backup Database" : "";
    _targetCtrl.text = isEditing ? "telegram" : "";
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  String _buildCron() {
    final minute = _selectedMinute.toString().padLeft(2, '0');
    final hour = _selectedHour.toString().padLeft(2, '0');

    if (_selectedDays.length == 7) {
      return "$minute $hour * * *";
    }

    final days = _selectedDays.join(",");
    return "$minute $hour * * $days";
  }

  String _buildDayLabel() {
    if (_selectedDays.length == 7) return "Every day";
    if (_selectedDays.length == 5 && !_selectedDays.contains(5) && !_selectedDays.contains(6)) {
      return "Monday to Friday";
    }

    final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return _selectedDays.map((d) => dayNames[d]).join(", ");
  }

  String _formatTime() {
    final hour = _selectedHour > 12 ? _selectedHour - 12 : (_selectedHour == 0 ? 12 : _selectedHour);
    final ampm = _selectedHour >= 12 ? "PM" : "AM";
    return "${hour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')} $ampm";
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim().isEmpty ? "Schedule ${DateTime.now().millisecondsSinceEpoch}" : _nameCtrl.text.trim();

    setState(() => _saving = true);

    try {
      final conn = ref.read(connectionProvider).valueOrNull;
      if (conn == null) throw Exception("Not connected to Hermes");

      final schedule = {
        'name': name,
        'cron': _buildCron(),
        'target': _targetCtrl.text.trim(),
        'timezone': 'Asia/Jakarta',
        'enabled': true,
      };

      if (isEditing) {
        await conn.updateSchedule(widget.scheduleId!, schedule);
      } else {
        await conn.createSchedule(schedule);
      }

      ref.invalidate(schedulesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? "Schedule updated" : "Schedule created"),
            backgroundColor: HermesTokens.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save: $e"),
            backgroundColor: HermesTokens.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
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

    if (confirm == true && mounted && widget.scheduleId != null) {
      setState(() => _saving = true);
      try {
        final conn = ref.read(connectionProvider).valueOrNull;
        if (conn == null) throw Exception("Not connected to Hermes");
        await conn.deleteSchedule(widget.scheduleId!);
        ref.invalidate(schedulesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Schedule deleted"),
              backgroundColor: HermesTokens.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.pop();
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
      } finally {
        if (mounted) setState(() => _saving = false);
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
        leading: IconButton(
          icon: const Icon(Icons.close, color: HermesTokens.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEditing ? "Edit Schedule" : "New Schedule",
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: HermesTokens.textPrimary,
          ),
        ),
        actions: [
          if (isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: GestureDetector(
                  onTap: _saving ? null : _delete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: NeumorphicDecoration.raised(
                      radius: 12,
                      distance: 2.5,
                      blur: 5,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: HermesTokens.error),
                        SizedBox(width: 4),
                        Text(
                          "Hapus",
                          style: TextStyle(
                            color: HermesTokens.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Scheduled Time Display (Neumorphic Raised Card, clean time text without inner border)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                decoration: NeumorphicDecoration.raised(
                  radius: 20,
                  distance: 4.5,
                  blur: 9,
                ),
                child: Column(
                  children: [
                    const Text(
                      "SCHEDULED TIME",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: HermesTokens.textMuted,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _showTimePicker,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Text(
                          _formatTime(),
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w300,
                            letterSpacing: -1,
                            color: HermesTokens.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showTimePicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: NeumorphicDecoration.raised(
                          radius: 18,
                          distance: 2,
                          blur: 4,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time_rounded, size: 14, color: HermesTokens.accent),
                            SizedBox(width: 6),
                            Text(
                              "Change Time",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: HermesTokens.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Configuration Form Card (Neumorphic Raised Container)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: NeumorphicDecoration.raised(
                  radius: 20,
                  distance: 4.5,
                  blur: 9,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Field 1: Name
                    const Text(
                      "SCHEDULE NAME",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: HermesTokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: NeumorphicDecoration.recessed(radius: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      child: TextField(
                        controller: _nameCtrl,
                        style: const TextStyle(
                          color: HermesTokens.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          icon: Icon(Icons.label_outline, size: 18, color: HermesTokens.textMuted),
                          hintText: "Daily Sync, Backup Local Database",
                          hintStyle: TextStyle(color: HermesTokens.textMuted, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                          isDense: true,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Field 2: Recurrence
                    const Text(
                      "RECURRENCE",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: HermesTokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showDayPicker,
                      child: Container(
                        decoration: NeumorphicDecoration.recessed(radius: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.repeat, size: 18, color: HermesTokens.textMuted),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _buildDayLabel(),
                                style: const TextStyle(
                                  color: HermesTokens.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 18, color: HermesTokens.textMuted),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Field 3: Target
                    const Text(
                      "TARGET CHANNEL / COMMAND",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: HermesTokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: NeumorphicDecoration.recessed(radius: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      child: TextField(
                        controller: _targetCtrl,
                        style: const TextStyle(
                          color: HermesTokens.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          icon: Icon(Icons.send_outlined, size: 18, color: HermesTokens.textMuted),
                          hintText: "general, alerts, or command",
                          hintStyle: TextStyle(color: HermesTokens.textMuted, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Generated Cron Preview (Recessed Neumorphic Pill)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: NeumorphicDecoration.recessed(radius: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: NeumorphicDecoration.raised(
                        radius: 6,
                        distance: 1.5,
                        blur: 3,
                      ),
                      child: const Text(
                        "CRON",
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: HermesTokens.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _buildCron(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: HermesTokens.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Primary Action Button (Neumorphic Prominent CTA)
              GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: NeumorphicDecoration.raised(
                    radius: 16,
                    color: HermesTokens.accent,
                    distance: 4,
                    blur: 8,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isEditing ? Icons.check : Icons.add_alarm, size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              isEditing ? "Save Schedule" : "Create Schedule",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTimePicker() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: HermesTokens.bgElevated,
              dialBackgroundColor: HermesTokens.bgTertiary,
              dialHandColor: HermesTokens.accent,
              hourMinuteTextColor: HermesTokens.textPrimary,
              dayPeriodTextColor: HermesTokens.textPrimary,
              helpTextStyle: const TextStyle(color: HermesTokens.textPrimary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HermesTokens.radiusMd)),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedHour = picked.hour;
        _selectedMinute = picked.minute;
      });
    }
  }

  void _showDayPicker() {
    final dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    showModalBottomSheet(
      context: context,
      backgroundColor: HermesTokens.bgPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(HermesTokens.radiusMd)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancel", style: TextStyle(color: HermesTokens.textMuted)),
                      ),
                      const Text(
                        "Repeat Days",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: HermesTokens.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: NeumorphicDecoration.raised(radius: 10, distance: 2, blur: 4),
                          child: const Text(
                            "Done",
                            style: TextStyle(color: HermesTokens.accentText, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Quick options chips
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Row(
                    children: [
                      _quickDayChip("Every Day", _selectedDays.length == 7, () {
                        setSheet(() => _selectedDays = [0, 1, 2, 3, 4, 5, 6]);
                        setState(() {});
                      }),
                      const SizedBox(width: 8),
                      _quickDayChip("Weekdays", !_selectedDays.contains(0) && !_selectedDays.contains(6) && _selectedDays.length == 5, () {
                        setSheet(() => _selectedDays = [1, 2, 3, 4, 5]);
                        setState(() {});
                      }),
                      const SizedBox(width: 8),
                      _quickDayChip("Weekends", (_selectedDays.contains(0) || _selectedDays.contains(6)) && _selectedDays.length == 2, () {
                        setSheet(() => _selectedDays = [0, 6]);
                        setState(() {});
                      }),
                    ],
                  ),
                ),
                // Day checkboxes with neumorphic touch
                ...List.generate(7, (i) {
                  final isChecked = _selectedDays.contains(i);
                  return InkWell(
                    onTap: () {
                      setSheet(() {
                        if (isChecked) {
                          _selectedDays = _selectedDays.where((d) => d != i).toList();
                        } else {
                          _selectedDays = [..._selectedDays, i]..sort();
                        }
                      });
                      setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: isChecked
                                ? NeumorphicDecoration.raised(radius: 6, color: HermesTokens.accent, distance: 1.5, blur: 3)
                                : NeumorphicDecoration.recessed(radius: 6),
                            child: isChecked
                                ? const Icon(Icons.check, size: 15, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            dayNames[i],
                            style: TextStyle(
                              color: isChecked ? HermesTokens.textPrimary : HermesTokens.textSecondary,
                              fontSize: 13,
                              fontWeight: isChecked ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickDayChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: selected
            ? NeumorphicDecoration.raised(radius: 10, color: HermesTokens.accent, distance: 2, blur: 4)
            : NeumorphicDecoration.raised(radius: 10, distance: 2, blur: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : HermesTokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
