import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../models/chat_message.dart";
import "../../providers/chat_provider.dart";
import "../../providers/connection_provider.dart";
import "../../services/hermes_connection.dart";
import "../../theme.dart";
import "../widgets/chat_bubble.dart";
import "../widgets/vibe_mode_view.dart";

class _SlashCommandDef {
  final String command;
  final String label;
  final String description;
  final IconData icon;

  const _SlashCommandDef({
    required this.command,
    required this.label,
    required this.description,
    required this.icon,
  });
}

final List<_SlashCommandDef> _allSlashCommands = [
  _SlashCommandDef(
    command: "/status",
    label: "Gateway Status",
    description: "Check live daemon, session & provider state",
    icon: Icons.monitor_heart_rounded,
  ),
  _SlashCommandDef(
    command: "/compact",
    label: "Compact Context",
    description: "Summarize & compress active context memory",
    icon: Icons.compress_rounded,
  ),
  _SlashCommandDef(
    command: "/plan",
    label: "Plan Mode",
    description: "Formulate step-by-step strategy for the task",
    icon: Icons.assignment_outlined,
  ),
  _SlashCommandDef(
    command: "/goal",
    label: "Set Goal",
    description: "Define session goal and execution boundaries",
    icon: Icons.flag_rounded,
  ),
  _SlashCommandDef(
    command: "/skills",
    label: "Skills & Hub",
    description: "Review, approve or inspect agent skills",
    icon: Icons.auto_awesome_rounded,
  ),
  _SlashCommandDef(
    command: "/queue",
    label: "Task Queue",
    description: "Inspect queued commands & background jobs",
    icon: Icons.queue_rounded,
  ),
  _SlashCommandDef(
    command: "/undo",
    label: "Undo Turn",
    description: "Revert the last message and tool turn",
    icon: Icons.undo_rounded,
  ),
  _SlashCommandDef(
    command: "/clear",
    label: "Clear History",
    description: "Reset current conversation messages",
    icon: Icons.delete_sweep_rounded,
  ),
  _SlashCommandDef(
    command: "/model",
    label: "Change Model",
    description: "Switch active LLM inference model",
    icon: Icons.tune_rounded,
  ),
  _SlashCommandDef(
    command: "/memory",
    label: "Memory Editor",
    description: "View and edit agent persistent memory",
    icon: Icons.psychology_rounded,
  ),
  _SlashCommandDef(
    command: "/soul",
    label: "Soul & Persona",
    description: "Configure persona, style & system prompt",
    icon: Icons.face_rounded,
  ),
  _SlashCommandDef(
    command: "/capabilities",
    label: "Capabilities & Tools",
    description: "Inspect active tools and agent permissions",
    icon: Icons.handyman_rounded,
  ),
  _SlashCommandDef(
    command: "/approval",
    label: "Command Approval",
    description: "Preview dangerous command execution approval card",
    icon: Icons.shield_outlined,
  ),
  _SlashCommandDef(
    command: "/help",
    label: "Help & Commands",
    description: "View all commands and quick shortcuts",
    icon: Icons.help_outline_rounded,
  ),
];

class _PromptSuggestion {
  final IconData icon;
  final String title;
  final String subtitle;
  final String prompt;

  const _PromptSuggestion({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.prompt,
  });
}

const List<_PromptSuggestion> _allPromptSuggestions = [
  _PromptSuggestion(
    icon: Icons.lightbulb_outline_rounded,
    title: "Brainstorm Ideas",
    subtitle: "Creative concepts & project architectures",
    prompt: "Brainstorm 5 innovative feature ideas for my project",
  ),
  _PromptSuggestion(
    icon: Icons.code_rounded,
    title: "Write & Debug Code",
    subtitle: "Flutter widgets, APIs, or bug fixes",
    prompt: "Help me build and optimize a Flutter widget",
  ),
  _PromptSuggestion(
    icon: Icons.schedule_rounded,
    title: "Cron & Automation",
    subtitle: "Setup automated background cron schedules",
    prompt: "How do I configure a recurring cron schedule in Hermes?",
  ),
  _PromptSuggestion(
    icon: Icons.bug_report_outlined,
    title: "Find & Fix Bugs",
    subtitle: "Analyze runtime errors and stack traces",
    prompt: "Analyze my recent code changes and help me identify potential bugs or regressions",
  ),
  _PromptSuggestion(
    icon: Icons.speed_rounded,
    title: "Optimize Performance",
    subtitle: "Memory leaks, frame drops, and query speeds",
    prompt: "Give me actionable tips to optimize app rendering performance and reduce memory usage",
  ),
  _PromptSuggestion(
    icon: Icons.terminal_rounded,
    title: "Shell & CLI Scripts",
    subtitle: "Terminal commands, bash scripts, and automation",
    prompt: "Write a bash script to automate project build, testing, and deployment",
  ),
  _PromptSuggestion(
    icon: Icons.data_object_rounded,
    title: "API & Data Schema",
    subtitle: "REST models, JSON serialization, and endpoints",
    prompt: "Design a clean REST API payload and Dart model with json serialization",
  ),
  _PromptSuggestion(
    icon: Icons.security_rounded,
    title: "Security & Auth Audit",
    subtitle: "API keys, token headers, and vulnerability checks",
    prompt: "Audit my authentication flow and suggest security hardening best practices",
  ),
  _PromptSuggestion(
    icon: Icons.palette_outlined,
    title: "UI/UX Enhancements",
    subtitle: "Modern glassmorphism, neumorphism, and tokens",
    prompt: "Suggest visual improvements and micro-animations to make this screen feel more premium",
  ),
  _PromptSuggestion(
    icon: Icons.checklist_rounded,
    title: "Unit & Widget Tests",
    subtitle: "Mocks, test coverage, and assertions",
    prompt: "Write comprehensive unit test cases covering edge cases for my state provider",
  ),
  _PromptSuggestion(
    icon: Icons.account_tree_outlined,
    title: "Architecture Review",
    subtitle: "State management, clean layers, and separation",
    prompt: "Review my current project structure and recommend clean architecture improvements",
  ),
  _PromptSuggestion(
    icon: Icons.merge_type_rounded,
    title: "Git & Release Workflow",
    subtitle: "Branching strategies, changelogs, and tags",
    prompt: "Generate a conventional commit guideline and automated release workflow",
  ),
  _PromptSuggestion(
    icon: Icons.psychology_outlined,
    title: "Deep Reasoning Analysis",
    subtitle: "Complex algorithmic trade-offs & problem solving",
    prompt: "Explain the algorithmic trade-offs between different caching strategies for mobile",
  ),
  _PromptSuggestion(
    icon: Icons.storage_rounded,
    title: "Database Optimization",
    subtitle: "Indexing, relational queries, and migrations",
    prompt: "How can I structure database indexes to optimize slow relational queries?",
  ),
];

