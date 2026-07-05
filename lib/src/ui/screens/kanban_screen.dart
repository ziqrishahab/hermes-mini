import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/kanban_provider.dart';

class KanbanScreen extends ConsumerWidget {
  const KanbanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(kanbanProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final active = tasks.where((t) => t.status == KanbanStatus.active).toList();
    final backlog = tasks.where((t) => t.status == KanbanStatus.backlog).toList();
    final done = tasks.where((t) => t.status == KanbanStatus.done).toList();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Kanban', style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${tasks.length} tasks', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                ])),
              ]),
              const SizedBox(height: 24),
              if (active.isNotEmpty) ...[
                _columnHeader('ACTIVE', active.length, tt),
                const SizedBox(height: 8),
                ...active.map((t) => _taskCard(t, ref, cs)),
                const SizedBox(height: 24),
              ],
              if (backlog.isNotEmpty) ...[
                _columnHeader('BACKLOG', backlog.length, tt),
                const SizedBox(height: 8),
                ...backlog.map((t) => _taskCard(t, ref, cs)),
                const SizedBox(height: 24),
              ],
              if (done.isNotEmpty) ...[
                _columnHeader('DONE', done.length, tt),
                const SizedBox(height: 8),
                ...done.map((t) => _taskCard(t, ref, cs)),
                const SizedBox(height: 24),
              ],
              if (tasks.isEmpty)
                _emptyState(cs, tt),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFC7B8EA),
        foregroundColor: const Color(0xFF121212),
        child: const Icon(Icons.add),
        onPressed: () => _showAddDialog(context, ref),
      ),
    );
  }

  Widget _columnHeader(String title, int count, TextTheme tt) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Text(title, style: tt.labelSmall?.copyWith(color: const Color(0xFF948F99), fontWeight: FontWeight.w600, letterSpacing: 1)),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: const Color(0xFF948F99).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
        child: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF948F99))),
      ),
    ]),
  );

  Widget _taskCard(KanbanTask t, WidgetRef ref, ColorScheme cs) {
    return Dismissible(
      key: Key(t.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: const Color(0xFFE57373).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Color(0xFFE57373)),
      ),
      onDismissed: (_) => ref.read(kanbanProvider.notifier).remove(t.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.tag, style: TextStyle(color: t.tagColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(t.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ])),
          _statusChip(t, ref),
        ]),
      ),
    );
  }

  Widget _statusChip(KanbanTask t, WidgetRef ref) {
    final next = t.status == KanbanStatus.active ? KanbanStatus.done : t.status == KanbanStatus.backlog ? KanbanStatus.active : KanbanStatus.backlog;
    final icon = t.status == KanbanStatus.done ? Icons.refresh : Icons.arrow_forward;
    return GestureDetector(
      onTap: () => ref.read(kanbanProvider.notifier).moveTo(t.id, next),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: t.tagColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 16, color: t.tagColor),
      ),
    );
  }

  Widget _emptyState(ColorScheme cs, TextTheme tt) => Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.view_kanban, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text('No tasks yet', style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text('Tap + to add your first task.', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ]),
    ),
  );

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final tagCtrl = TextEditingController();
    Color picked = const Color(0xFFC7B8EA);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
        title: const Text('New Task'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(hintText: 'Task title')),
          const SizedBox(height: 12),
          TextField(controller: tagCtrl, decoration: const InputDecoration(hintText: 'Tag (e.g. DEV)')),
          const SizedBox(height: 12),
          Row(children: [
            for (final c in [const Color(0xFFC7B8EA), const Color(0xFFEADD95), const Color(0xFF95D5B2), const Color(0xFFE57373)])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setDlg(() => picked = c),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(14), border: picked == c ? Border.all(color: Colors.white, width: 2) : null),
                  ),
                ),
              ),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final title = titleCtrl.text.trim();
            if (title.isEmpty) return;
            ref.read(kanbanProvider.notifier).add(title, tagCtrl.text.trim().isEmpty ? 'TASK' : tagCtrl.text.trim(), picked);
            Navigator.pop(ctx);
          }, child: const Text('Add')),
        ],
      )),
    );
  }
}