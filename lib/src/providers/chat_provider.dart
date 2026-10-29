import "dart:async";
import "dart:convert";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:uuid/uuid.dart";
import "../models/chat_message.dart";
import "../services/hermes_connection.dart";
import "../services/device_executor_service.dart";
import "../services/accessibility_service.dart";
import "../services/shell_executor_service.dart";
import "../services/local_database_service.dart";
import "connection_provider.dart";
import "profiles_provider.dart";
final chatMessagesProvider =
    StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
      return ChatNotifier(ref);
    });
final chatProvider = chatMessagesProvider;

final modelsProvider = FutureProvider<List<ModelConfig>>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  final activeProfile = ref.watch(activeProfileProvider);
  if (conn == null) {
    final cached = await LocalDatabaseService.instance.getModels();
    return cached.map((m) => ModelConfig.fromJson(m)).toList();
  }
  conn.activeProfile = activeProfile;
  try {
    final remote = await conn.getModels(profile: activeProfile);
    if (remote.isNotEmpty && activeProfile == 'default') {
      unawaited(LocalDatabaseService.instance.saveModels(remote.map((m) => m.toJson()).toList()));
    }
    return remote;
  } catch (_) {
    if (activeProfile == 'default') {
      final cached = await LocalDatabaseService.instance.getModels();
      if (cached.isNotEmpty) {
        return cached.map((m) => ModelConfig.fromJson(m)).toList();
      }
    }
    rethrow;
  }
});

final profileModelsProvider =
    FutureProvider.family<List<ModelConfig>, String>((ref, profileId) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  final target = profileId.trim().isEmpty ? 'default' : profileId.trim();
  if (conn == null) {
    if (target == 'default') {
      final cached = await LocalDatabaseService.instance.getModels();
      return cached.map((m) => ModelConfig.fromJson(m)).toList();
    }
    return [];
  }
  final remote = await conn.getModels(profile: target);
  if (remote.isNotEmpty && target == 'default') {
    unawaited(LocalDatabaseService.instance.saveModels(remote.map((m) => m.toJson()).toList()));
  }
  return remote;
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
      final activeProfile = ref.watch(activeProfileProvider);
      if (conn == null) {
        return await LocalDatabaseService.instance.getSessions(query: query);
      }
      conn.activeProfile = activeProfile;
      try {
        final remote = await conn.getSessions(query: query);
        if (remote.isNotEmpty) {
          unawaited(LocalDatabaseService.instance.saveSessions(remote));
        }
        return remote;
      } catch (_) {
        return await LocalDatabaseService.instance.getSessions(query: query);
      }
    });
final sessionsSearchQueryProvider = StateProvider<String>((ref) => "");
final inChatRoomProvider = StateProvider<bool>((ref) => false);