final Set<String> _globallyResolvedApprovals = {};

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String? title;
  final String? sessionId;

  const ChatRoomScreen({super.key, this.title, this.sessionId});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _streaming = false;
  bool _loadingSession = false;
  PlatformFile? _attachment;
  bool _dismissedApproval = false;
  Map<String, String>? _manualApproval;
  late String _sessionTitle;
  bool _isVibeMode = false;
  String? _activeCwd;
  List<_PromptSuggestion> _activeSuggestions = [];

  void _randomizeSuggestions() {
    final list = List<_PromptSuggestion>.from(_allPromptSuggestions)..shuffle();
    _activeSuggestions = list.take(3).toList();
  }

  @override
  void initState() {
    super.initState();
    _randomizeSuggestions();
    _sessionTitle = widget.title ?? "Hermes Agent";
    _ctrl.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCwd();
      if (widget.sessionId != null && widget.sessionId!.isNotEmpty) {
        _loadSession();
      }
    });
  }

  Future<void> _loadCwd() async {
    final activeWs = ref.read(activeWorkspaceProvider);
    if (activeWs.path.isNotEmpty) {
      if (mounted) setState(() => _activeCwd = activeWs.path);
      return;
    }
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn != null) {
      try {
        final cwd = await conn.getActiveWorkspaceCwd();
        if (cwd != null && cwd.isNotEmpty && mounted) {
          setState(() => _activeCwd = cwd);
        }
      } catch (_) {}
    }
  }

  @override
  void didUpdateWidget(ChatRoomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.title != oldWidget.title && widget.title != null) {
      _sessionTitle = widget.title!;
    }
  }

  Future<void> _loadSession() async {
    if (!mounted) return;
    final sId = widget.sessionId;
    if (sId == null || sId.isEmpty) return;

    final notifier = ref.read(chatMessagesProvider.notifier);
    final isGenerating = ref.read(generatingSessionsProvider).contains(sId);

    // If this session is already loaded in memory (or generating in background), do NOT wipe!
    if (notifier.activeSessionId == sId && ref.read(chatMessagesProvider).isNotEmpty) {
      _jumpToLatest();
      return;
    }

    setState(() => _loadingSession = true);
    try {
      if (!isGenerating && notifier.activeSessionId != sId) {
        notifier.clear();
      }
      await notifier.loadSession(sId);
    } catch (e) {
      debugPrint("Error loading session: $e");
    } finally {
      if (mounted) {
        setState(() => _loadingSession = false);
        _jumpToLatest();
      }
    }
  }

  void _jumpToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(0.0);
      }
    });
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        setState(() {
          _attachment = res.files.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to pick file: $e")),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, String>? _detectPendingApproval(List<ChatMessage> messages) {
    if (_dismissedApproval) return null;
    if (_manualApproval != null) return _manualApproval;

    if (messages.isEmpty) return null;
    final lastMsg = messages.last;
    // An approval is ONLY pending if the latest conversation message is from the assistant
    if (lastMsg.role != MessageRole.assistant || lastMsg.isStreaming) {
      return null;
    }

    if (lastMsg.id.isNotEmpty && _globallyResolvedApprovals.contains(lastMsg.id)) {
      return null;
    }

    final content = lastMsg.content;
    final lower = content.toLowerCase();

    // Ignore conversational explanations / examples about approvals
    if (lower.contains("contoh bentuk") ||
        lower.contains("contoh approval") ||
        lower.contains("ini hanya contoh") ||
        lower.contains("contoh tampilan")) {
      return null;
    }

    final requiresApproval = content.contains("confirm_required") ||
        lower.contains("approval required") ||
        lower.contains("requires approval") ||
        lower.contains("requires confirmation") ||
        (lower.contains("permission to run") && content.contains("?")) ||
        (lower.contains("execute the following command") && content.contains("?")) ||
        (lower.contains("[approve]") && (lower.contains("[reject]") || lower.contains("[deny]")));

    if (!requiresApproval) return null;

    var command = RegExp(r'`([^`]+)`').firstMatch(content)?.group(1);
    if (command == null || command.isEmpty) {
      final reqMatch = RegExp(r'(?:Request|Command):\s*([a-zA-Z0-9_\-\./]+)', caseSensitive: false).firstMatch(content);
      command = reqMatch?.group(1);
    }
    if (command == null || command.isEmpty) {
      final deployMatch = RegExp(r'(deploy[a-zA-Z0-9_\-\./]*)', caseSensitive: false).firstMatch(content);
      command = deployMatch?.group(1);
    }

    return {
      'id': lastMsg.id,
      'message': content.length > 200 ? '${content.substring(0, 200)}...' : content,
      if (command != null && command.isNotEmpty) 'command': command,
    };
  }

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    final generating = ref.read(generatingSessionsProvider);
    final isGenerating = _streaming ||
        (widget.sessionId != null && generating.contains(widget.sessionId)) ||
        ref.read(chatMessagesProvider).any((m) => m.isStreaming);

    if ((t.isEmpty && _attachment == null) || isGenerating) return;

    final att = _attachment;
    String fullMessage = t;
    if (att != null) {
      final sizeStr = _formatFileSize(att.size);
      if (fullMessage.isEmpty) {
        fullMessage = "[Attached File: ${att.name} ($sizeStr)]";
      } else {
        fullMessage = "[Attached File: ${att.name} ($sizeStr)]\n\n$fullMessage";
      }
    }

    _ctrl.clear();
    setState(() {
      _streaming = true;
      _attachment = null;
    });
    _scrollToBottom(immediate: true);
    try {
      await ref.read(chatMessagesProvider.notifier).sendMessage(fullMessage, sessionId: widget.sessionId);
    } finally {
      if (mounted) {
        setState(() => _streaming = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom({bool immediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        if (immediate || _scroll.offset < 300) {
          _scroll.jumpTo(0.0);
        } else {
          _scroll.animateTo(
            0.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  Future<void> _showRenameDialog() async {
    final editCtrl = TextEditingController(text: _sessionTitle);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HermesTokens.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Rename Session",
          style: TextStyle(
            color: HermesTokens.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Container(
          decoration: NeumorphicDecoration.recessed(radius: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: editCtrl,
            autofocus: true,
            style: const TextStyle(color: HermesTokens.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: "Enter session title...",
              hintStyle: TextStyle(color: HermesTokens.textMuted, fontSize: 14),
            ),
            onSubmitted: (val) {
              final trimmed = val.trim();
              Navigator.of(ctx).pop(trimmed.isNotEmpty ? trimmed : null);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel", style: TextStyle(color: HermesTokens.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: HermesTokens.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              final val = editCtrl.text.trim();
              Navigator.of(ctx).pop(val.isNotEmpty ? val : null);
            },
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && mounted) {
      setState(() => _sessionTitle = newName);
      final sId = widget.sessionId;
      if (sId != null && sId.isNotEmpty) {
        final conn = ref.read(connectionProvider).valueOrNull;
        if (conn != null) {
          try {
            await conn.renameSession(sId, newName);
            ref.invalidate(sessionsProvider);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Failed to rename session: $e"),
                  backgroundColor: HermesTokens.error,
                ),
              );
            }
          }
        }
      }
    }
  }

  Future<void> _confirmClearMessages() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HermesTokens.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Clear Messages?",
          style: TextStyle(
            color: HermesTokens.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          "Are you sure you want to clear active messages from the screen?",
          style: TextStyle(
            color: HermesTokens.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel", style: TextStyle(color: HermesTokens.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: HermesTokens.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Clear", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(chatMessagesProvider.notifier).clear();
    }
  }

  Future<void> _confirmDeleteSession() async {
    final sId = widget.sessionId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HermesTokens.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Delete Session?",
          style: TextStyle(
            color: HermesTokens.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to permanently delete "$_sessionTitle"? This cannot be undone.',
          style: const TextStyle(
            color: HermesTokens.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel", style: TextStyle(color: HermesTokens.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: HermesTokens.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      if (sId != null && sId.isNotEmpty) {
        final conn = ref.read(connectionProvider).valueOrNull;
        if (conn != null) {
          try {
            await conn.deleteSession(sId);
            ref.invalidate(sessionsProvider);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Failed to delete session: $e"),
                  backgroundColor: HermesTokens.error,
                ),
              );
            }
            return;
          }
        }
      }
      ref.read(chatMessagesProvider.notifier).clear();
      if (mounted && context.canPop()) {
        context.pop();
      }
    }
  }

  int _estimateTokens(List<ChatMessage> messages) {
    if (messages.isEmpty) return 0;
    int totalChars = 0;
    for (final m in messages) {
      totalChars += m.content.length;
      if (m.toolInput != null) totalChars += m.toolInput!.length;
      if (m.toolOutput != null) totalChars += m.toolOutput!.length;
    }
    return (totalChars / 3.8).ceil();
  }

  double _estimateCost(int tokens) {
    return tokens * 0.000002;
  }

  String _formatNumber(int n) {
    if (n < 1000) return n.toString();
    if (n < 1000000) return "${(n / 1000).toStringAsFixed(1)}k";
    return "${(n / 1000000).toStringAsFixed(2)}M";
  }

  void _handleSlashCommand(_SlashCommandDef cmd) {
    _ctrl.clear();
    setState(() {});

    switch (cmd.command) {
      case "/clear":
        ref.read(chatMessagesProvider.notifier).clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Chat history cleared"),
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case "/model":
        _showModelSheet(context, [], ref.read(selectedModelProvider));
        break;
      case "/compact":
        _ctrl.text = "/compact";
        _send();
        break;
      case "/memory":
        context.push('/memory-editor');
        break;
      case "/soul":
        context.push('/soul-editor');
        break;
      case "/capabilities":
        context.push('/capabilities');
        break;
      case "/approval":
        setState(() {
          _dismissedApproval = false;
          _manualApproval = {
            'command': 'deploy-staging',
            'message': 'Command execution requires operator confirmation.',
          };
        });
        break;
      case "/help":
        _showHelpDialog();
        break;
      default:
        _ctrl.text = cmd.command;
        _send();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<ChatMessage>>(chatMessagesProvider, (prev, next) {
      if (next.isNotEmpty && !_loadingSession) {
        _scrollToBottom();
      }
    });

    final messages = ref.watch(chatMessagesProvider);
    final selected = ref.watch(selectedModelProvider);
    final generatingSessions = ref.watch(generatingSessionsProvider);
    final isGenerating = _streaming ||
        (widget.sessionId != null && generatingSessions.contains(widget.sessionId)) ||
        messages.any((m) => m.isStreaming);

    final totalTokens = _estimateTokens(messages);
    final estCost = _estimateCost(totalTokens);
    final pendingApproval = _detectPendingApproval(messages);

    final text = _ctrl.text.trim();
    final isSlash = text.startsWith('/');
    final slashQuery = isSlash ? text.toLowerCase() : '';
    final matchingCommands = isSlash
        ? _allSlashCommands.where((c) {
            final filter = slashQuery.replaceFirst('/', '');
            if (filter.isEmpty) return true;
            return c.command.toLowerCase().contains(filter) ||
                c.label.toLowerCase().contains(filter);
          }).toList()
        : <_SlashCommandDef>[];

    return Scaffold(
      backgroundColor: HermesTokens.bgPrimary,
      appBar: AppBar(
        backgroundColor: HermesTokens.bgPrimary,
        elevation: 0,
        leadingWidth: 54,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: NeumorphicDecoration.raised(radius: 12, distance: 2.5, blur: 5),
              child: IconButton(
                tooltip: "Back to conversations",
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: HermesTokens.textPrimary, size: 16),
                onPressed: () => context.pop(),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        title: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.55),
          child: InkWell(
            onTap: () => _showModelSheet(context, [], selected),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: NeumorphicDecoration.raised(
                radius: 16,
                distance: 2.5,
                blur: 5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _sessionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: HermesTokens.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isGenerating ? HermesTokens.accent : HermesTokens.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isGenerating
                              ? "Thinking..."
                              : (selected.isNotEmpty
                                  ? _ParsedModelInfo.fromRaw(selected).cleanName
                                  : "Select Model"),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isGenerating ? HermesTokens.accent : HermesTokens.textMuted,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: HermesTokens.textMuted),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: NeumorphicDecoration.raised(radius: 12, distance: 2.5, blur: 5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      popupMenuTheme: PopupMenuThemeData(
                        color: HermesTokens.bgElevated,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: HermesTokens.border),
                        ),
                        elevation: 6,
                        textStyle: const TextStyle(
                          color: HermesTokens.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    child: PopupMenuButton<String>(
                      tooltip: "Session options",
                      icon: const Icon(Icons.more_vert_rounded, color: HermesTokens.textSecondary, size: 20),
                      padding: EdgeInsets.zero,
                      onSelected: (val) {
                        if (val == "rename") {
                          _showRenameDialog();
                        } else if (val == "clear") {
                          _confirmClearMessages();
                        } else if (val == "delete") {
                          _confirmDeleteSession();
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem<String>(
                          value: "rename",
                          height: 42,
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18, color: HermesTokens.textSecondary),
                              SizedBox(width: 10),
                              Text("Rename Session", style: TextStyle(fontSize: 13, color: HermesTokens.textPrimary)),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: "clear",
                          height: 42,
                          child: Row(
                            children: [
                              Icon(Icons.cleaning_services_outlined, size: 18, color: HermesTokens.textSecondary),
                              SizedBox(width: 10),
                              Text("Clear Messages", style: TextStyle(fontSize: 13, color: HermesTokens.textPrimary)),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(height: 1),
                        const PopupMenuItem<String>(
                          value: "delete",
                          height: 42,
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 18, color: HermesTokens.error),
                              SizedBox(width: 10),
                              Text("Delete Session", style: TextStyle(fontSize: 13, color: HermesTokens.error, fontWeight: FontWeight.w600)),
                            ],
                          ),
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
      body: Column(
        children: [
          _buildTopPillsRow(totalTokens, estCost, selected),
          Expanded(
            child: IndexedStack(
              index: _isVibeMode ? 1 : 0,
              children: [
                _buildChatView(messages, isGenerating),
                VibeModeView(
                  messages: messages,
                  isGenerating: isGenerating,
                  activeCwd: ref.watch(activeWorkspaceProvider).path.isNotEmpty
                      ? ref.watch(activeWorkspaceProvider).path
                      : _activeCwd,
                  connection: ref.watch(connectionProvider).valueOrNull,
                  onQuickPrompt: (prompt) {
                    _ctrl.text = prompt;
                    _send();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isVibeMode)
              _buildVibeQuickChips(),
            if (!isGenerating && pendingApproval != null)
              _buildApprovalCard(pendingApproval),
            if (_attachment != null)
              _buildAttachmentPreview(),
            if (isSlash && matchingCommands.isNotEmpty)
              _buildSlashCommandsPalette(matchingCommands),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: HermesTokens.bgPrimary,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.white,
                    offset: Offset(0, -4),
                    blurRadius: 8,
                  ),
                  BoxShadow(
                    color: Color(0x22A3B1C6),
                    offset: Offset(0, -1),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: NeumorphicDecoration.raised(radius: 14, distance: 2, blur: 4),
                    child: IconButton(
                      tooltip: "Attach file",
                      icon: const Icon(Icons.attach_file_rounded, color: HermesTokens.textSecondary, size: 18),
                      padding: EdgeInsets.zero,
                      onPressed: isGenerating ? null : _pickAttachment,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: NeumorphicDecoration.recessed(radius: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _ctrl,
                        enabled: !isGenerating,
                        style: const TextStyle(color: HermesTokens.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: "Message MyPixie or type / for commands...",
                          hintStyle: TextStyle(color: HermesTokens.textMuted, fontSize: 13),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: NeumorphicDecoration.circle(
                      color: isGenerating ? HermesTokens.error : HermesTokens.accent,
                    ),
                    child: IconButton(
                      tooltip: isGenerating ? "Stop generation" : "Send message",
                      onPressed: isGenerating
                          ? () {
                              HapticFeedback.mediumImpact();
                              ref.read(chatMessagesProvider.notifier).stopGeneration(
                                sessionId: widget.sessionId,
                              );
                            }
                          : _send,
                      icon: isGenerating
                          ? const Icon(Icons.stop_rounded, color: Colors.white, size: 24)
                          : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    if (_attachment == null) return const SizedBox.shrink();
    final att = _attachment!;
    final isImage = ['png', 'jpg', 'jpeg', 'webp', 'gif']
        .contains((att.extension ?? '').toLowerCase());

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: NeumorphicDecoration.raised(radius: 14, distance: 2.5, blur: 5),
      child: Row(
        children: [
          Icon(
            isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
            size: 20,
            color: HermesTokens.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  att.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: HermesTokens.textPrimary,
                  ),
                ),
                Text(
                  _formatFileSize(att.size),
                  style: const TextStyle(fontSize: 10, color: HermesTokens.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16, color: HermesTokens.textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => setState(() => _attachment = null),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalCard(Map<String, String> approval) {
    final command = approval['command'];
    final approvalId = approval['id'];
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.all(14),
      decoration: NeumorphicDecoration.raised(radius: 16, distance: 3.5, blur: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: HermesTokens.accent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Command Execution Approval",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: HermesTokens.textPrimary,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  if (approvalId != null && approvalId.isNotEmpty) {
                    _globallyResolvedApprovals.add(approvalId);
                  }
                  setState(() {
                    _dismissedApproval = true;
                    _manualApproval = null;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 16, color: HermesTokens.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (command != null && command.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: NeumorphicDecoration.recessed(radius: 8),
              child: Text(
                command,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HermesTokens.accent,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ] else ...[
            Text(
              approval['message'] ?? "This action requires operator confirmation.",
              style: const TextStyle(fontSize: 11, color: HermesTokens.textSecondary),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () async {
                  if (approvalId != null && approvalId.isNotEmpty) {
                    _globallyResolvedApprovals.add(approvalId);
                  }
                  setState(() {
                    _dismissedApproval = true;
                    _manualApproval = null;
                  });
                  final conn = ref.read(connectionProvider).valueOrNull;
                  if (conn != null) {
                    await conn.denyAction();
                  }
                  ref.read(chatMessagesProvider.notifier).sendMessage("/deny", sessionId: widget.sessionId);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: HermesTokens.border),
                  ),
                  child: const Text(
                    "Deny",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HermesTokens.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () async {
                  if (approvalId != null && approvalId.isNotEmpty) {
                    _globallyResolvedApprovals.add(approvalId);
                  }
                  setState(() {
                    _dismissedApproval = true;
                    _manualApproval = null;
                  });
                  final conn = ref.read(connectionProvider).valueOrNull;
                  if (conn != null) {
                    await conn.approveAction();
                  }
                  ref.read(chatMessagesProvider.notifier).sendMessage("/approve", sessionId: widget.sessionId);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: NeumorphicDecoration.raised(
                    radius: 8,
                    distance: 2,
                    blur: 4,
                    color: HermesTokens.accent,
                  ),
                  child: const Text(
                    "Approve",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopPillsRow(int tokens, double cost, String model) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Pill: Token and Cost Estimator
          GestureDetector(
            onTap: () => _showTokenCostBreakdown(tokens, cost, model),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: NeumorphicDecoration.raised(radius: 17, distance: 2, blur: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, size: 14, color: HermesTokens.accent),
                  const SizedBox(width: 4),
                  Text(
                    "${_formatNumber(tokens)} tkn",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: HermesTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text("•", style: TextStyle(fontSize: 10, color: HermesTokens.textMuted)),
                  const SizedBox(width: 5),
                  Text(
                    tokens == 0
                        ? "\$0"
                        : (cost < 0.0001 ? "<\$0.0001" : "\$${cost.toStringAsFixed(4)}"),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: HermesTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right Pill: Mode Switcher [Chat | Vibe]
          _buildModeTogglePill(),
        ],
      ),
    );
  }

  Widget _buildModeTogglePill() {
    return Container(
      height: 34,
      decoration: NeumorphicDecoration.recessed(radius: 17),
      padding: const EdgeInsets.all(2.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modePillButton(
            title: "Chat",
            icon: Icons.chat_bubble_outline_rounded,
            isSelected: !_isVibeMode,
            onTap: () {
              if (_isVibeMode) {
                HapticFeedback.selectionClick();
                setState(() => _isVibeMode = false);
              }
            },
          ),
          _modePillButton(
            title: "Vibe",
            icon: Icons.code_rounded,
            isSelected: _isVibeMode,
            onTap: () {
              if (!_isVibeMode) {
                HapticFeedback.selectionClick();
                setState(() => _isVibeMode = true);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _modePillButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutQuad,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: isSelected
            ? NeumorphicDecoration.raised(radius: 14, distance: 1.5, blur: 3, color: HermesTokens.bgPrimary)
            : const BoxDecoration(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? HermesTokens.accentText : HermesTokens.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? HermesTokens.textPrimary : HermesTokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatView(List<ChatMessage> messages, bool isGenerating) {
    if (_loadingSession) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: HermesTokens.accent),
      );
    }
    if (messages.isEmpty && !isGenerating && !_streaming) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: NeumorphicDecoration.raised(radius: 16),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 26,
                  color: HermesTokens.accent,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "Start a conversation",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: HermesTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Type / for commands, or ask Hermes to code or automate.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: HermesTokens.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Suggested Prompts",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: HermesTokens.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _randomizeSuggestions();
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: HermesTokens.bgTertiary.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: HermesTokens.border.withValues(alpha: 0.6)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shuffle_rounded, size: 12, color: HermesTokens.accent),
                          SizedBox(width: 4),
                          Text(
                            "Shuffle",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: HermesTokens.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._activeSuggestions.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _promptSuggestionCard(
                  icon: s.icon,
                  title: s.title,
                  subtitle: s.subtitle,
                  prompt: s.prompt,
                ),
              )),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (_, i) {
        final msg = messages[messages.length - 1 - i];
        final showDate = i == messages.length - 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDate)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: HermesTokens.bgSecondary,
                      borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
                      border: Border.all(color: HermesTokens.border),
                    ),
                    child: const Text(
                      "TODAY",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: HermesTokens.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ChatBubble(message: msg),
          ],
        );
      },
    );
  }

  Widget _buildVibeQuickChips() {
    final chips = [
      ("/fix", "Fix Errors", Icons.auto_fix_high_rounded),
      ("/test", "Write Tests", Icons.checklist_rounded),
      ("/explain", "Explain Code", Icons.menu_book_rounded),
      ("/refactor", "Refactor", Icons.transform_rounded),
      ("/plan", "Plan Strategy", Icons.assignment_outlined),
    ];

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: HermesTokens.bgSecondary,
        border: Border(
          top: BorderSide(color: HermesTokens.border, width: 0.5),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        itemBuilder: (ctx, idx) {
          final item = chips[idx];
          return Padding(
            padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                _ctrl.text = "${item.$1} ";
                _ctrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: _ctrl.text.length),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: NeumorphicDecoration.raised(radius: 8, distance: 1.5, blur: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.$3, size: 12, color: HermesTokens.accentText),
                    const SizedBox(width: 5),
                    Text(
                      item.$2,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: HermesTokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }



  Widget _buildSlashCommandsPalette(List<_SlashCommandDef> commands) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: NeumorphicDecoration.raised(radius: 16, distance: 3.5, blur: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(
              children: [
                const Icon(Icons.terminal_rounded, size: 14, color: HermesTokens.accent),
                const SizedBox(width: 6),
                const Text(
                  "COMMANDS",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: HermesTokens.textMuted,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    _ctrl.clear();
                    setState(() {});
                  },
                  child: const Icon(Icons.close_rounded, size: 16, color: HermesTokens.textMuted),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: HermesTokens.border),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: commands.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: HermesTokens.border),
              itemBuilder: (_, index) {
                final cmd = commands[index];
                return InkWell(
                  onTap: () => _handleSlashCommand(cmd),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: NeumorphicDecoration.recessed(radius: 8),
                          child: Icon(cmd.icon, size: 15, color: HermesTokens.accent),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          cmd.command,
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: HermesTokens.accentText,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            cmd.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: HermesTokens.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showTokenCostBreakdown(int tokens, double cost, String model) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => Dialog(
        backgroundColor: HermesTokens.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
          side: const BorderSide(color: HermesTokens.borderBright),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: NeumorphicDecoration.recessed(radius: 12),
                      child: const Icon(Icons.analytics_rounded, size: 20, color: HermesTokens.accent),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Session Usage & Cost",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: HermesTokens.textPrimary,
                            ),
                          ),
                          Text(
                            "Live context estimation",
                            style: TextStyle(
                              fontSize: 11,
                              color: HermesTokens.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: HermesTokens.textMuted),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: NeumorphicDecoration.recessed(radius: 12),
                  child: Column(
                    children: [
                      _metricRow("Active Model", model),
                      const SizedBox(height: 8),
                      _metricRow("Total Tokens", "$tokens tokens"),
                      const SizedBox(height: 8),
                      _metricRow(
                        "Estimated Cost",
                        "\$${cost.toStringAsFixed(6)}",
                        valueColor: HermesTokens.accentText,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HermesTokens.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text("Close", style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: HermesTokens.textMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor ?? HermesTokens.textPrimary,
          ),
        ),
      ],
    );
  }

  void _showHelpDialog() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => Dialog(
        backgroundColor: HermesTokens.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
          side: const BorderSide(color: HermesTokens.borderBright),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: NeumorphicDecoration.recessed(radius: 12),
                      child: const Icon(Icons.help_outline_rounded, size: 20, color: HermesTokens.accent),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Slash Commands",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: HermesTokens.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: HermesTokens.textMuted),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ..._allSlashCommands.map((c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            c.command,
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: HermesTokens.accentText,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.description,
                              style: const TextStyle(
                                fontSize: 11,
                                color: HermesTokens.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _promptSuggestionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String prompt,
  }) {
    return GestureDetector(
      onTap: () {
        _ctrl.text = prompt;
        _send();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: NeumorphicDecoration.raised(radius: 14, distance: 3, blur: 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: NeumorphicDecoration.recessed(radius: 10),
              child: Icon(icon, size: 18, color: HermesTokens.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: HermesTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: HermesTokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: HermesTokens.textMuted),
          ],
        ),
      ),
    );
  }

  void _showModelSheet(BuildContext context, List<ModelConfig> models, String current) {
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        String searchQuery = "";
        String selectedFilter = "All";

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: const BoxDecoration(
                color: HermesTokens.bgPrimary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(HermesTokens.radiusLg)),
              ),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: HermesTokens.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text(
                        "Select Model",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: HermesTokens.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded, size: 20, color: HermesTokens.textMuted),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: NeumorphicDecoration.recessed(radius: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, size: 18, color: HermesTokens.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setModalState(() => searchQuery = val),
                            style: const TextStyle(color: HermesTokens.textPrimary, fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: "Search models, provider, or family...",
                              hintStyle: TextStyle(color: HermesTokens.textMuted, fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        if (searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () => setModalState(() => searchQuery = ""),
                            child: const Icon(Icons.clear_rounded, size: 18, color: HermesTokens.textMuted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: FutureBuilder<List<ModelConfig>>(
                      future: conn.getModels(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting && models.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(color: HermesTokens.accent),
                          );
                        }
                        final allList = snap.data ?? models;
                        if (allList.isEmpty && snap.connectionState != ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                "No models available",
                                style: TextStyle(color: HermesTokens.textMuted),
                              ),
                            ),
                          );
                        }

                        final availableFilters = <String>['All'];
                        final hasFree = allList.any((m) =>
                            m.name.toLowerCase().contains(':free') ||
                            m.name.toLowerCase().contains('free'));
                        if (hasFree) availableFilters.add('Free');

                        final detectedFamilies = <String>{};
                        for (final m in allList) {
                          final l = m.name.toLowerCase();
                          final p = m.provider.toLowerCase();
                          if (l.contains('claude') || l.contains('anthropic') || p.contains('anthropic')) {
                            detectedFamilies.add('Claude');
                          } else if (l.contains('gpt') || l.contains('openai') || p.contains('openai')) {
                            detectedFamilies.add('GPT');
                          } else if (l.contains('gemini') || l.contains('google') || p.contains('google')) {
                            detectedFamilies.add('Gemini');
                          } else if (l.contains('llama') || l.contains('meta')) {
                            detectedFamilies.add('Llama');
                          } else if (l.contains('deepseek')) {
                            detectedFamilies.add('DeepSeek');
                          } else if (l.contains('qwen')) {
                            detectedFamilies.add('Qwen');
                          } else if (l.contains('mistral')) {
                            detectedFamilies.add('Mistral');
                          }
                        }
                        availableFilters.addAll(detectedFamilies);

                        final q = searchQuery.trim().toLowerCase();
                        final filteredList = allList.where((m) {
                          final l = m.name.toLowerCase();
                          final p = m.provider.toLowerCase();

                          if (selectedFilter == 'Free') {
                            if (!l.contains(':free') && !l.contains('free')) return false;
                          } else if (selectedFilter == 'Claude') {
                            if (!l.contains('claude') && !l.contains('anthropic') && !p.contains('anthropic')) return false;
                          } else if (selectedFilter == 'GPT') {
                            if (!l.contains('gpt') && !l.contains('openai') && !p.contains('openai')) return false;
                          } else if (selectedFilter == 'Gemini') {
                            if (!l.contains('gemini') && !l.contains('google') && !p.contains('google')) return false;
                          } else if (selectedFilter == 'Llama') {
                            if (!l.contains('llama') && !l.contains('meta')) return false;
                          } else if (selectedFilter == 'DeepSeek') {
                            if (!l.contains('deepseek')) return false;
                          } else if (selectedFilter == 'Qwen') {
                            if (!l.contains('qwen')) return false;
                          } else if (selectedFilter == 'Mistral') {
                            if (!l.contains('mistral')) return false;
                          }

                          if (q.isNotEmpty) {
                            final info = _ParsedModelInfo.fromConfig(m);
                            if (!l.contains(q) &&
                                !p.contains(q) &&
                                !info.cleanName.toLowerCase().contains(q) &&
                                !info.namespace.toLowerCase().contains(q)) {
                              return false;
                            }
                          }
                          return true;
                        }).toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 32,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: availableFilters.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 6),
                                itemBuilder: (context, chipIdx) {
                                  final chip = availableFilters[chipIdx];
                                  final isChipSelected = selectedFilter == chip;
                                  return GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setModalState(() => selectedFilter = chip);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isChipSelected
                                            ? HermesTokens.accent
                                            : HermesTokens.bgSecondary,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isChipSelected
                                              ? HermesTokens.accent
                                              : HermesTokens.borderBright.withValues(alpha: 0.6),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        chip,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isChipSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isChipSelected ? Colors.white : HermesTokens.textMuted,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                              child: Text(
                                "${filteredList.length} models available",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: HermesTokens.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: filteredList.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          q.isNotEmpty
                                              ? "No models matching \"$searchQuery\""
                                              : "No models in this category",
                                          style: const TextStyle(color: HermesTokens.textMuted),
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: filteredList.length,
                                      itemBuilder: (context, index) {
                                        final m = filteredList[index];
                                        final isSelected = m.name == current;
                                        final info = _ParsedModelInfo.fromConfig(m);

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 6),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? HermesTokens.accent.withValues(alpha: 0.1)
                                                : HermesTokens.bgSecondary.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isSelected
                                                  ? HermesTokens.accent.withValues(alpha: 0.4)
                                                  : HermesTokens.borderBright.withValues(alpha: 0.4),
                                              width: isSelected ? 1.2 : 0.8,
                                            ),
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(10),
                                              onTap: () async {
                                                HapticFeedback.selectionClick();
                                                ref.read(selectedModelProvider.notifier).state = m.name;
                                                Navigator.of(ctx).pop();
                                                try {
                                                  await conn.setModelEnabled(m.name, true);
                                                  ref.invalidate(modelsProvider);
                                                } catch (_) {}
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 32,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        color: isSelected
                                                            ? HermesTokens.accent.withValues(alpha: 0.18)
                                                            : HermesTokens.bgTertiary,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Center(
                                                        child: Icon(
                                                          isSelected
                                                              ? Icons.auto_awesome_rounded
                                                              : Icons.smart_toy_outlined,
                                                          size: 16,
                                                          color: isSelected
                                                              ? HermesTokens.accent
                                                              : HermesTokens.textMuted,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Flexible(
                                                                child: Text(
                                                                  info.cleanName,
                                                                  style: TextStyle(
                                                                    fontSize: 13,
                                                                    fontWeight: isSelected
                                                                        ? FontWeight.w700
                                                                        : FontWeight.w600,
                                                                    color: isSelected
                                                                        ? HermesTokens.accent
                                                                        : HermesTokens.textPrimary,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                              if (info.tag != null) ...[
                                                                const SizedBox(width: 6),
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(
                                                                      horizontal: 5, vertical: 1.5),
                                                                  decoration: BoxDecoration(
                                                                    color: info.isFree
                                                                        ? HermesTokens.success
                                                                            .withValues(alpha: 0.15)
                                                                        : HermesTokens.accent
                                                                            .withValues(alpha: 0.15),
                                                                    borderRadius: BorderRadius.circular(4),
                                                                  ),
                                                                  child: Text(
                                                                    info.tag!,
                                                                    style: TextStyle(
                                                                      fontSize: 9,
                                                                      fontWeight: FontWeight.w700,
                                                                      color: info.isFree
                                                                          ? HermesTokens.success
                                                                          : HermesTokens.accent,
                                                                      letterSpacing: 0.5,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                          const SizedBox(height: 2),
                                                          Text(
                                                            info.namespace.isNotEmpty
                                                                ? "${info.namespace} • ${info.provider.isNotEmpty ? info.provider : info.rawId}"
                                                                : (info.provider.isNotEmpty
                                                                    ? info.provider
                                                                    : info.rawId),
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              color: HermesTokens.textMuted,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    if (isSelected)
                                                      Container(
                                                        width: 20,
                                                        height: 20,
                                                        decoration: const BoxDecoration(
                                                          color: HermesTokens.accent,
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: const Icon(
                                                          Icons.check_rounded,
                                                          size: 13,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    else
                                                      const Icon(
                                                        Icons.chevron_right_rounded,
                                                        size: 16,
                                                        color: HermesTokens.textMuted,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ParsedModelInfo {
  final String rawId;
  final String cleanName;
  final String namespace;
  final String provider;
  final bool isFree;
  final String? tag;

  const _ParsedModelInfo({
    required this.rawId,
    required this.cleanName,
    required this.namespace,
    required this.provider,
    required this.isFree,
    this.tag,
  });

  factory _ParsedModelInfo.fromRaw(String raw, [String provider = '']) {
    final slashIdx = raw.indexOf('/');
    final ns = slashIdx != -1 ? raw.substring(0, slashIdx) : '';
    String modelPart = slashIdx != -1 ? raw.substring(slashIdx + 1) : raw;

    bool isFree = false;
    String? tag;
    if (modelPart.contains(':free')) {
      isFree = true;
      tag = 'FREE';
      modelPart = modelPart.replaceAll(':free', '');
    } else if (modelPart.contains(':beta')) {
      tag = 'BETA';
      modelPart = modelPart.replaceAll(':beta', '');
    } else if (modelPart.contains(':exact')) {
      modelPart = modelPart.replaceAll(':exact', '');
    }

    final cleanName = _cleanFormat(modelPart);

    return _ParsedModelInfo(
      rawId: raw,
      cleanName: cleanName.isNotEmpty ? cleanName : raw,
      namespace: ns,
      provider: provider,
      isFree: isFree,
      tag: tag,
    );
  }

  factory _ParsedModelInfo.fromConfig(ModelConfig m) {
    return _ParsedModelInfo.fromRaw(m.name, m.provider);
  }

  static String _cleanFormat(String name) {
    if (name.isEmpty) return name;
    final segments = name.split(RegExp(r'[-_]'));
    return segments.map((seg) {
      if (seg.isEmpty) return '';
      final lower = seg.toLowerCase();
      if (lower == 'gpt') return 'GPT';
      if (lower == 'claude') return 'Claude';
      if (lower == 'llama') return 'Llama';
      if (lower == 'gemini') return 'Gemini';
      if (lower == 'deepseek') return 'DeepSeek';
      if (lower == 'qwen') return 'Qwen';
      if (lower == 'mistral') return 'Mistral';
      if (lower == 'instruct') return 'Instruct';
      if (lower == 'flash') return 'Flash';
      if (lower == 'pro') return 'Pro';
      if (lower == 'sonnet') return 'Sonnet';
      if (lower == 'opus') return 'Opus';
      if (lower == 'haiku') return 'Haiku';
      return seg[0].toUpperCase() + seg.substring(1);
    }).join(' ');
  }
}
