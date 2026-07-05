import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KanbanTask {
  final String id;
  final String title;
  final String tag;
  final Color tagColor;
  final KanbanStatus status;

  const KanbanTask({
    required this.id,
    required this.title,
    required this.tag,
    required this.tagColor,
    required this.status,
  });

  KanbanTask copyWith({String? title, String? tag, Color? tagColor, KanbanStatus? status}) =>
      KanbanTask(id: id, title: title ?? this.title, tag: tag ?? this.tag, tagColor: tagColor ?? this.tagColor, status: status ?? this.status);
}

enum KanbanStatus { active, backlog, done }

final kanbanProvider = StateNotifierProvider<KanbanNotifier, List<KanbanTask>>((ref) => KanbanNotifier());

class KanbanNotifier extends StateNotifier<List<KanbanTask>> {
  int _counter = 0;

  KanbanNotifier()
      : super([
          const KanbanTask(id: '1', title: 'Refine Typography System', tag: 'DESIGN', tagColor: Color(0xFFC7B8EA), status: KanbanStatus.active),
          const KanbanTask(id: '2', title: 'User Interview Synthesis', tag: 'RESEARCH', tagColor: Color(0xFFEADD95), status: KanbanStatus.active),
          const KanbanTask(id: '3', title: 'API Documentation Update', tag: 'DEV', tagColor: Color(0xFF95D5B2), status: KanbanStatus.backlog),
        ]);

  void add(String title, String tag, Color color) {
    _counter++;
    state = [
      ...state,
      KanbanTask(id: 'new_$_counter', title: title, tag: tag.toUpperCase(), tagColor: color, status: KanbanStatus.backlog),
    ];
  }

  void remove(String id) => state = state.where((t) => t.id != id).toList();

  void moveTo(String id, KanbanStatus status) {
    state = state.map((t) => t.id == id ? t.copyWith(status: status) : t).toList();
  }
}