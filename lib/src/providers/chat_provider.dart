import "dart:convert";
import "package:flutter/foundation.dart";
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

enum ReasoningEffort {
  off('Off', 'none', 'Standard speed, no extended thinking'),
  low('Low', 'low', 'Light reasoning, fast responses (Default)'),
  medium('Medium', 'medium', 'Balanced reasoning and depth'),
  high('High', 'high', 'Deep multi-step reasoning analysis');

  final String label;
  final String value;
  final String description;
  const ReasoningEffort(this.label, this.value, this.description);
}

class WorkspaceItem {
  final String id;
  final String name;
  final String path;
  final bool isDefault;

  const WorkspaceItem({
    required this.id,
    required this.name,
    required this.path,
    this.isDefault = false,
  });
}

class ReasoningNotifier extends StateNotifier<ReasoningEffort> {
  final Ref ref;

  ReasoningNotifier(this.ref) : super(ReasoningEffort.low) {
    _loadFromBackend();
  }

  Future<void> _loadFromBackend() async {
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) return;
    try {
      final backendEffort = await conn.getReasoningEffort();
      final match = ReasoningEffort.values.firstWhere(
        (e) => e.value.toLowerCase() == backendEffort.toLowerCase() || e.label.toLowerCase() == backendEffort.toLowerCase(),
        orElse: () => ReasoningEffort.low,
      );
      state = match;
    } catch (_) {}
  }

  Future<void> setEffort(ReasoningEffort effort) async {
    state = effort;
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn != null) {
      await conn.setReasoningEffort(effort.value);
    }
  }
}

final reasoningEffortProvider = StateNotifierProvider<ReasoningNotifier, ReasoningEffort>((ref) {
  ref.watch(connectionProvider);
  return ReasoningNotifier(ref);
});

class WorkspaceNotifier extends StateNotifier<WorkspaceItem> {
  final Ref ref;

  WorkspaceNotifier(this.ref)
      : super(const WorkspaceItem(
          id: 'default',
          name: 'Workspace',
          path: '',
          isDefault: true,
        )) {
    _loadFromBackend();
    ref.listen<AsyncValue<HermesConnection?>>(connectionProvider, (prev, next) {
      if (next.valueOrNull != null) {
        _loadFromBackend();
      }
    });
  }

  Future<void> reload() => _loadFromBackend();

  Future<void> _loadFromBackend() async {
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) return;
    try {
      final cwd = await conn.getActiveWorkspaceCwd();
      final rawProjects = await conn.getProjectsList();

      final List<WorkspaceItem> loaded = [];
      if (rawProjects.isNotEmpty) {
        for (final p in rawProjects) {
          final id = p['id']?.toString() ?? p['name']?.toString() ?? 'proj';
          final name = p['name']?.toString() ?? 'Project';
          final path = p['path']?.toString() ?? p['root']?.toString() ?? '';
          if (path.isNotEmpty) {
            loaded.add(WorkspaceItem(
              id: id,
              name: name,
              path: path,
              isDefault: p['is_default'] == true || p['active'] == true,
            ));
          }
        }
      }

      if (cwd != null && cwd.isNotEmpty) {
        final existing = loaded.where((w) => w.path == cwd).firstOrNull;
        if (existing != null) {
          state = existing;
        } else {
          final folderName = cwd.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).lastOrNull ?? 'Workspace';
          final currentWs = WorkspaceItem(id: 'active', name: folderName, path: cwd, isDefault: true);
          loaded.insert(0, currentWs);
          state = currentWs;
        }
      } else if (loaded.isNotEmpty) {
        state = loaded.firstWhere((w) => w.isDefault, orElse: () => loaded.first);
      } else {
        // Fallback for connected remote daemon without explicit cwd
        state = const WorkspaceItem(
          id: 'remote',
          name: 'Remote Workspace',
          path: '.',
          isDefault: true,
        );
      }

      if (loaded.isNotEmpty) {
        ref.read(workspacesListProvider.notifier).state = loaded;
      }
    } catch (_) {}
  }

  Future<void> setWorkspace(WorkspaceItem ws) async {
    state = ws;
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn != null) {
      await conn.setActiveWorkspaceCwd(ws.path);
    }
  }
}

final workspacesListProvider = StateProvider<List<WorkspaceItem>>((ref) {
  return const [
    WorkspaceItem(
      id: 'default',
      name: 'Active Workspace',
      path: '',
      isDefault: true,
    ),
  ];
});

final activeWorkspaceProvider = StateNotifierProvider<WorkspaceNotifier, WorkspaceItem>((ref) {
  ref.watch(connectionProvider);
  return WorkspaceNotifier(ref);
});

