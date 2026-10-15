import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../providers/chat_provider.dart";
import "../../providers/connection_provider.dart";
import "../../services/hermes_connection.dart";
import "../../theme.dart";
import "../widgets/neumorphic_skeleton.dart";
import "../widgets/tactile_feedback.dart";

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openChatRoom(String title, {String? sessionId}) {
    context.push('/chat-room', extra: {
      'title': title,
      'sessionId': sessionId,
    });
  }

  Future<bool> _confirmDeleteSession(SessionSummary s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HermesTokens.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Delete Conversation?",
          style: TextStyle(
            color: HermesTokens.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${s.title}"? This will permanently delete the session from Hermes.',
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
      final conn = ref.read(connectionProvider).valueOrNull;
      if (conn != null) {
        try {
          await conn.deleteSession(s.id);
          ref.invalidate(sessionsProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Session "${s.title}" deleted'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return true;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Failed to delete session: $e"),
                backgroundColor: HermesTokens.error,
              ),
            );
          }
          return false;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(sessionsSearchQueryProvider);
    final sessionsAsync = ref.watch(sessionsProvider(searchQuery.isEmpty ? null : searchQuery));
    final generatingSessions = ref.watch(generatingSessionsProvider);

    final activeWorkspace = ref.watch(activeWorkspaceProvider);
    final activeReasoning = ref.watch(reasoningEffortProvider);

    return Scaffold(
      backgroundColor: HermesTokens.bgPrimary,
      appBar: AppBar(
        backgroundColor: HermesTokens.bgPrimary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "MyPixie",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: HermesTokens.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Container(
                decoration: NeumorphicDecoration.recessed(radius: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: HermesTokens.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: "Search conversations...",
                    hintStyle: TextStyle(color: HermesTokens.textMuted, fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: HermesTokens.textMuted, size: 18),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => ref.read(sessionsSearchQueryProvider.notifier).state = v,
                ),
              ),
            ),

            // Context Bar: Workspace & Reasoning
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: _workspacePill(context, activeWorkspace),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: _reasoningPill(context, activeReasoning),
                  ),
                ],
              ),
            ),

            // Session list
            Expanded(
              child: RefreshIndicator(
                color: HermesTokens.accent,
                backgroundColor: HermesTokens.bgElevated,
                onRefresh: () async {
                  final query = ref.read(sessionsSearchQueryProvider);
                  ref.invalidate(sessionsProvider);
                  try {
                    await ref.read(sessionsProvider(query.isEmpty ? null : query).future);
                  } catch (_) {}
                },
                child: sessionsAsync.when(
                  data: (sessions) {
                    final allSessions = [...sessions];
                    // Keep actively generating sessions visible at top even before backend persistence
                    for (final genId in generatingSessions) {
                      if (!allSessions.any((s) => s.id == genId)) {
                        allSessions.insert(
                          0,
                          SessionSummary(
                            id: genId,
                            title: "New Conversation",
                            snippet: "Thinking & responding...",
                            startedAt: DateTime.now().toIso8601String(),
                            source: "app",
                            model: "hermes-agent",
                            messageCount: 1,
                            unreadCount: 0,
                          ),
                        );
                      }
                    }
                    return _sessionList(allSessions);
                  },
                  loading: () => const SessionListSkeleton(),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 40, color: HermesTokens.error),
                        const SizedBox(height: 12),
                        const Text("Failed to load sessions", style: TextStyle(color: HermesTokens.textMuted)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.invalidate(sessionsProvider(null)),
                          child: const Text("Retry", style: TextStyle(color: HermesTokens.accentText)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: TactileContainer(
        onTap: () {
          ref.read(chatMessagesProvider.notifier).clear();
          _openChatRoom("New Chat");
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: NeumorphicDecoration.circle(color: HermesTokens.accent),
          child: const Center(
            child: Icon(Icons.add, size: 24, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _sessionList(List<SessionSummary> sessions) {
    if (sessions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: NeumorphicDecoration.raised(radius: 20),
                    child: const Icon(Icons.chat_bubble_outline_rounded, size: 28, color: HermesTokens.textMuted),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No conversations yet",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: HermesTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Pull down to refresh or tap + to start a chat",
                    style: TextStyle(fontSize: 12, color: HermesTokens.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final Map<String, List<SessionSummary>> groups = {};

    for (final s in sessions) {
      final parsed = DateTime.tryParse(s.startedAt) ?? DateTime.now();
      final d = DateTime(parsed.year, parsed.month, parsed.day);
      String label;
      if (d == today) {
        label = "Today";
      } else if (d == yesterday) {
        label = "Yesterday";
      } else {
        final months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
        label = "${months[parsed.month-1]} ${parsed.day}";
      }
      groups.putIfAbsent(label, () => []).add(s);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
      children: groups.entries.map((e) => _dateGroup(e.key, e.value)).toList(),
    );
  }

  Widget _dateGroup(String date, List<SessionSummary> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 2),
            child: Text(
              date,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: HermesTokens.textMuted,
              ),
            ),
          ),
          ...items.map((s) => _sessionCard(s)),
        ],
      ),
    );
  }

  Widget _sessionCard(SessionSummary s) {
    final time = _formatTime(DateTime.tryParse(s.startedAt));
    final isGenerating = ref.watch(generatingSessionsProvider).contains(s.id);

    return Dismissible(
      key: Key('session_${s.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await _confirmDeleteSession(s);
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: HermesTokens.error.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Delete",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
      child: TactileContainer(
        onTap: () => _openChatRoom(s.title, sessionId: s.id),
        pressedScale: 0.98,
        child: GestureDetector(
          onLongPress: () => _confirmDeleteSession(s),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
          decoration: isGenerating
              ? BoxDecoration(
                  color: HermesTokens.bgElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: HermesTokens.accent.withValues(alpha: 0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: HermesTokens.accent.withValues(alpha: 0.18),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                    const BoxShadow(
                      color: Colors.white,
                      offset: Offset(-3, -3),
                      blurRadius: 6,
                    ),
                  ],
                )
              : NeumorphicDecoration.raised(
                  radius: 16,
                  distance: 3.5,
                  blur: 7,
                ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Linear Modern Accent Strip
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: isGenerating
                          ? HermesTokens.accent
                          : HermesTokens.accent.withValues(alpha: 0.28),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                    ),
                  ),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: HermesTokens.textPrimary,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                time,
                                style: const TextStyle(fontSize: 11, color: HermesTokens.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          if (isGenerating)
                            const Row(
                              children: [
                                SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: HermesTokens.accent,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "Thinking & responding...",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: HermesTokens.accent,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s.snippet.isNotEmpty ? s.snippet : "No messages yet",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: HermesTokens.textMuted,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  String _formatTime(DateTime? dt) {
    if (dt == null) return "";
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      return "${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
    }
    final months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return "${months[dt.month-1]} ${dt.day}";
  }

  Widget _workspacePill(BuildContext context, WorkspaceItem active) {
    final hasValidPath = active.path.isNotEmpty && active.path != '.';
    final folderName = hasValidPath
        ? (active.path.split(RegExp(r'[\\/]')).where((p) => p.isNotEmpty).lastOrNull ?? active.name)
        : active.name;

    final String label;
    if (active.name == folderName ||
        active.name.toLowerCase() == 'default' ||
        active.name.toLowerCase() == 'active' ||
        active.name.toLowerCase() == 'workspace') {
      label = folderName;
    } else {
      label = "${active.name} • $folderName";
    }

    return TactileContainer(
      onTap: () => _showWorkspaceSheet(context),
      pressedScale: 0.96,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: NeumorphicDecoration.raised(radius: 12, distance: 2.5, blur: 5),
        child: Row(
          children: [
            const Icon(Icons.folder_open_rounded, size: 15, color: HermesTokens.accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: HermesTokens.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: HermesTokens.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _reasoningPill(BuildContext context, ReasoningEffort effort) {
    return TactileContainer(
      onTap: () => _showReasoningSheet(context),
      pressedScale: 0.96,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: NeumorphicDecoration.raised(radius: 12, distance: 2.5, blur: 5),
        child: Row(
          children: [
            const Icon(Icons.psychology_outlined, size: 15, color: HermesTokens.accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                effort.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: HermesTokens.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: HermesTokens.textMuted),
          ],
        ),
      ),
    );
  }

  void _showReasoningSheet(BuildContext context) {
    final current = ref.read(reasoningEffortProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: HermesTokens.bgElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 16),
              const Text(
                "Reasoning Effort",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: HermesTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Controls model thinking budget and depth of chain-of-thought tokens.",
                style: TextStyle(
                  fontSize: 12,
                  color: HermesTokens.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              ...ReasoningEffort.values.map((effort) {
                final isSelected = effort == current;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TactileContainer(
                    onTap: () {
                      ref.read(reasoningEffortProvider.notifier).setEffort(effort);
                      Navigator.of(ctx).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: isSelected
                          ? NeumorphicDecoration.recessed(radius: 14)
                          : NeumorphicDecoration.raised(radius: 14, distance: 2, blur: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? HermesTokens.accent : HermesTokens.textMuted,
                                width: 2,
                              ),
                              color: isSelected ? HermesTokens.accent : Colors.transparent,
                            ),
                            child: isSelected
                                ? const Center(
                                    child: Icon(Icons.check, size: 12, color: Colors.white),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  effort.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    color: isSelected ? HermesTokens.accent : HermesTokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  effort.description,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: HermesTokens.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showWorkspaceSheet(BuildContext context) {
    final active = ref.read(activeWorkspaceProvider);
    final list = ref.read(workspacesListProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: HermesTokens.bgElevated,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Hermes Workspace",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: HermesTokens.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.sync_rounded, color: HermesTokens.textSecondary, size: 20),
                      tooltip: "Sync with Daemon",
                      onPressed: () async {
                        await ref.read(activeWorkspaceProvider.notifier).reload();
                        if (ctx.mounted) {
                          setSheetState(() {});
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  "Root working directory for tool execution, file reading, and terminal bash commands.",
                  style: TextStyle(
                    fontSize: 12,
                    color: HermesTokens.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                ...list.map((ws) {
                  final isSelected = ws.id == active.id || ws.path == active.path;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TactileContainer(
                      onTap: () {
                        ref.read(activeWorkspaceProvider.notifier).setWorkspace(ws);
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: isSelected
                            ? NeumorphicDecoration.recessed(radius: 14)
                            : NeumorphicDecoration.raised(radius: 14, distance: 2, blur: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.folder_rounded,
                              size: 20,
                              color: isSelected ? HermesTokens.accent : HermesTokens.textMuted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        ws.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                          color: isSelected ? HermesTokens.accent : HermesTokens.textPrimary,
                                        ),
                                      ),
                                      if (ws.isDefault) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: HermesTokens.accent.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            "DEFAULT",
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: HermesTokens.accent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    ws.path.isNotEmpty ? ws.path : "Server process working directory (.)",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: HermesTokens.textMuted,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, size: 18, color: HermesTokens.accent),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                TactileContainer(
                  onTap: () => _showServerDirectoryPicker(context, ctx, setSheetState),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: HermesTokens.accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          "Browse Server Folders",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
      ),
    );
  }

  bool _isItemDirectory(Map<String, dynamic> item, String name) {
    if (item['isDir'] == true ||
        item['is_dir'] == true ||
        item['is_dir'] == 1 ||
        item['is_directory'] == true ||
        item['isDirectory'] == true) {
      return true;
    }
    final type = item['type']?.toString().toLowerCase();
    if (type == 'dir' || type == 'directory' || type == 'folder' || type == 'd') {
      return true;
    }
    if (!name.contains('.')) return true;
    return false;
  }

  String? _getParentPath(String path) {
    final sep = path.contains('\\') ? '\\' : '/';
    final parts = path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).toList();
    if (parts.length <= 1) return null;
    parts.removeLast();
    if (path.startsWith(sep)) {
      return '$sep${parts.join(sep)}';
    }
    if (path.length >= 2 && path[1] == ':') {
      if (parts.length == 1) return '${parts.first}\\';
      return parts.join('\\');
    }
    return parts.join(sep);
  }

  void _showServerDirectoryPicker(BuildContext context, BuildContext sheetCtx, StateSetter setSheetState) {
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Not connected to server"), backgroundColor: HermesTokens.error),
      );
      return;
    }

    String currentSubpath = '.';
    List<Map<String, dynamic>> items = [];
    bool isLoading = true;
    String? resolvedBase;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (pickerCtx) {
        return StatefulBuilder(
          builder: (ctx, setPickerState) {
            void loadDir(String path) async {
              setPickerState(() {
                isLoading = true;
                currentSubpath = path;
              });
              try {
                resolvedBase ??= await conn.getActiveWorkspaceCwd();
                final list = await conn.listWorkspaceFiles(subpath: path == '.' ? null : path);
                if (ctx.mounted) {
                  setPickerState(() {
                    items = list;
                    isLoading = false;
                  });
                }
              } catch (_) {
                if (ctx.mounted) {
                  setPickerState(() => isLoading = false);
                }
              }
            }

            if (isLoading && items.isEmpty) {
              loadDir(currentSubpath);
            }

            final parentPath = currentSubpath != '.' ? _getParentPath(currentSubpath) : null;
            final currentDisplay = currentSubpath == '.' ? (resolvedBase ?? 'Root Workspace (.)') : currentSubpath;
            final currentFolderName = currentDisplay.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).lastOrNull ?? 'Workspace';

            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: const BoxDecoration(
                color: HermesTokens.bgElevated,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: HermesTokens.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Server Directory Browser",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: HermesTokens.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Tap folders to navigate, select to apply workspace",
                                style: TextStyle(fontSize: 11, color: HermesTokens.textMuted),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20, color: HermesTokens.textMuted),
                            onPressed: () => Navigator.of(pickerCtx).pop(),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: NeumorphicDecoration.recessed(radius: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.folder_open_rounded, size: 16, color: HermesTokens.accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                currentDisplay,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: HermesTokens.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                          : ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              children: [
                                if (parentPath != null || currentSubpath != '.')
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: InkWell(
                                      onTap: () => loadDir(parentPath ?? '.'),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: HermesTokens.bgTertiary.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.arrow_upward_rounded, size: 16, color: HermesTokens.accent),
                                            SizedBox(width: 8),
                                            Text(
                                              "Up to Parent Directory (..)",
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
                                  ),
                                if (items.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 30),
                                    child: Center(
                                      child: Text(
                                        "No subdirectories or files found",
                                        style: TextStyle(color: HermesTokens.textMuted, fontSize: 12),
                                      ),
                                    ),
                                  )
                                else
                                  ...items.map((it) {
                                    final name = it['name']?.toString() ?? '';
                                    final itemPath = it['path']?.toString() ?? name;
                                    final isDir = _isItemDirectory(it, name);

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: InkWell(
                                        onTap: isDir
                                            ? () => loadDir(itemPath)
                                            : () => _viewFileContent(context, conn, itemPath, name),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isDir
                                                ? HermesTokens.bgTertiary.withValues(alpha: 0.3)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isDir ? Icons.folder_rounded : Icons.insert_drive_file_outlined,
                                                size: 18,
                                                color: isDir ? HermesTokens.accent : HermesTokens.textMuted,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: isDir ? FontWeight.w600 : FontWeight.w400,
                                                    color: isDir ? HermesTokens.textPrimary : HermesTokens.textSecondary,
                                                  ),
                                                ),
                                              ),
                                              if (isDir)
                                                const Icon(
                                                  Icons.chevron_right_rounded,
                                                  size: 16,
                                                  color: HermesTokens.textMuted,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      decoration: const BoxDecoration(
                        color: HermesTokens.bgElevated,
                        border: Border(top: BorderSide(color: HermesTokens.border, width: 0.5)),
                      ),
                      child: TactileContainer(
                        onTap: () {
                          final selectedPath = currentSubpath == '.' ? (resolvedBase ?? '.') : currentSubpath;
                          final newWs = WorkspaceItem(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            name: currentFolderName,
                            path: selectedPath,
                          );
                          ref.read(workspacesListProvider.notifier).update((l) => [...l, newWs]);
                          ref.read(activeWorkspaceProvider.notifier).setWorkspace(newWs);
                          Navigator.of(pickerCtx).pop();
                          if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                        },
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: HermesTokens.accent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  "Select '$currentFolderName' as Workspace",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
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
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _viewFileContent(BuildContext context, HermesConnection conn, String path, String fileName) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bCtx) {
        return FutureBuilder<String?>(
          future: conn.readWorkspaceFile(path),
          builder: (fCtx, snap) {
            final isLoading = snap.connectionState == ConnectionState.waiting;
            final content = snap.data ?? "";
            final error = snap.hasError ? snap.error.toString() : null;

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: const BoxDecoration(
                color: HermesTokens.bgElevated,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: HermesTokens.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: NeumorphicDecoration.raised(radius: 10, distance: 1.5, blur: 3),
                            child: const Icon(Icons.description_outlined, size: 18, color: HermesTokens.accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: HermesTokens.textPrimary,
                                  ),
                                ),
                                Text(
                                  path,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    color: HermesTokens.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isLoading && content.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18, color: HermesTokens.textSecondary),
                              tooltip: "Copy content",
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: content));
                                if (bCtx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("File content copied to clipboard"), duration: Duration(seconds: 1)),
                                  );
                                }
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20, color: HermesTokens.textMuted),
                            onPressed: () => Navigator.of(bCtx).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: HermesTokens.border),
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                          : error != null
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text("Error reading file: $error", style: const TextStyle(color: HermesTokens.error, fontSize: 12)),
                                  ),
                                )
                              : content.isEmpty
                                  ? const Center(
                                      child: Text("File is empty", style: TextStyle(color: HermesTokens.textMuted, fontSize: 12)),
                                    )
                                  : Container(
                                      margin: const EdgeInsets.all(12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: NeumorphicDecoration.recessed(radius: 12),
                                      child: SingleChildScrollView(
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: SelectableText(
                                            content,
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 12,
                                              color: HermesTokens.textPrimary,
                                              height: 1.45,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