/// Set of session IDs that are currently actively generating / streaming responses
final generatingSessionsProvider = StateProvider<Set<String>>((ref) => <String>{});

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref ref;
  String? activeSessionId;
  final Map<String, List<ChatMessage>> _sessionCache = {};
  String? _recentDeviceContext;
  final Set<String> _deviceCapabilityAnnounced = {};
  final Set<String> _shellCapabilityAnnounced = {};

  ChatNotifier(this.ref) : super([]);

  Future<void> sendMessage(String text, {String? sessionId}) async {
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) return;
    final model = ref.read(selectedModelProvider);
    final activeProfile = ref.read(activeProfileProvider);
    conn.activeProfile = activeProfile;

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

    unawaited(LocalDatabaseService.instance.saveMessage(targetSession, userMsg));
    unawaited(LocalDatabaseService.instance.updateSessionSnippet(targetSession, text));

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
- `/device shizuku` : Check status or authorize Shizuku Next shell bridge
- `/device shell <command>` : Execute Android shell command via Shizuku Next
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
        } else if (sub == 'shizuku' || sub == 'shell-status') {
          final status = await ShellExecutorService.getStatus();
          if (status.authorized) {
            res = MobileActionResult(
              success: true,
              action: 'check_shell',
              message: status.modeLabel,
              data: status.toJson(),
            );
          } else if (status.running) {
            final perm = await ShellExecutorService.requestPermission();
            final updated = await ShellExecutorService.getStatus();
            res = MobileActionResult(
              success: perm.granted,
              action: 'authorize_shell',
              message: perm.message,
              data: updated.toJson(),
            );
          } else {
            await ShellExecutorService.openManagerApp();
            res = MobileActionResult(
              success: false,
              action: 'check_shell',
              message: status.modeLabel,
              data: status.toJson(),
            );
          }
        } else if (sub == 'shell' || sub == 'adb') {
          res = await DeviceExecutorService.execute('adb_shell', {'command': arg});
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
        _recentDeviceContext = 'User just executed device action "${res.action}": ${res.message}';
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
      unawaited(LocalDatabaseService.instance.saveMessages(targetSession, nextList));
      unawaited(LocalDatabaseService.instance.updateSessionSnippet(targetSession, formatted));
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
        unawaited(LocalDatabaseService.instance.saveMessages(targetSession, nextList));
        unawaited(LocalDatabaseService.instance.updateSessionSnippet(targetSession, formatted));
      } catch (e) {
        final current = _sessionCache[targetSession] ?? state;
        final errMsg = "Error executing command: $e";
        final nextList = [
          for (final m in current)
            if (m.id == assistantId)
              m.copyWith(content: errMsg, isStreaming: false)
            else
              m,
        ];
        _sessionCache[targetSession] = nextList;
        state = nextList;
        unawaited(LocalDatabaseService.instance.saveMessages(targetSession, nextList));
        unawaited(LocalDatabaseService.instance.updateSessionSnippet(targetSession, errMsg));
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
        lowerText.contains('buka') ||
        lowerText.contains('open') ||
        lowerText.contains('youtube') ||
        lowerText.contains('whatsapp') ||
        lowerText.contains('wa ') ||
        lowerText.contains('kirim') ||
        lowerText.contains('send') ||
        lowerText.contains('vibrate') ||
        lowerText.contains('getar') ||
        lowerText.contains('clipboard') ||
        lowerText.contains('salin') ||
        lowerText.contains('tempel') ||
        lowerText.contains('layar') ||
        lowerText.contains('screen') ||
        lowerText.contains('klik') ||
        lowerText.contains('click') ||
        lowerText.contains('ketik') ||
        lowerText.contains('type') ||
        lowerText.contains('baterai') ||
        lowerText.contains('battery') ||
        lowerText.contains('notif') ||
        lowerText.contains('wifi') ||
        lowerText.contains('koneksi') ||
        lowerText.contains('telepon') ||
        lowerText.contains('call') ||
        lowerText.contains('sms') ||
        lowerText.contains('alarm') ||
        lowerText.contains('volume') ||
        lowerText.contains('senter') ||
        lowerText.contains('lampu') ||
        lowerText.contains('camera') ||
        lowerText.contains('kamera') ||
        lowerText.contains('adb') ||
        lowerText.contains('shell') ||
        lowerText.contains('shizuku') ||
        lowerText.contains('dumpsys') ||
        lowerText.contains('logcat') ||
        lowerText.contains('package') ||
        lowerText.contains('apk') ||
        lowerText.contains('install') ||
        lowerText.contains('uninstall') ||
        lowerText.contains('screenshot') ||
        lowerText.contains('screencap') ||
        lowerText.contains('ram') ||
        lowerText.contains('memori') ||
        lowerText.contains('proses') ||
        lowerText.contains('sistem');

    final buffer = StringBuffer(text);

    // 1. If recent local device action occurred, pass its context so LLM knows what happened
    if (_recentDeviceContext != null && _recentDeviceContext!.isNotEmpty) {
      buffer.write('\n\n[RECENT LOCAL DEVICE CONTEXT: $_recentDeviceContext]');
      _recentDeviceContext = null;
    }

    // 2. Announce device capabilities once per session, and only while the
    // corresponding service is active so the model never emits actions that
    // cannot run. The prompt stays in session history after the first send.
    if (isDeviceIntent) {
      final a11yAnnounced = _deviceCapabilityAnnounced.contains(targetSession);
      final a11yEnabled = a11yAnnounced ? true : await AccessibilityService.isEnabled();
      if (DeviceExecutorService.shouldAnnounceCapabilities(
        accessibilityEnabled: a11yEnabled,
        alreadyAnnounced: a11yAnnounced,
      )) {
        buffer.write('\n\n${DeviceExecutorService.deviceCapabilityPrompt}');
        _deviceCapabilityAnnounced.add(targetSession);
      }

      final shellAnnounced = _shellCapabilityAnnounced.contains(targetSession);
      final shellAuthorized = shellAnnounced ? true : await ShellExecutorService.isAuthorized();
      if (DeviceExecutorService.shouldAnnounceCapabilities(
        accessibilityEnabled: false,
        shellAuthorized: shellAuthorized,
        alreadyAnnounced: shellAnnounced,
      )) {
        buffer.write('\n\n${DeviceExecutorService.shellCapabilityPrompt}');
        _shellCapabilityAnnounced.add(targetSession);
      }
    }

    final textToSend = buffer.toString();

    try {
      await for (final chunk in conn.streamChat(
        textToSend,
        model: model,
        sessionId: targetSession.startsWith('temp_') ? null : targetSession,
        profile: activeProfile,
      )) {
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
      if (_deviceCapabilityAnnounced.contains(targetSession)) {
        _deviceCapabilityAnnounced.add(resolvedSessionId);
      }
      if (_shellCapabilityAnnounced.contains(targetSession)) {
        _shellCapabilityAnnounced.add(resolvedSessionId);
      }

      final finalCurrent = _sessionCache[targetSession] ?? state;
      var completedContent = finalCurrent.firstWhere((m) => m.id == assistantId, orElse: () => assistantMsg).content;

      final textWithoutThink = completedContent
          .replaceAll(RegExp(r'<(?:think|thinking)>[\s\S]*?(?:<\/(?:think|thinking)>|$)', caseSensitive: false), '')
          .trim();
      var mobileReqs = DeviceExecutorService.extractActions(completedContent);

      // Automated continuation: If the model generated thoughts (<think>) but stopped before emitting
      // conversational response text or mobile_action, prompt it once to complete its output.
      if (textWithoutThink.isEmpty && mobileReqs.isEmpty && completedContent.isNotEmpty) {
        const nudgePrompt =
            'You concluded your reasoning in <think>, but did not provide your response or mobile action block yet. '
            'Please directly provide your final response or output the ```mobile_action block now.';

        try {
          await for (final chunk in conn.streamChat(
            nudgePrompt,
            model: model,
            sessionId: resolvedSessionId.startsWith('temp_') ? null : resolvedSessionId,
            profile: activeProfile,
          )) {
            final liveList = _sessionCache[targetSession] ?? state;
            final nextList = [
              for (final m in liveList)
                if (m.id == assistantId)
                  m.copyWith(content: m.content + chunk, isStreaming: true)
                else
                  m,
            ];
            _sessionCache[targetSession] = nextList;
            _sessionCache[resolvedSessionId] = nextList;
            state = nextList;
          }

          final currentAfterNudge = _sessionCache[targetSession] ?? state;
          completedContent = currentAfterNudge.firstWhere((m) => m.id == assistantId, orElse: () => assistantMsg).content;
          mobileReqs = DeviceExecutorService.extractActions(completedContent);
        } catch (_) {}
      }

      final finalEffective = completedContent.trim().isEmpty
          ? "Empty response from provider. Check endpoint URL, API Key, and model quota in Model Configuration."
          : completedContent;
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

      String cleanAssistantText = finalEffective;

      if (mobileReqs.isNotEmpty) {
        // Strip out the raw mobile action code blocks from the conversational text
        for (final req in mobileReqs) {
          cleanAssistantText = cleanAssistantText.replaceAll(req.rawMatch, '').trim();
        }

        final toolCards = <ChatMessage>[];
        final feedbackList = <String>[];
        final informationalResults = <String>[];

        for (final req in mobileReqs) {
          final isSensitive = DeviceExecutorService.isSensitiveAction(req.action);
          if (isSensitive) {
            final summary = DeviceExecutorService.getActionSummary(req.action, req.params);
            feedbackList.add('Aksi "${req.action}" memerlukan izin pengguna.');
            toolCards.add(ChatMessage(
              id: const Uuid().v4(),
              role: MessageRole.tool,
              content: summary,
              toolName: 'mobile_${req.action}',
              toolStatus: 'pending_approval',
              toolInput: jsonEncode(req.params),
              toolOutput: summary,
              timestamp: DateTime.now(),
            ));
          } else {
            final actionRes = await DeviceExecutorService.execute(req.action, req.params);
            feedbackList.add(actionRes.message);

            if (actionRes.data != null && actionRes.data!.isNotEmpty) {
              informationalResults.add('[ACTION: ${req.action} RESULT: ${jsonEncode(actionRes.data)}]');
            }

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
        }

        HapticFeedback.mediumImpact();

        // Build clean user-facing response:
        // Never wrap normal conversational text in <think> tags!
        // If the model gave no text beside the action tag, provide the clean feedback summary.
        final thinkMatch = RegExp(r'<(?:think|thinking)>([\s\S]*?)<\/(?:think|thinking)>', caseSensitive: false)
            .firstMatch(cleanAssistantText);
        final actualUserText = cleanAssistantText
            .replaceAll(RegExp(r'<(?:think|thinking)>[\s\S]*?(?:<\/(?:think|thinking)>|$)', caseSensitive: false), '')
            .trim();

        if (actualUserText.isEmpty) {
          final fallbackSummary = feedbackList.join('\n');
          if (thinkMatch != null) {
            cleanAssistantText = '${thinkMatch.group(0)}\n$fallbackSummary';
          } else {
            cleanAssistantText = fallbackSummary;
          }
        }

        final updatedAssistantList = [
          for (final m in finalList)
            if (m.id == assistantId)
              m.copyWith(
                content: cleanAssistantText,
                isStreaming: false,
              )
            else
              m,
        ];

        finalList = [...updatedAssistantList, ...toolCards];

        // ReAct continuation: if the action produced informational data (e.g. read_screen, get_clipboard, etc.),
        // stream observation back to the model so it can formulate an informed reply!
        if (informationalResults.isNotEmpty) {
          final observationPrompt =
              "Observation from mobile execution:\n${informationalResults.join('\n')}\n"
              "Please provide a helpful, natural response to the user based on these device observation results.";

          final followUpAssistantId = const Uuid().v4();
          final followUpMsg = ChatMessage(
            id: followUpAssistantId,
            role: MessageRole.assistant,
            content: '',
            timestamp: DateTime.now(),
            isStreaming: true,
          );

          finalList = [...finalList, followUpMsg];
          _sessionCache[targetSession] = finalList;
          _sessionCache[resolvedSessionId] = finalList;
          state = finalList;

          try {
            await for (final chunk in conn.streamChat(
              observationPrompt,
              model: model,
              sessionId: resolvedSessionId.startsWith('temp_') ? null : resolvedSessionId,
              profile: activeProfile,
            )) {
              final liveList = _sessionCache[resolvedSessionId] ?? state;
              final nextContinuation = [
                for (final m in liveList)
                  if (m.id == followUpAssistantId)
                    m.copyWith(content: m.content + chunk, isStreaming: true)
                  else
                    m,
              ];
              _sessionCache[targetSession] = nextContinuation;
              _sessionCache[resolvedSessionId] = nextContinuation;
              state = nextContinuation;
            }

            // Mark continuation finished; remove if completely empty
            final currentAfterFollowUp = _sessionCache[resolvedSessionId] ?? state;
            final updatedFollowUp = currentAfterFollowUp.firstWhere(
              (m) => m.id == followUpAssistantId,
              orElse: () => followUpMsg,
            );

            if (updatedFollowUp.content.trim().isEmpty) {
              finalList = currentAfterFollowUp.where((m) => m.id != followUpAssistantId).toList();
            } else {
              finalList = [
                for (final m in currentAfterFollowUp)
                  if (m.id == followUpAssistantId)
                    m.copyWith(isStreaming: false)
                  else
                    m,
              ];
            }
          } catch (_) {
            final currentAfterFollowUp = _sessionCache[resolvedSessionId] ?? state;
            finalList = currentAfterFollowUp.where((m) => m.id != followUpAssistantId).toList();
          }
        }
      }

      _sessionCache[targetSession] = finalList;
      _sessionCache[resolvedSessionId] = finalList;
      state = finalList;

      unawaited(LocalDatabaseService.instance.saveMessages(resolvedSessionId, finalList));
      unawaited(LocalDatabaseService.instance.updateSessionSnippet(resolvedSessionId, cleanAssistantText));

      // Unregister generating
      ref.read(generatingSessionsProvider.notifier).update((s) => s.where((id) => id != targetSession && id != resolvedSessionId).toSet());

      // Refresh sessions in background so user sees updated message count / title
      ref.invalidate(sessionsProvider);

      // Only auto-reload from Hermes daemon if no local mobile actions were executed,
      // and only for valid backend session IDs (never temp_ IDs), so streamed replies are never wiped.
      if (mobileReqs.isEmpty &&
          !resolvedSessionId.startsWith('temp_') &&
          !finalEffective.startsWith('Empty response from provider') &&
          !finalEffective.contains('Kendala respon')) {
        Future.delayed(const Duration(milliseconds: 350), () {
          loadSession(resolvedSessionId, forceReload: true);
        });
      }
    } catch (e) {
      final current = _sessionCache[targetSession] ?? state;
      final errorText = e.toString().contains('SocketException') || e.toString().contains('Timeout')
          ? 'Connection to Hermes Gateway lost. Partial response saved. Please try sending again.'
          : 'Kendala respon: $e';
      final errList = [
        for (final m in current)
          if (m.id == assistantId)
            m.copyWith(
              content: m.content.isEmpty ? errorText : "${m.content}\n\n[$errorText]",
              isStreaming: false,
            )
          else
            m,
      ];
      _sessionCache[targetSession] = errList;
      state = errList;
      unawaited(LocalDatabaseService.instance.saveMessages(targetSession, errList));
      unawaited(LocalDatabaseService.instance.updateSessionSnippet(targetSession, errorText));

      final activeConnId = conn.activeSessionId;
      if (activeConnId != null && activeConnId != targetSession) {
        _sessionCache[activeConnId] = errList;
        unawaited(LocalDatabaseService.instance.saveMessages(activeConnId, errList));
        unawaited(LocalDatabaseService.instance.updateSessionSnippet(activeConnId, errorText));
      }

      ref.read(generatingSessionsProvider.notifier).update((s) => s.where((id) => id != targetSession && id != activeConnId).toSet());
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
      unawaited(LocalDatabaseService.instance.saveMessages(targetSession, stoppedList));
    }
  }

  static bool isSyntheticReActPrompt(String raw) {
    var content = raw;
    if (content.contains('[DEVICE CONTROL CAPABILITY]')) {
      content = content.split('[DEVICE CONTROL CAPABILITY]').first.trim();
    }
    if (content.contains('[PRIVILEGED SHELL CAPABILITY]')) {
      content = content.split('[PRIVILEGED SHELL CAPABILITY]').first.trim();
    }
    if (content.contains('[RECENT LOCAL DEVICE CONTEXT:')) {
      content = content.split('[RECENT LOCAL DEVICE CONTEXT:').first.trim();
    }
    if (content.contains('[INSTRUCTION:')) {
      content = content.split('[INSTRUCTION:').first.trim();
    }

    final trimmed = content.trim();
    if (trimmed.isEmpty) return true;

    final lower = trimmed.toLowerCase();
    return lower.startsWith("user approved mobile action") ||
           lower.startsWith("user declined/rejected the mobile action") ||
           lower.startsWith("user rejected the execution of mobile action") ||
           lower.startsWith("user declined the mobile action") ||
           lower.startsWith("observation from mobile execution:") ||
           lower.startsWith("you concluded your reasoning in <think>");
  }

  Future<void> loadSession(String sessionId, {bool forceReload = false}) async {
    activeSessionId = sessionId;

    final isGenerating = ref.read(generatingSessionsProvider).contains(sessionId);

    // 1. Immediately show from in-memory cache if available
    if (_sessionCache.containsKey(sessionId) && _sessionCache[sessionId]!.isNotEmpty) {
      final sanitizedMem = _sessionCache[sessionId]!.where((m) {
        if (m.role != MessageRole.user) return true;
        return !isSyntheticReActPrompt(m.content);
      }).toList();
      _sessionCache[sessionId] = sanitizedMem;
      state = sanitizedMem;
      if (isGenerating && !forceReload) {
        return;
      }
    } else {
      // 2. Instant 0ms load from SQLite offline database
      final localMsgs = await LocalDatabaseService.instance.getMessages(sessionId);
      if (localMsgs.isNotEmpty) {
        final sanitizedLocal = localMsgs.where((m) {
          if (m.role != MessageRole.user) return true;
          return !isSyntheticReActPrompt(m.content);
        }).toList();
        if (sanitizedLocal.isNotEmpty) {
          _sessionCache[sessionId] = sanitizedLocal;
          if (activeSessionId == sessionId) {
            state = sanitizedLocal;
          }
          if (isGenerating && !forceReload) {
            return;
          }
        }
      }
    }

    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) return;
    conn.activeSessionId = sessionId;

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
        if (role == MessageRole.user) {
          if (content.contains('[DEVICE CONTROL CAPABILITY]')) {
            content = content.split('[DEVICE CONTROL CAPABILITY]').first.trim();
          }
          if (content.contains('[PRIVILEGED SHELL CAPABILITY]')) {
            content = content.split('[PRIVILEGED SHELL CAPABILITY]').first.trim();
          }
          if (content.contains('[RECENT LOCAL DEVICE CONTEXT:')) {
            content = content.split('[RECENT LOCAL DEVICE CONTEXT:').first.trim();
          }
          if (content.contains('[INSTRUCTION:')) {
            content = content.split('[INSTRUCTION:').first.trim();
          }

          if (isSyntheticReActPrompt(content)) {
            final trimmed = content.trim();
            final lower = trimmed.toLowerCase();
            if (lower.startsWith("user approved mobile action")) {
              final actMatch = RegExp(r"user approved mobile action '([^']+)'", caseSensitive: false).firstMatch(trimmed);
              final actName = actMatch?.group(1);
              final resRegex = RegExp(r"Execution result:\n([\s\S]*?)(?:\nPlease formulate a natural response|$)", caseSensitive: false);
              final resMatch = resRegex.firstMatch(trimmed);
              final execOutput = resMatch?.group(1)?.trim();

              if (actName != null) {
                final existingIdx = loaded.lastIndexWhere((m) =>
                  m.role == MessageRole.tool &&
                  (m.toolName == 'mobile_$actName' || m.toolName == actName)
                );
                if (existingIdx != -1) {
                  loaded[existingIdx] = loaded[existingIdx].copyWith(
                    toolStatus: 'completed',
                    toolOutput: execOutput ?? loaded[existingIdx].toolOutput,
                  );
                }
              }
            } else if (lower.startsWith("user declined") || lower.startsWith("user rejected")) {
              final actMatch = RegExp(r"mobile action '([^']+)'", caseSensitive: false).firstMatch(trimmed);
              final actName = actMatch?.group(1);
              if (actName != null) {
                final existingIdx = loaded.lastIndexWhere((m) =>
                  m.role == MessageRole.tool &&
                  (m.toolName == 'mobile_$actName' || m.toolName == actName)
                );
                if (existingIdx != -1) {
                  loaded[existingIdx] = loaded[existingIdx].copyWith(
                    toolStatus: 'rejected',
                  );
                }
              }
            }
            continue;
          }
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

        final textWithoutThink = content.replaceAll(
          RegExp(r'<(?:think|thinking)>[\s\S]*?(?:<\/(?:think|thinking)>|$)', caseSensitive: false),
          '',
        ).trim();

        // If it's an assistant message with empty conversational text:
        if (role == MessageRole.assistant && textWithoutThink.isEmpty) {
          final hasToolCalls = (item['tool_calls'] is List && (item['tool_calls'] as List).isNotEmpty) ||
              (item['toolCalls'] is List && (item['toolCalls'] as List).isNotEmpty);
          // If it invoked tools, skip so it does not create a redundant bubble before the tool message
          if (hasToolCalls) {
            continue;
          }
          // If completely empty (no reasoning, no tool info), skip it
          if (content.trim().isEmpty && toolName == null && toolOutput == null) {
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
      // Never overwrite an already populated in-memory session with an empty server response
      // (e.g., if the backend is still flushing messages to SQLite or session is newly created).
      if (loaded.isNotEmpty || (_sessionCache[sessionId]?.isEmpty ?? true)) {
        final prevMessages = _sessionCache[sessionId] ?? state;

        bool isErrorOrFallback(String text) {
          final l = text.toLowerCase();
          return l.contains('kendala respon') ||
              l.contains('connection to hermes gateway') ||
              l.contains('empty response from provider') ||
              l.contains('error executing command') ||
              l.contains('(generation stopped)') ||
              l.contains('[stopped]') ||
              l.contains('model inference failed') ||
              l.contains('error:') ||
              l.contains('tidak ada respons dari model') ||
              l.contains('model menyelesaikan penalaran tanpa') ||
              l.startsWith('**device action:**') ||
              l.startsWith('**hermes mobile device executor**');
        }

        // 1. Preserve local mobile tool messages in cache
        final localMobileTools = prevMessages.where((m) =>
          m.role == MessageRole.tool && (m.toolName?.startsWith('mobile_') ?? false)
        ).toList();

        for (final mt in localMobileTools) {
          if (!loaded.any((m) => m.id == mt.id || (m.toolName == mt.toolName && m.toolInput == mt.toolInput))) {
            loaded.add(mt);
          }
        }

        // 2. Preserve local error details/suffixes on existing messages
        for (int i = 0; i < loaded.length; i++) {
          final sMsg = loaded[i];
          final match = prevMessages.where((m) => m.id == sMsg.id).firstOrNull;
          if (match != null && isErrorOrFallback(match.content)) {
            if (sMsg.content.isEmpty || match.content.contains(sMsg.content)) {
              loaded[i] = sMsg.copyWith(content: match.content);
            } else if (!sMsg.content.contains('Kendala respon') && match.content.contains('Kendala respon')) {
              loaded[i] = sMsg.copyWith(content: match.content);
            }
          }
        }

        // 3. Preserve missing assistant replies/errors if the server turn aborted before saving
        if (loaded.isNotEmpty && loaded.last.role == MessageRole.user && prevMessages.isNotEmpty) {
          final lastUserContent = loaded.last.content.trim();
          final prevUserIdx = prevMessages.lastIndexWhere(
            (m) => m.role == MessageRole.user && m.content.trim() == lastUserContent,
          );
          if (prevUserIdx != -1 && prevUserIdx + 1 < prevMessages.length) {
            for (int j = prevUserIdx + 1; j < prevMessages.length; j++) {
              final followUp = prevMessages[j];
              if (!loaded.any((m) => m.id == followUp.id)) {
                loaded.add(followUp);
              }
            }
          }
        }

        // 4. Ensure any standalone error or fallback assistant messages from prevMessages are retained
        for (final pMsg in prevMessages) {
          if (pMsg.role == MessageRole.assistant && isErrorOrFallback(pMsg.content)) {
            if (!loaded.any((m) => m.id == pMsg.id || m.content == pMsg.content)) {
              loaded.add(pMsg);
            }
          }
        }

        // 5. Ensure strict chronological order
        loaded.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        if (loaded.isNotEmpty) {
          _sessionCache[sessionId] = loaded;
          if (activeSessionId == sessionId) {
            state = loaded;
          }
          unawaited(LocalDatabaseService.instance.saveMessages(sessionId, loaded));
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
      if (text.contains('[PRIVILEGED SHELL CAPABILITY]')) {
        text = text.split('[PRIVILEGED SHELL CAPABILITY]').first.trim();
      }
      if (text.contains('[RECENT LOCAL DEVICE CONTEXT:')) {
        text = text.split('[RECENT LOCAL DEVICE CONTEXT:').first.trim();
      }
      if (text.contains('[INSTRUCTION:')) {
        text = text.split('[INSTRUCTION:').first.trim();
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

  Future<void> approveMobileAction(String messageId, {String? sessionId}) async {
    final conn = ref.read(connectionProvider).valueOrNull;
    final model = ref.read(selectedModelProvider);

    final targetSession = (sessionId != null && sessionId.isNotEmpty)
        ? sessionId
        : (activeSessionId ?? conn?.activeSessionId ?? 'temp_');

    final current = _sessionCache[targetSession] ?? state;
    final idx = current.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;

    final targetMsg = current[idx];
    if (targetMsg.toolStatus != 'pending_approval') return;

    // 1. Mark as running
    var workingList = List<ChatMessage>.from(current);
    workingList[idx] = targetMsg.copyWith(toolStatus: 'running');
    _sessionCache[targetSession] = workingList;
    if (activeSessionId == targetSession) state = workingList;

    // 2. Parse action and params
    final rawToolName = targetMsg.toolName ?? '';
    final action = rawToolName.startsWith('mobile_') ? rawToolName.substring(7) : rawToolName;
    Map<String, dynamic> params = {};
    if (targetMsg.toolInput != null) {
      try {
        final decoded = jsonDecode(targetMsg.toolInput!);
        if (decoded is Map<String, dynamic>) params = decoded;
      } catch (_) {}
    }

    // 3. Execute
    final res = await DeviceExecutorService.execute(action, params);
    HapticFeedback.mediumImpact();

    // 4. Update tool message status
    final current2 = _sessionCache[targetSession] ?? state;
    final idx2 = current2.indexWhere((m) => m.id == messageId);
    if (idx2 != -1) {
      workingList = List<ChatMessage>.from(current2);
      workingList[idx2] = workingList[idx2].copyWith(
        toolStatus: res.success ? 'completed' : 'failed',
        content: res.message,
        toolOutput: res.toString(),
      );
      _sessionCache[targetSession] = workingList;
      if (activeSessionId == targetSession) state = workingList;
      unawaited(LocalDatabaseService.instance.saveMessages(targetSession, workingList));
    }

    // 5. Send ReAct observation back to the LLM
    if (conn != null) {
      final observationPrompt =
          "User approved mobile action '$action'. Execution result:\n"
          "${res.message}\n"
          "${res.data != null ? jsonEncode(res.data) : ''}\n"
          "Please formulate a natural response to the user based on this outcome.";

      final followUpAssistantId = const Uuid().v4();
      final followUpMsg = ChatMessage(
        id: followUpAssistantId,
        role: MessageRole.assistant,
        content: '',
        timestamp: DateTime.now(),
        isStreaming: true,
      );

      final listBeforeContinuation = _sessionCache[targetSession] ?? state;
      final withFollowUp = [...listBeforeContinuation, followUpMsg];
      _sessionCache[targetSession] = withFollowUp;
      if (activeSessionId == targetSession) state = withFollowUp;

      try {
        await for (final chunk in conn.streamChat(
          observationPrompt,
          model: model,
          sessionId: targetSession.startsWith('temp_') ? null : targetSession,
        )) {
          final liveList = _sessionCache[targetSession] ?? state;
          final nextContinuation = [
            for (final m in liveList)
              if (m.id == followUpAssistantId)
                m.copyWith(content: m.content + chunk, isStreaming: true)
              else
                m,
          ];
          _sessionCache[targetSession] = nextContinuation;
          if (activeSessionId == targetSession) state = nextContinuation;
        }

        final liveListDone = _sessionCache[targetSession] ?? state;
        final updatedFollowUp = liveListDone.firstWhere(
          (m) => m.id == followUpAssistantId,
          orElse: () => followUpMsg,
        );

        List<ChatMessage> finishedContinuation;
        if (updatedFollowUp.content.trim().isEmpty) {
          finishedContinuation = [
            for (final m in liveListDone)
              if (m.id == followUpAssistantId)
                m.copyWith(
                  content: res.success
                      ? 'Aksi selesai: ${res.message}'
                      : 'Aksi mengalami kendala: ${res.message}',
                  isStreaming: false,
                )
              else
                m,
          ];
        } else {
          finishedContinuation = [
            for (final m in liveListDone)
              if (m.id == followUpAssistantId)
                m.copyWith(isStreaming: false)
              else
                m,
          ];
        }
        _sessionCache[targetSession] = finishedContinuation;
        if (activeSessionId == targetSession) state = finishedContinuation;
        unawaited(LocalDatabaseService.instance.saveMessages(targetSession, finishedContinuation));
      } catch (_) {
        final liveListErr = _sessionCache[targetSession] ?? state;
        final finishedContinuation = [
          for (final m in liveListErr)
            if (m.id == followUpAssistantId)
              m.copyWith(
                content: res.success
                    ? 'Aksi selesai: ${res.message}'
                    : 'Aksi mengalami kendala: ${res.message}',
                isStreaming: false,
              )
            else
              m,
        ];
        _sessionCache[targetSession] = finishedContinuation;
        if (activeSessionId == targetSession) state = finishedContinuation;
        unawaited(LocalDatabaseService.instance.saveMessages(targetSession, finishedContinuation));
      }
    }
  }

  Future<void> rejectMobileAction(String messageId, {String? sessionId}) async {
    final conn = ref.read(connectionProvider).valueOrNull;
    final model = ref.read(selectedModelProvider);

    final targetSession = (sessionId != null && sessionId.isNotEmpty)
        ? sessionId
        : (activeSessionId ?? 'default');

    final current = _sessionCache[targetSession] ?? state;
    final idx = current.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;

    final targetMsg = current[idx];
    final rawToolName = targetMsg.toolName ?? 'aksi';
    final action = rawToolName.startsWith('mobile_') ? rawToolName.substring(7) : rawToolName;

    var workingList = List<ChatMessage>.from(current);
    workingList[idx] = targetMsg.copyWith(
      toolStatus: 'rejected',
      content: 'Aksi $action dibatalkan oleh pengguna.',
      toolOutput: 'User rejected the action execution request.',
    );
    _sessionCache[targetSession] = workingList;
    if (activeSessionId == targetSession) state = workingList;
    unawaited(LocalDatabaseService.instance.saveMessages(targetSession, workingList));

    // Send observation back to model so it knows the action was canceled
    if (conn != null) {
      final rejectPrompt =
          "User declined/rejected the mobile action '$action'. "
          "Please acknowledge the cancellation and ask how you can help next.";

      final followUpAssistantId = const Uuid().v4();
      final followUpMsg = ChatMessage(
        id: followUpAssistantId,
        role: MessageRole.assistant,
        content: '',
        timestamp: DateTime.now(),
        isStreaming: true,
      );

      final withFollowUp = [...workingList, followUpMsg];
      _sessionCache[targetSession] = withFollowUp;
      if (activeSessionId == targetSession) state = withFollowUp;

      try {
        await for (final chunk in conn.streamChat(
          rejectPrompt,
          model: model,
          sessionId: targetSession.startsWith('temp_') ? null : targetSession,
        )) {
          final liveList = _sessionCache[targetSession] ?? state;
          final nextContinuation = [
            for (final m in liveList)
              if (m.id == followUpAssistantId)
                m.copyWith(content: m.content + chunk, isStreaming: true)
              else
                m,
          ];
          _sessionCache[targetSession] = nextContinuation;
          if (activeSessionId == targetSession) state = nextContinuation;
        }

        final liveListDone = _sessionCache[targetSession] ?? state;
        final updatedFollowUp = liveListDone.firstWhere(
          (m) => m.id == followUpAssistantId,
          orElse: () => followUpMsg,
        );

        List<ChatMessage> finishedList;
        if (updatedFollowUp.content.trim().isEmpty) {
          finishedList = [
            for (final m in liveListDone)
              if (m.id == followUpAssistantId)
                m.copyWith(
                  content: 'Aksi $action dibatalkan oleh pengguna.',
                  isStreaming: false,
                )
              else
                m,
          ];
        } else {
          finishedList = [
            for (final m in liveListDone)
              if (m.id == followUpAssistantId)
                m.copyWith(isStreaming: false)
              else
                m,
          ];
        }
        _sessionCache[targetSession] = finishedList;
        if (activeSessionId == targetSession) state = finishedList;
        unawaited(LocalDatabaseService.instance.saveMessages(targetSession, finishedList));
      } catch (_) {
        final liveListErr = _sessionCache[targetSession] ?? state;
        final finishedList = [
          for (final m in liveListErr)
            if (m.id == followUpAssistantId)
              m.copyWith(
                content: 'Aksi $action dibatalkan oleh pengguna.',
                isStreaming: false,
              )
            else
              m,
        ];
        _sessionCache[targetSession] = finishedList;
        if (activeSessionId == targetSession) state = finishedList;
        unawaited(LocalDatabaseService.instance.saveMessages(targetSession, finishedList));
      }
    }
  }

  Future<void> continueResponse({String? messageId, String? sessionId}) async {
    final targetSession = (sessionId != null && sessionId.isNotEmpty)
        ? sessionId
        : (activeSessionId ?? 'default');
    await sendMessage('Lanjutkan respon atau eksekusi aksi di perangkat sekarang.', sessionId: targetSession);
  }

  Future<void> retryLastMessage({String? sessionId}) async {
    final targetSession = (sessionId != null && sessionId.isNotEmpty)
        ? sessionId
        : (activeSessionId ?? 'default');
    final current = _sessionCache[targetSession] ?? state;
    final lastUserMsg = current.where((m) => m.role == MessageRole.user).lastOrNull;
    if (lastUserMsg != null && lastUserMsg.content.isNotEmpty) {
      await sendMessage(lastUserMsg.content, sessionId: targetSession);
    }
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

class ChatDraftsNotifier extends StateNotifier<Map<String, String>> {
  ChatDraftsNotifier() : super({}) {
    _loadFromPrefs();
  }

  static const _draftPrefix = 'chat_draft_';

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_draftPrefix));
      final map = <String, String>{};
      for (final k in keys) {
        final val = prefs.getString(k);
        if (val != null && val.isNotEmpty) {
          final sId = k.substring(_draftPrefix.length);
          map[sId] = val;
        }
      }
      if (mounted) {
        state = map;
      }
    } catch (_) {}
  }

  String getDraft(String? sessionId) {
    final key = (sessionId != null && sessionId.isNotEmpty) ? sessionId : 'new';
    return state[key] ?? '';
  }

  void setDraft(String? sessionId, String text) {
    final key = (sessionId != null && sessionId.isNotEmpty) ? sessionId : 'new';
    if (text.isEmpty) {
      if (state.containsKey(key)) {
        final next = Map<String, String>.from(state)..remove(key);
        state = next;
        SharedPreferences.getInstance().then((p) => p.remove('$_draftPrefix$key')).catchError((_) => false);
      }
    } else {
      if (state[key] != text) {
        final next = Map<String, String>.from(state)..[key] = text;
        state = next;
        SharedPreferences.getInstance().then((p) => p.setString('$_draftPrefix$key', text)).catchError((_) => false);
      }
    }
  }

  void clearDraft(String? sessionId) {
    final key = (sessionId != null && sessionId.isNotEmpty) ? sessionId : 'new';
    if (state.containsKey(key)) {
      final next = Map<String, String>.from(state)..remove(key);
      state = next;
      SharedPreferences.getInstance().then((p) => p.remove('$_draftPrefix$key')).catchError((_) => false);
    }
  }
}

final chatDraftsProvider =
    StateNotifierProvider<ChatDraftsNotifier, Map<String, String>>((ref) {
  return ChatDraftsNotifier();
});