final selectedModelProvider = StateProvider<String>((ref) {
  final modelsAsync = ref.watch(modelsProvider);
  return modelsAsync.when(
    data: (models) {
      final active = models.where((m) => m.enabled).toList();
      return active.isNotEmpty ? active.first.name : 'hermes-agent';
    },
    loading: () => '...',
    error: (_, _) => 'hermes-agent',
  );
});

final sessionsProvider =
    FutureProvider.family<List<SessionSummary>, String?>((ref, query) async {
      final conn = ref.watch(connectionProvider).valueOrNull;
      if (conn == null) return [];
      return conn.getSessions(query: query);
    });
final sessionsSearchQueryProvider = StateProvider<String>((ref) => "");
final inChatRoomProvider = StateProvider<bool>((ref) => false);

/// Set of session IDs that are currently actively generating / streaming responses
final generatingSessionsProvider = StateProvider<Set<String>>((ref) => <String>{});

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref ref;
  String? activeSessionId;
  final Map<String, List<ChatMessage>> _sessionCache = {};

  ChatNotifier(this.ref) : super([]);

  Future<void> sendMessage(String text, {String? sessionId}) async {
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) return;
    final model = ref.read(selectedModelProvider);

    final targetSession = (sessionId != null && sessionId.isNotEmpty)
        ? sessionId
        : (activeSessionId ?? conn.activeSessionId ?? 'temp_${const Uuid().v4()}');

    // Register active generation for this session ID
    ref.read(generatingSessionsProvider.notifier).update((s) => {...s, targetSession});

    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      role: MessageRole.user,
      content: text,
      timestamp: DateTime.now(),
    );
    final assistantId = const Uuid().v4();
    final assistantMsg = ChatMessage(
      id: assistantId,
      role: MessageRole.assistant,
      content: "",
      timestamp: DateTime.now(),
      isStreaming: true,
    );

    // Save into cache
    final existingInCache = _sessionCache[targetSession] ?? (activeSessionId == targetSession ? state : []);
    final updatedList = [...existingInCache, userMsg, assistantMsg];
    _sessionCache[targetSession] = updatedList;

    activeSessionId = targetSession;
    state = updatedList;

    final trimmedText = text.trim();
    if (trimmedText.startsWith('/')) {
      try {
        final out = await conn.executeSlashCommand(
          trimmedText,
          sessionId: targetSession.startsWith('temp_') ? null : targetSession,
        );
        final current = _sessionCache[targetSession] ?? state;
        final nextList = [
          for (final m in current)
            if (m.id == assistantId)
              m.copyWith(content: out.isNotEmpty ? out : "(command executed)", isStreaming: false)
            else
              m,
        ];
        _sessionCache[targetSession] = nextList;
        state = nextList;
      } catch (e) {
        final current = _sessionCache[targetSession] ?? state;
        final nextList = [
          for (final m in current)
            if (m.id == assistantId)
              m.copyWith(content: "Error executing command: $e", isStreaming: false)
            else
              m,
        ];
        _sessionCache[targetSession] = nextList;
        state = nextList;
      } finally {
        ref.read(generatingSessionsProvider.notifier).update((s) {
          final copy = Set<String>.from(s);
          copy.remove(targetSession);
          return copy;
        });
      }
      return;
    }

    try {
      await for (final chunk in conn.streamChat(text, model: model, sessionId: targetSession.startsWith('temp_') ? null : targetSession)) {
        final liveStoredId = conn.activeSessionId;
        final current = _sessionCache[targetSession] ?? state;
        final nextList = [
          for (final m in current)
            if (m.id == assistantId)
              m.copyWith(content: m.content + chunk, isStreaming: true)
            else
              m,
        ];
        _sessionCache[targetSession] = nextList;
        if (liveStoredId != null && liveStoredId != targetSession) {
          _sessionCache[liveStoredId] = nextList;
        }
        state = nextList;
      }

      final resolvedSessionId = conn.activeSessionId ?? targetSession;
      activeSessionId = resolvedSessionId;

      final finalCurrent = _sessionCache[targetSession] ?? state;
      final completedList = [
        for (final m in finalCurrent)
          if (m.id == assistantId) m.copyWith(isStreaming: false) else m,
      ];
      _sessionCache[targetSession] = completedList;
      _sessionCache[resolvedSessionId] = completedList;
      state = completedList;

      // Unregister generating
      ref.read(generatingSessionsProvider.notifier).update((s) => s.where((id) => id != targetSession && id != resolvedSessionId).toSet());

      // Refresh sessions in background so user sees updated message count / title
      ref.invalidate(sessionsProvider);
    } catch (e) {
      final current = _sessionCache[targetSession] ?? state;
      final errList = [
        for (final m in current)
          if (m.id == assistantId)
            m.copyWith(content: m.content.isEmpty ? "Error: $e" : "${m.content}\n\n[Error: $e]", isStreaming: false)
          else
            m,
      ];
      _sessionCache[targetSession] = errList;
      state = errList;
      ref.read(generatingSessionsProvider.notifier).update((s) => s.where((id) => id != targetSession).toSet());
    }
  }

  Future<void> stopGeneration({String? sessionId}) async {
    final conn = ref.read(connectionProvider).valueOrNull;
    final targetSession = (sessionId != null && sessionId.isNotEmpty)
        ? sessionId
        : (activeSessionId ?? conn?.activeSessionId);

    if (targetSession != null) {
      ref.read(generatingSessionsProvider.notifier).update((s) => s.where((id) => id != targetSession).toSet());

      try {
        await conn?.stopGeneration(sessionId: targetSession.startsWith('temp_') ? null : targetSession);
      } catch (e) {
        debugPrint("Error stopping generation: $e");
      }

      final current = _sessionCache[targetSession] ?? state;
      final stoppedList = [
        for (final m in current)
          if (m.isStreaming)
            m.copyWith(
              content: m.content.isEmpty ? "(Generation stopped)" : "${m.content} [Stopped]",
              isStreaming: false,
            )
          else
            m,
      ];
      _sessionCache[targetSession] = stoppedList;
      if (activeSessionId == targetSession) {
        state = stoppedList;
      }
    }
  }

  Future<void> loadSession(String sessionId, {bool forceReload = false}) async {
    activeSessionId = sessionId;
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) return;
    conn.activeSessionId = sessionId;

    final isGenerating = ref.read(generatingSessionsProvider).contains(sessionId);

    // If already in cache (and either generating or not forcing reload), display immediately
    if (_sessionCache.containsKey(sessionId) && _sessionCache[sessionId]!.isNotEmpty) {
      state = _sessionCache[sessionId]!;
      if (isGenerating && !forceReload) {
        return;
      }
    }

    try {
      final rawList = await conn.getSessionMessages(sessionId);

      // If generating started or active in progress, keep live stream intact!
      if (ref.read(generatingSessionsProvider).contains(sessionId) || state.any((m) => m.isStreaming)) {
        return;
      }

      final List<ChatMessage> loaded = [];
      for (final item in rawList) {
        final roleStr = item['role']?.toString().toLowerCase() ?? 'user';
        final role = roleStr == 'assistant'
            ? MessageRole.assistant
            : (roleStr == 'system'
                ? MessageRole.system
                : (roleStr == 'tool'
                    ? MessageRole.tool
                    : MessageRole.user));

        final content = item['content']?.toString() ?? '';
        final tsRaw = item['timestamp'];
        DateTime ts = DateTime.now();
        if (tsRaw is num) {
          ts = DateTime.fromMillisecondsSinceEpoch((tsRaw * 1000).toInt());
        } else if (tsRaw != null) {
          ts = DateTime.tryParse(tsRaw.toString()) ?? DateTime.now();
        }

        final toolName = item['tool_name']?.toString() ??
            item['toolName']?.toString() ??
            item['tool']?.toString() ??
            item['name']?.toString();
        final toolStatus = item['tool_status']?.toString() ?? item['status']?.toString();
        final toolInput = item['tool_input']?.toString() ??
            item['toolInput']?.toString() ??
            item['arguments']?.toString() ??
            (item['input'] != null ? jsonEncode(item['input']) : null);
        final toolOutput = item['tool_output']?.toString() ??
            item['toolOutput']?.toString() ??
            item['output']?.toString() ??
            item['result']?.toString();

        loaded.add(ChatMessage(
          id: item['id']?.toString() ?? item['message_uid']?.toString() ?? const Uuid().v4(),
          role: role,
          content: content,
          timestamp: ts,
          toolName: toolName,
          toolStatus: toolStatus,
          toolInput: toolInput,
          toolOutput: toolOutput,
        ));
      }
      if (loaded.isNotEmpty || !_sessionCache.containsKey(sessionId)) {
        _sessionCache[sessionId] = loaded;
        if (activeSessionId == sessionId) {
          state = loaded;
        }
      }
    } catch (_) {}
  }

  void clear() {
    activeSessionId = null;
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn != null) {
      conn.activeSessionId = null;
    }
    state = [];
  }
}

