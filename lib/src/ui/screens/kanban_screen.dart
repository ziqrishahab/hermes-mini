import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../providers/connection_provider.dart";
import "../../theme.dart";
import "../widgets/neumorphic_skeleton.dart";

class KanbanScreen extends ConsumerStatefulWidget {
  const KanbanScreen({super.key});

  @override
  ConsumerState<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends ConsumerState<KanbanScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _tasks = [];

  static const List<Map<String, String>> _columns = [
    {"key": "todo", "label": "To Do"},
    {"key": "running", "label": "In Progress"},
    {"key": "review", "label": "Review"},
    {"key": "done", "label": "Done"},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _columns.length, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadBoard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBoard() async {
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = "Not connected to Hermes Daemon";
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final board = await conn.getKanbanBoard();
      final tasksList = <Map<String, dynamic>>[];
      if (board != null) {
        if (board["tasks"] is List) {
          for (final item in board["tasks"] as List) {
            if (item is Map) {
              tasksList.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          _tasks = tasksList;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  List<Map<String, dynamic>> _getTasksForColumn(String colKey) {
    return _tasks.where((t) {
      final status = (t["status"] ?? "todo").toString().toLowerCase();
      if (colKey == "todo") {
        return status == "todo" || status == "ready" || status == "triage" || status == "scheduled";
      } else if (colKey == "running") {
        return status == "running" || status == "in_progress";
      } else if (colKey == "review") {
        return status == "review";
      } else if (colKey == "done") {
        return status == "done" || status == "archived";
      }
      return status == colKey;
    }).toList();
  }

  Future<void> _moveTask(String taskId, String newStatus) async {
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) return;

    final prevTasks = List<Map<String, dynamic>>.from(_tasks);
    setState(() {
      _tasks = _tasks.map((t) {
        if (t["id"]?.toString() == taskId) {
          final updated = Map<String, dynamic>.from(t);
          updated["status"] = newStatus;
          return updated;
        }
        return t;
      }).toList();
    });

    final ok = await conn.updateKanbanTask(taskId, status: newStatus);
    if (!ok && mounted) {
      setState(() => _tasks = prevTasks);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to move task")),
      );
    }
  }

  Future<void> _deleteTask(String taskId) async {
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: NeumorphicDecoration.raised(radius: 18),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Delete Task?",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  "This task will be permanently removed from the Kanban board.",
                  style: TextStyle(fontSize: 12, color: HermesTokens.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text("Cancel", style: TextStyle(color: HermesTokens.textMuted, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: HermesTokens.error,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text("Delete", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirm == true) {
      final prevTasks = List<Map<String, dynamic>>.from(_tasks);
      setState(() {
        _tasks = _tasks.where((t) => t["id"]?.toString() != taskId).toList();
      });

      final ok = await conn.deleteKanbanTask(taskId);
      if (!ok && mounted) {
        setState(() => _tasks = prevTasks);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete task")),
        );
      }
    }
  }

  void _showCreateTaskDialog() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => _CreateKanbanTaskDialog(
        onCreated: _loadBoard,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HermesTokens.bgPrimary,
      appBar: AppBar(
        backgroundColor: HermesTokens.bgPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
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
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: HermesTokens.textPrimary, size: 16),
                onPressed: () => context.pop(),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        title: const Text(
          "Kanban Board",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: NeumorphicDecoration.raised(radius: 12, distance: 2.5, blur: 5),
                child: IconButton(
                  tooltip: "Refresh board",
                  icon: const Icon(Icons.refresh_rounded, color: HermesTokens.textSecondary, size: 18),
                  onPressed: _loadBoard,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: NeumorphicDecoration.raised(radius: 12, distance: 2.5, blur: 5),
                child: IconButton(
                  tooltip: "Add task",
                  icon: const Icon(Icons.add_rounded, color: HermesTokens.accent, size: 20),
                  onPressed: _showCreateTaskDialog,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: NeumorphicDecoration.recessed(radius: 14),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: NeumorphicDecoration.raised(radius: 10, distance: 2, blur: 4),
                labelColor: HermesTokens.accent,
                unselectedLabelColor: HermesTokens.textMuted,
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                tabs: _columns.map((col) {
                  final count = _getTasksForColumn(col["key"]!).length;
                  return Tab(
                    height: 36,
                    child: Text("${col["label"]} ($count)", maxLines: 1, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const KanbanBoardSkeleton()
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: NeumorphicDecoration.raised(radius: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: NeumorphicDecoration.recessed(radius: 14),
                            child: const Icon(Icons.error_outline_rounded, size: 24, color: HermesTokens.error),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: HermesTokens.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: _loadBoard,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                              decoration: NeumorphicDecoration.raised(radius: 10, distance: 2, blur: 4),
                              child: const Text(
                                "Retry",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HermesTokens.accent),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: _columns.map((col) {
                    final columnKey = col["key"]!;
                    final tasks = _getTasksForColumn(columnKey);

                    if (tasks.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: _loadBoard,
                        color: HermesTokens.accent,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                            Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 28),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                                decoration: NeumorphicDecoration.raised(radius: 20, distance: 3, blur: 6),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: NeumorphicDecoration.recessed(radius: 14),
                                      child: const Icon(Icons.assignment_outlined, size: 24, color: HermesTokens.textMuted),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      "No tasks in ${col["label"]}",
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HermesTokens.textPrimary),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      "Create a task or move existing tasks here",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 11, color: HermesTokens.textMuted),
                                    ),
                                    const SizedBox(height: 18),
                                    InkWell(
                                      onTap: _showCreateTaskDialog,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                        decoration: NeumorphicDecoration.raised(radius: 12, distance: 2, blur: 4),
                                        child: const Text(
                                          "Create Task",
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HermesTokens.accent),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _loadBoard,
                      color: HermesTokens.accent,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: tasks.length,
                        itemBuilder: (ctx, i) {
                          final task = tasks[i];
                          final taskId = task["id"]?.toString() ?? "";
                          final title = task["title"]?.toString() ?? "Untitled task";
                          final body = task["body"]?.toString() ?? "";
                          final priorityVal = int.tryParse(task["priority"]?.toString() ?? "0") ?? 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: NeumorphicDecoration.raised(radius: 16, distance: 2.5, blur: 5),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: HermesTokens.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (priorityVal > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: NeumorphicDecoration.recessed(radius: 6),
                                        child: Text(
                                          priorityVal == 2 ? "Urgent" : "High",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: priorityVal == 2 ? HermesTokens.error : HermesTokens.accent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (body.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: NeumorphicDecoration.recessed(radius: 10),
                                    child: Text(
                                      body,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: HermesTokens.textSecondary, height: 1.3),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Text(
                                      "Move to:",
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: HermesTokens.textMuted),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: _columns
                                              .where((c) => c["key"] != columnKey)
                                              .map((targetCol) {
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 6),
                                              child: InkWell(
                                                onTap: () => _moveTask(taskId, targetCol["key"]!),
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  decoration: NeumorphicDecoration.raised(radius: 8, distance: 1.5, blur: 3),
                                                  child: Text(
                                                    targetCol["label"]!,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: HermesTokens.textSecondary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _deleteTask(taskId),
                                      borderRadius: BorderRadius.circular(8),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.delete_outline_rounded, size: 16, color: HermesTokens.textMuted),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}

class _CreateKanbanTaskDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;

  const _CreateKanbanTaskDialog({required this.onCreated});

  @override
  ConsumerState<_CreateKanbanTaskDialog> createState() => _CreateKanbanTaskDialogState();
}

class _CreateKanbanTaskDialogState extends ConsumerState<_CreateKanbanTaskDialog> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  int _priority = 0;
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) {
      setState(() => _error = "Not connected to Hermes host");
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      final ok = await conn.createKanbanTask(
        title: title,
        body: _bodyCtrl.text.trim(),
        priority: _priority,
      );
      if (!mounted) return;
      if (ok) {
        widget.onCreated();
        Navigator.pop(context);
      } else {
        setState(() {
          _creating = false;
          _error = "Failed to create task on backend";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _creating = false;
          _error = e.toString();
        });
      }
    }
  }

  Widget _priorityChip(int val, String label) {
    final isSelected = val == _priority;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _priority = val),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: isSelected
              ? NeumorphicDecoration.raised(radius: 10, distance: 2, blur: 4)
              : NeumorphicDecoration.recessed(radius: 10),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? HermesTokens.accent : HermesTokens.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: NeumorphicDecoration.raised(radius: 20),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "New Task",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Create collaborative agent task",
                          style: TextStyle(fontSize: 11, color: HermesTokens.textMuted),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: HermesTokens.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  "Title",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HermesTokens.textPrimary),
                ),
                const SizedBox(height: 5),
                Container(
                  decoration: NeumorphicDecoration.recessed(radius: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  child: TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(fontSize: 13, color: HermesTokens.textPrimary),
                    decoration: const InputDecoration(
                      hintText: "Enter task title",
                      hintStyle: TextStyle(fontSize: 12, color: HermesTokens.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Description (Optional)",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HermesTokens.textPrimary),
                ),
                const SizedBox(height: 5),
                Container(
                  decoration: NeumorphicDecoration.recessed(radius: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: TextField(
                    controller: _bodyCtrl,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 12, color: HermesTokens.textPrimary),
                    decoration: const InputDecoration(
                      hintText: "Enter details or directives",
                      hintStyle: TextStyle(fontSize: 12, color: HermesTokens.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Priority",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HermesTokens.textPrimary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _priorityChip(0, "Normal"),
                    const SizedBox(width: 8),
                    _priorityChip(1, "High"),
                    const SizedBox(width: 8),
                    _priorityChip(2, "Urgent"),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: HermesTokens.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_error!, style: const TextStyle(fontSize: 11, color: HermesTokens.error)),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel", style: TextStyle(color: HermesTokens.textMuted, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: HermesTokens.accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      ),
                      onPressed: _creating ? null : _submit,
                      child: _creating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text("Create Task", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
