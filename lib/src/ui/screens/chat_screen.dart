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
  String _filter = "All"; // "All" or "Unread"

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
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _enterChat(String title) => setState(() => _inChat = true);

  @override
  Widget build(BuildContext context) {
    if (_inChat) return _chatView();
    return _sessionsView();
  }

  // ==================== SESSIONS LIST ====================

  Widget _sessionsView() {
    final searchQuery = ref.watch(sessionsSearchQueryProvider);
    final sessionsAsync = ref.watch(sessionsProvider(searchQuery.isEmpty ? null : searchQuery));

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Color(0xFFECECEC), fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Search conversations...",
                  hintStyle: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF8E8E8E), size: 20),
                  filled: true,
                  fillColor: const Color(0xFF171717),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => ref.read(sessionsSearchQueryProvider.notifier).state = v,
              ),
            ),

            // Filter pills
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _filterPill("All"),
                  const SizedBox(width: 8),
                  _filterPill("Unread"),
                ],
              ),
            ),

            // Session list
            Expanded(
              child: sessionsAsync.when(
                data: (sessions) => _sessionList(sessions),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF003F7A)),
                ),
                error: (e, _) => const Center(
                  child: Text("Failed to load sessions", style: TextStyle(color: Color(0xFF8E8E8E))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterPill(String label) {
    final active = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF003F7A) : const Color(0xFF2F2F2F),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFFB4B4B4),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _sessionList(List<SessionSummary> sessions) {
    if (sessions.isEmpty) {
      return const Center(
        child: Text("No sessions found.", style: TextStyle(color: Color(0xFF8E8E8E))),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              date,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E8E8E),
                letterSpacing: 0.5,
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

    return GestureDetector(
      onTap: () => _enterChat(s.title),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFECECEC),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${s.messageCount} messages",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8E8E8E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E8E)),
                ),
                if (s.messageCount > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFF003F7A),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "${s.messageCount}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return "";
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
    }
    final months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return "${months[dt.month-1]} ${dt.day}";
  }

  // ==================== CHAT VIEW ====================

  Widget _chatView() {
    final messages = ref.watch(chatMessagesProvider);
    final selected = ref.watch(selectedModelProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF212121),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF003F7A)),
          onPressed: () => setState(() => _inChat = false),
        ),
        title: _ModelSelector(),
        centerTitle: false,
      ),
      body: messages.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 64, color: Color(0xFF8E8E8E)),
                  const SizedBox(height: 16),
                  const Text("Start a conversation",
                      style: TextStyle(fontSize: 16, color: Color(0xFF8E8E8E))),
                  const SizedBox(height: 4),
                  const Text("Send a message to begin.",
                      style: TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
                ],
              ),
            )
          : ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final msg = messages[i];
                // Show date separator
                final showDate = i == 0;
                return Column(
                  children: [
                    if (showDate)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F2F2F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text("TODAY",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8E8E8E))),
                        ),
                      ),
                    ChatBubble(message: msg),
                  ],
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: const BoxDecoration(
            color: Color(0xFF212121),
            border: Border(top: BorderSide(color: Color(0x0FFFFFFF))),
          ),
          child: Row(
            children: [
              // Model chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2F2F2F),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, size: 14, color: Color(0xFF003F7A)),
                    const SizedBox(width: 4),
                    Text(
                      selected.length > 10 ? "${selected.substring(0, 10)}..." : selected,
                      style: const TextStyle(fontSize: 12, color: Color(0xFFB4B4B4)),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.expand_more, size: 14, color: Color(0xFF8E8E8E)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Attachment
              const Icon(Icons.attach_file, color: Color(0xFF8E8E8E), size: 22),
              const SizedBox(width: 8),
              // Text input
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  enabled: !_streaming,
                  style: const TextStyle(color: Color(0xFFECECEC), fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: "Ask Hermes anything...",
                    hintStyle: TextStyle(color: Color(0xFF8E8E8E), fontSize: 14),
                    filled: true,
                    fillColor: Color(0xFF171717),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              // Mic
              const Icon(Icons.mic, color: Color(0xFF8E8E8E), size: 22),
              const SizedBox(width: 8),
              // Send
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF003F7A),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _streaming ? null : _send,
                  icon: _streaming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 18),
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== MODEL SELECTOR ====================

  Widget _ModelSelector() {
    return Consumer(
      builder: (context, ref, _) {
        final modelsAsync = ref.watch(modelsProvider);
        final selected = ref.watch(selectedModelProvider);
        return modelsAsync.when(
          data: (models) {
            final active = models.where((m) => m.enabled).toList();
            return GestureDetector(
              onTap: () => _showModelSheet(context, ref, active, selected),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, color: Color(0xFF003F7A), size: 24),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      selected,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFFECECEC)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more, size: 18, color: Color(0xFF8E8E8E)),
                ],
              ),
            );
          },
          loading: () => const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF003F7A)),
          ),
          error: (_, __) => const Text("hermes-agent", style: TextStyle(color: Color(0xFFECECEC))),
        );
      },
    );
  }

  void _showModelSheet(BuildContext ctx, WidgetRef ref, List<ModelConfig> models, String current) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF171717),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("Select Model",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFECECEC))),
            ),
            ...models.map((m) => ListTile(
              leading: Icon(Icons.bolt,
                  color: m.name == current ? const Color(0xFF003F7A) : const Color(0xFF8E8E8E)),
              title: Text(m.name, style: const TextStyle(color: Color(0xFFECECEC))),
              subtitle: Text(m.provider,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
              selected: m.name == current,
              trailing: m.name == current
                  ? const Icon(Icons.check, color: Color(0xFF003F7A))
                  : null,
              onTap: () {
                ref.read(selectedModelProvider.notifier).state = m.name;
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }
}
