import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:uuid/uuid.dart";
import "../models/chat_message.dart";
import "../services/hermes_connection.dart";
import "connection_provider.dart";
final chatMessagesProvider =
    StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
      return ChatNotifier(ref);
    });

final modelsProvider = FutureProvider<List<ModelConfig>>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return [];
  return conn.getModels();
});

final selectedModelProvider = StateProvider<String>((ref) {
  final modelsAsync = ref.watch(modelsProvider);
  return modelsAsync.when(
    data: (models) {
      final active = models.where((m) => m.enabled).toList();
      return active.isNotEmpty ? active.first.name : 'hermes-agent';
    },
    loading: () => '...',
    error: (_, __) => 'hermes-agent',
  );
});

final sessionsProvider =
    FutureProvider.family<List<SessionSummary>, String?>((ref, query) async {
      final conn = ref.watch(connectionProvider).valueOrNull;
      if (conn == null) return [];
      return conn.getSessions(query: query);
    });
final sessionsSearchQueryProvider = StateProvider<String>((ref) => "");
class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref ref;
  ChatNotifier(this.ref) : super([]);
  Future<void> sendMessage(String text) async {
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) return;
    final model = ref.read(selectedModelProvider);
    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      role: MessageRole.user,
      content: text,
      timestamp: DateTime.now(),
    );
    state = [...state, userMsg];
    final assistantId = const Uuid().v4();
    final assistantMsg = ChatMessage(
      id: assistantId,
      role: MessageRole.assistant,
      content: "",
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    state = [...state, assistantMsg];
    try {
      await for (final chunk in conn.streamChat(text, model: model)) {
        state = [
          for (final m in state)
            if (m.id == assistantId)
              m.copyWith(content: m.content + chunk, isStreaming: true)
            else
              m,
        ];
      }
      state = [
        for (final m in state)
          if (m.id == assistantId) m.copyWith(isStreaming: false) else m,
      ];
    } catch (e) {
      state = [
        for (final m in state)
          if (m.id == assistantId)
            m.copyWith(content: "Error: $e", isStreaming: false)
          else
            m,
      ];
    }
  }
}
