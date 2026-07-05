import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../providers/chat_provider.dart";
import "../../services/hermes_connection.dart";
import "../widgets/chat_bubble.dart";
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}
class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  bool _streaming = false;
  bool _inChat = false;
  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }
  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || _streaming) return;
    _ctrl.clear();
    setState(() => _streaming = true);
    await ref.read(chatMessagesProvider.notifier).sendMessage(t);
    setState(() => _streaming = false);
    _scrollToBottom();
  }
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients)
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
    });
  }
  void _enterChat(String title) => setState(() => _inChat = true);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (_inChat) return _chatView(cs, tt);
    return _sessionsView(cs, tt);
  }
  Widget _sessionsView(ColorScheme cs, TextTheme tt) {
    final searchQuery = ref.watch(sessionsSearchQueryProvider);
    final sessionsAsync = ref.watch(sessionsProvider(searchQuery.isEmpty ? null : searchQuery));
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Chat",
                          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Browse and resume conversations.",
                          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFFC7B8EA)),
                    tooltip: "New",
                    onPressed: () => _enterChat("New Chat"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: "Search sessions...",
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF948F99)),
                  filled: true,
                  fillColor: const Color(0xFF242424),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (v) => ref.read(sessionsSearchQueryProvider.notifier).state = v,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: sessionsAsync.when(
                data: (sessions) => _sessionList(sessions, cs),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text("Failed to load sessions")),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _sessionList(List<SessionSummary> sessions, ColorScheme cs) {
    if (sessions.isEmpty) {
      return Center(
        child: Text("No sessions found.", style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    // Group by date
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
        label = "${parsed.month}/${parsed.day}";
      }
      groups.putIfAbsent(label, () => []).add(s);
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: groups.entries.map((e) => _dateGroup(e.key, e.value, cs)).toList(),
    );
  }
  Widget _dateGroup(String date, List<SessionSummary> items, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(date, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF948F99))),
          const SizedBox(height: 8),
          ...items.map((s) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF242424),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              title: Text(s.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: Text(
                "${s.messageCount} msgs · ${_timeAgo(DateTime.tryParse(s.startedAt) ?? DateTime.now())}",
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFF948F99), size: 20),
              onTap: () => _enterChat(s.title),
            ),
          )),
        ],
      ),
    );
  }
  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative) return "just now";
    if (diff.inMinutes < 1) return "just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }
  Widget _chatView(ColorScheme cs, TextTheme tt) {
    final messages = ref.watch(chatMessagesProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFC7B8EA)),
          onPressed: () => setState(() => _inChat = false),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt, color: Color(0xFFC7B8EA), size: 24),
            const SizedBox(width: 8),
            const Text("Hermes"),
          ],
        ),
      ),
      body: messages.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text("Start a conversation", style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text("Send a message to begin.", style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: messages.length,
              itemBuilder: (_, i) => ChatBubble(message: messages[i]),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  enabled: !_streaming,
                  decoration: const InputDecoration(
                    hintText: "Message Hermes...",
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC7B8EA).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: _streaming ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC7B8EA),
                    foregroundColor: const Color(0xFF121212),
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(14),
                  ),
                  child: _streaming
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.onPrimary))
                      : const Icon(Icons.send),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
