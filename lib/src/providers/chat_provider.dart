import "dart:convert";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:uuid/uuid.dart";
import "../models/chat_message.dart";
import "../services/hermes_connection.dart";
import "../services/device_executor_service.dart";
import "../services/accessibility_service.dart";
import "connection_provider.dart";
final chatMessagesProvider =
    StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
      return ChatNotifier(ref);
    });
final chatProvider = chatMessagesProvider;

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
    if (trimmedText.startsWith('/device') || trimmedText.startsWith('/mobile')) {
      final parts = trimmedText.split(RegExp(r'\s+'));
      final sub = parts.length > 1 ? parts[1].toLowerCase() : 'help';
      final arg = parts.length > 2 ? parts.sublist(2).join(' ') : '';

      String formatted;
      if (sub == 'help') {
        formatted = '''**Hermes Mobile Device Executor**
Native on-device actions (Cellular / Offline / No ADB needed):

- `/device a11y` : Check status or open Accessibility Service Settings
- `/device wa <phone> <message>` : Send WhatsApp message automatically
- `/device click <text>` : Click element on screen by text
- `/device type <text>` : Type text into focused input field
- `/device screen` : Read all visible UI text on current screen
- `/device info` : Show OS, device hardware, and platform info
- `/device network` : Check cellular (4G/5G) / Wi-Fi status
- `/device vibrate` : Trigger device haptic vibration
- `/device clipboard [text]` : Read or copy text to clipboard
- `/device open <app>` : Open app (youtube, whatsapp, maps, chrome, spotify)
- `/device open <url>` : Open web link in external browser''';
      } else {
        MobileActionResult res;
        if (sub == 'a11y' || sub == 'accessibility') {
          final isEnabled = await AccessibilityService.isEnabled();
          if (!isEnabled) {
            await AccessibilityService.openSettings();
            res = const MobileActionResult(
              success: true,
              action: 'enable_accessibility',
              message: 'Opened Accessibility Settings. Please turn on "Hermes Mobile Agent".',
            );
          } else {
            res = const MobileActionResult(
              success: true,
              action: 'check_accessibility',
              message: 'Hermes Accessibility Service is ACTIVE. Full zero-touch automation is ready.',
            );
          }
        } else if (sub == 'wa' || sub == 'whatsapp') {
          final subParts = arg.split(RegExp(r'\s+'));
          final phone = subParts.isNotEmpty ? subParts.first : '';
          final msg = subParts.length > 1 ? subParts.sublist(1).join(' ') : 'Halo';
          res = await DeviceExecutorService.execute('send_whatsapp', {'phone': phone, 'message': msg});
        } else if (sub == 'click') {
          res = await DeviceExecutorService.execute('click', {'text': arg});
        } else if (sub == 'type') {
          res = await DeviceExecutorService.execute('type', {'text': arg});
        } else if (sub == 'screen') {
          res = await DeviceExecutorService.execute('read_screen', {});
        } else if (sub == 'info') {
          res = await DeviceExecutorService.execute('get_device_info', {});
        } else if (sub == 'network' || sub == 'connectivity') {
          res = await DeviceExecutorService.execute('get_connectivity', {});
        } else if (sub == 'vibrate') {
          res = await DeviceExecutorService.execute('vibrate', {});
        } else if (sub == 'clipboard') {
          if (arg.isNotEmpty) {
            res = await DeviceExecutorService.execute('set_clipboard', {'text': arg});
          } else {
            res = await DeviceExecutorService.execute('get_clipboard', {});
          }
        } else if (sub == 'open') {
          res = await DeviceExecutorService.execute('open_app', {'target': arg});
        } else {
          res = await DeviceExecutorService.execute(sub, {'target': arg});
        }

        final statusStr = res.success ? 'Success' : 'Failed';
        final dataStr = res.data != null
            ? '\n\n```json\n${const JsonEncoder.withIndent('  ').convert(res.data)}\n```'
            : '';
        formatted = '**Device Action:** `${res.action}` ($statusStr)\n${res.message}$dataStr';
      }

      final current = _sessionCache[targetSession] ?? state;
      final nextList = [
        for (final m in current)
          if (m.id == assistantId)
            m.copyWith(content: formatted, isStreaming: false)
          else
            m,
      ];
      _sessionCache[targetSession] = nextList;
      state = nextList;
      ref.read(generatingSessionsProvider.notifier).update((s) {
        final copy = Set<String>.from(s);
        copy.remove(targetSession);
        return copy;
      });
      return;
    }

    if (trimmedText.startsWith('/')) {
      try {
        final out = await conn.executeSlashCommand(
          trimmedText,
          sessionId: targetSession.startsWith('temp_') ? null : targetSession,
        );
        final formatted = out.isNotEmpty
            ? "**Command:** `$trimmedText`\n\n```text\n$out\n```"
            : "**Command:** `$trimmedText`\n\n*(Command executed with no output)*";
        final current = _sessionCache[targetSession] ?? state;
        final nextList = [
          for (final m in current)
            if (m.id == assistantId)
              m.copyWith(content: formatted, isStreaming: false)
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

    final lowerText = text.toLowerCase();
    final isDeviceIntent = lowerText.contains('hp') ||
        lowerText.contains('hape') ||
        lowerText.contains('phone') ||
        lowerText.contains('device') ||
        lowerText.contains('buka ') ||
        lowerText.contains('open ') ||
        lowerText.contains('youtube') ||
        lowerText.contains('whatsapp') ||
        lowerText.contains('vibrate') ||
        lowerText.contains('getar') ||
        lowerText.contains('clipboard');

    final textToSend = isDeviceIntent
        ? '$text\n\n${DeviceExecutorService.deviceCapabilityPrompt}'
        : text;

    try {
      await for (final chunk in conn.streamChat(textToSend, model: model, sessionId: targetSession.startsWith('temp_') ? null : targetSession)) {
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
      final completedContent = finalCurrent.firstWhere((m) => m.id == assistantId, orElse: () => assistantMsg).content;
      final finalEffective = completedContent.trim().isEmpty
          ? "Respon kosong dari provider. Periksa endpoint URL, API Key, dan kuota model Anda di Model Configuration."
          : completedContent;

      // Detect and execute any embedded mobile action(s)
      final mobileReqs = DeviceExecutorService.extractActions(finalEffective);
      List<ChatMessage> finalList = [
        for (final m in finalCurrent)
          if (m.id == assistantId)
            m.copyWith(
              content: finalEffective,
              isStreaming: false,
            )
          else
            m,
      ];

      if (mobileReqs.isNotEmpty) {
        // Separate out internal monologue
        String rawMonologue = finalEffective;
        for (final req in mobileReqs) {
          rawMonologue = rawMonologue.replaceAll(req.rawMatch, '').trim();
        }

        final toolCards = <ChatMessage>[];
        final feedbackList = <String>[];

        for (final req in mobileReqs) {
          final actionRes = await DeviceExecutorService.execute(req.action, req.params);
          feedbackList.add(actionRes.message);
          toolCards.add(ChatMessage(
            id: const Uuid().v4(),
            role: MessageRole.tool,
            content: actionRes.message,
            toolName: 'mobile_${req.action}',
            toolStatus: actionRes.success ? 'completed' : 'failed',
            toolInput: jsonEncode(req.params),
            toolOutput: actionRes.toString(),
            timestamp: DateTime.now(),
          ));
        }

        HapticFeedback.mediumImpact();

        // Build clean user-facing response:
        // Raw internal monologue is wrapped in <think> so Thought Process shows it properly
        String finalAssistantText = "";
        if (rawMonologue.isNotEmpty) {
          if (!rawMonologue.contains('<think>') && !rawMonologue.contains('<thinking>')) {
            finalAssistantText = '<think>$rawMonologue</think>\n\n';
          } else {
            finalAssistantText = '$rawMonologue\n\n';
          }
        }

        final feedbackSummary = feedbackList.join('\n');
        finalAssistantText += feedbackSummary;

        final updatedAssistantList = [
          for (final m in finalList)
            if (m.id == assistantId)
              m.copyWith(
                content: finalAssistantText,
                isStreaming: false,
              )
            else
              m,
        ];

        finalList = [...updatedAssistantList, ...toolCards];
      }

      _sessionCache[targetSession] = finalList;
      _sessionCache[resolvedSessionId] = finalList;
      state = finalList;

      // Unregister generating
      ref.read(generatingSessionsProvider.notifier).update((s) => s.where((id) => id != targetSession && id != resolvedSessionId).toSet());

      // Refresh sessions in background so user sees updated message count / title
      ref.invalidate(sessionsProvider);

      // Only auto-reload from Hermes daemon if no local mobile actions were executed,
      // so local mobile tool cards and feedback are never overwritten
      if (mobileReqs.isEmpty) {
        Future.delayed(const Duration(milliseconds: 350), () {
          loadSession(resolvedSessionId, forceReload: true);
        });
      }
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

      // 1. Pre-index all tool_calls from assistant messages
      final Map<String, Map<String, String>> toolCallsLookup = {};
      final List<Map<String, String>> orderedToolCalls = [];

      for (final item in rawList) {
        final toolCalls = item['tool_calls'] ?? item['toolCalls'] ?? item['function_calls'];
        if (toolCalls is List) {
          for (final tc in toolCalls) {
            if (tc is Map) {
              final id = tc['id']?.toString() ?? tc['tool_call_id']?.toString() ?? tc['call_id']?.toString();
              final fn = tc['function'] is Map ? (tc['function'] as Map) : tc;
              final name = fn['name']?.toString() ?? fn['tool']?.toString() ?? 'tool';
              final args = fn['arguments']?.toString() ?? (fn['input'] != null ? jsonEncode(fn['input']) : '');
              final info = {'name': name, 'input': args};
              if (id != null && id.isNotEmpty) {
                toolCallsLookup[id] = info;
              }
              orderedToolCalls.add(info);
            }
          }
        }
      }

      final List<ChatMessage> loaded = [];
      int toolCallCursor = 0;

      for (final item in rawList) {
        final roleStr = item['role']?.toString().toLowerCase() ?? 'user';
        final isToolMsg = roleStr == 'tool';
        final role = roleStr == 'assistant'
            ? MessageRole.assistant
            : (roleStr == 'system'
                ? MessageRole.system
                : (isToolMsg
                    ? MessageRole.tool
                    : MessageRole.user));

        var content = item['content']?.toString() ?? '';
        if (role == MessageRole.user && content.contains('[DEVICE CONTROL CAPABILITY]')) {
          content = content.split('[DEVICE CONTROL CAPABILITY]').first.trim();
        }
        final reasoning = item['reasoning']?.toString() ??
            item['reasoning_content']?.toString() ??
            item['thought']?.toString() ??
            item['thinking']?.toString();

        if (reasoning != null && reasoning.isNotEmpty && !content.contains('<think>') && !content.contains('<thinking>')) {
          content = '<think>$reasoning</think>\n$content';
        }

        // Preserve thinking content from memory/stream if server messages don't embed think tags
        if (role == MessageRole.assistant && !content.contains('<think>') && !content.contains('<thinking>')) {
          final idMatch = item['id']?.toString() ?? item['message_uid']?.toString();
          final existing = state.where((m) =>
            m.role == MessageRole.assistant &&
            ((idMatch != null && m.id == idMatch) || m.content.contains('<think>') || m.content.contains('<thinking>'))
          ).lastOrNull;

          if (existing != null) {
            final thinkMatch = RegExp(r'<(?:think|thinking)>([\s\S]*?)<\/(?:think|thinking)>', caseSensitive: false)
                .firstMatch(existing.content);
            if (thinkMatch != null) {
              content = '${thinkMatch.group(0)}\n$content';
            }
          }
        }

        final tsRaw = item['timestamp'];
        DateTime ts = DateTime.now();
        if (tsRaw is num) {
          ts = DateTime.fromMillisecondsSinceEpoch((tsRaw * 1000).toInt());
        } else if (tsRaw != null) {
          ts = DateTime.tryParse(tsRaw.toString()) ?? DateTime.now();
        }

        final callId = item['tool_call_id']?.toString() ?? item['call_id']?.toString() ?? item['tool_id']?.toString();
        Map<String, String>? matchingCall = callId != null ? toolCallsLookup[callId] : null;
        if (matchingCall == null && isToolMsg && toolCallCursor < orderedToolCalls.length) {
          matchingCall = orderedToolCalls[toolCallCursor++];
        }

        final toolName = item['tool_name']?.toString() ??
            item['toolName']?.toString() ??
            item['tool']?.toString() ??
            item['name']?.toString() ??
            matchingCall?['name'];
        final toolStatus = item['tool_status']?.toString() ?? item['status']?.toString();
        final toolInput = item['tool_input']?.toString() ??
            item['toolInput']?.toString() ??
            item['arguments']?.toString() ??
            (item['input'] != null ? jsonEncode(item['input']) : null) ??
            matchingCall?['input'];
        final toolOutput = item['tool_output']?.toString() ??
            item['toolOutput']?.toString() ??
            item['output']?.toString() ??
            item['result']?.toString() ??
            (isToolMsg ? content : null);

        // If it's an assistant message with empty text and has tool_calls,
        // skip it so it does not create a redundant/duplicate bubble with the tool message below it
        if (role == MessageRole.assistant && content.trim().isEmpty) {
          final hasToolCalls = (item['tool_calls'] is List && (item['tool_calls'] as List).isNotEmpty) ||
              (item['toolCalls'] is List && (item['toolCalls'] as List).isNotEmpty);
          if (hasToolCalls) {
            continue;
          }
        }

        final messageContent = content;

        loaded.add(ChatMessage(
          id: item['id']?.toString() ?? item['message_uid']?.toString() ?? const Uuid().v4(),
          role: role,
          content: messageContent,
          timestamp: ts,
          toolName: toolName,
          toolStatus: toolStatus,
          toolInput: toolInput,
          toolOutput: toolOutput,
        ));
      }
      if (loaded.isNotEmpty || !_sessionCache.containsKey(sessionId)) {
        // Preserve any local mobile tool messages in cache
        final prevMessages = _sessionCache[sessionId] ?? state;
        final localMobileTools = prevMessages.where((m) =>
          m.role == MessageRole.tool && (m.toolName?.startsWith('mobile_') ?? false)
        ).toList();

        for (final mt in localMobileTools) {
          if (!loaded.any((m) => m.id == mt.id || (m.toolName == mt.toolName && m.toolInput == mt.toolInput))) {
            loaded.add(mt);
          }
        }

        _sessionCache[sessionId] = loaded;
        if (activeSessionId == sessionId) {
          state = loaded;
        }
      }
    } catch (_) {}
  }

  String? getLatestSnippetForSession(String sessionId) {
    final list = _sessionCache[sessionId] ?? (activeSessionId == sessionId ? state : null);
    if (list == null || list.isEmpty) return null;

    for (int i = list.length - 1; i >= 0; i--) {
      final msg = list[i];
      if (msg.role == MessageRole.system || msg.role == MessageRole.tool) continue;

      String text = msg.content;
      if (text.contains('[DEVICE CONTROL CAPABILITY]')) {
        text = text.split('[DEVICE CONTROL CAPABILITY]').first.trim();
      }
      text = text.replaceAll(RegExp(r'<think>[\s\S]*?(?:</think>|$)', caseSensitive: false), '').trim();
      text = text.replaceAll(RegExp(r'<tool_call>[\s\S]*?(?:</tool_call>|$)', caseSensitive: false), '').trim();
      text = text.replaceAll(RegExp(r'<tool[^>]*>[\s\S]*?(?:</tool>|$)', caseSensitive: false), '').trim();
      text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '[code]').trim();
      text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

      if (text.isNotEmpty) {
        final prefix = msg.role == MessageRole.assistant ? 'Pixie: ' : 'You: ';
        return '$prefix$text';
      }
    }
    return null;
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

