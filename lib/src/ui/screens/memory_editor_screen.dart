import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:google_fonts/google_fonts.dart";
import "../../providers/connection_provider.dart";
import "../../theme.dart";

class _ParsedFact {
  final String category;
  final String text;
  final int rawLineIndex;

  _ParsedFact({required this.category, required this.text, required this.rawLineIndex});
}

class MemoryEditorScreen extends ConsumerStatefulWidget {
  final String? profile;
  const MemoryEditorScreen({super.key, this.profile});
  @override
  ConsumerState<MemoryEditorScreen> createState() => _MemoryEditorScreenState();
}

class _MemoryEditorScreenState extends ConsumerState<MemoryEditorScreen> {
  late final TextEditingController _ctrl;
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = true;
  bool _dirty = false;
  bool _saving = false;
  int _viewMode = 0; // 0 = Facts, 1 = Raw Markdown
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _loadMemory();
  }

  Future<void> _loadMemory() async {
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn != null) {
      try {
        final content = await conn.readMemory(profile: widget.profile);
        if (mounted) {
          setState(() {
            _ctrl.text = content;
            _dirty = false;
            _loading = false;
          });
          return;
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveMemory() async {
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) {
      _showSnackBar("Not connected to Hermes Gateway", isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await conn.writeMemory(_ctrl.text, profile: widget.profile);
      setState(() {
        _dirty = false;
        _saving = false;
      });
      _showSnackBar("Memory notes saved successfully.");
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _saving = false);
      _showSnackBar("Failed to save: $e", isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? HermesTokens.error : HermesTokens.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<_ParsedFact> _extractFacts(String md) {
    final lines = md.split('\n');
    final list = <_ParsedFact>[];
    String currentCategory = "General";

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#')) {
        currentCategory = line.replaceAll(RegExp(r'^#+\s*'), '').trim();
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        final factText = line.substring(2).trim();
        if (factText.isNotEmpty) {
          list.add(_ParsedFact(category: currentCategory, text: factText, rawLineIndex: i));
        }
      }
    }
    return list;
  }

  void _deleteFact(int rawLineIndex) {
    final lines = _ctrl.text.split('\n');
    if (rawLineIndex >= 0 && rawLineIndex < lines.length) {
      lines.removeAt(rawLineIndex);
      setState(() {
        _ctrl.text = lines.join('\n');
        _dirty = true;
      });
      _showSnackBar("Fact removed. Save to apply.");
    }
  }

  void _showAddFactDialog() {
    final factCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HermesTokens.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          "Add Learned Fact",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Fact text",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HermesTokens.textMuted),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: NeumorphicDecoration.recessed(radius: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: factCtrl,
                maxLines: 3,
                style: TextStyle(fontSize: 13, color: HermesTokens.textPrimary),
                decoration: InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: "Fact or preference",
                  hintStyle: TextStyle(fontSize: 13, color: HermesTokens.textMuted),
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: HermesTokens.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HermesTokens.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final text = factCtrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);

              final current = _ctrl.text.trim();
              final updated = "$current\n- $text\n";
              setState(() {
                _ctrl.text = updated;
                _dirty = true;
              });
              _showSnackBar("Fact added. Remember to save changes.");
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allFacts = _extractFacts(_ctrl.text);
    final filteredFacts = _searchQuery.isEmpty
        ? allFacts
        : allFacts.where((f) {
            return f.text.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                f.category.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

    return Scaffold(
      backgroundColor: HermesTokens.bgPrimary,
      appBar: AppBar(
        backgroundColor: HermesTokens.bgPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: HermesTokens.textPrimary),
          onPressed: () {
            if (_dirty) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: HermesTokens.bgElevated,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text(
                    "Discard changes?",
                    style: TextStyle(color: HermesTokens.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  content: Text(
                    "You have unsaved changes in MEMORY.md.",
                    style: TextStyle(color: HermesTokens.textSecondary, fontSize: 13),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text("Keep Editing", style: TextStyle(color: HermesTokens.textMuted)),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: HermesTokens.error,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.pop();
                      },
                      child: const Text("Discard"),
                    ),
                  ],
                ),
              );
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          widget.profile != null && widget.profile!.isNotEmpty && widget.profile != 'default'
              ? "Memory (${widget.profile})"
              : "Agent Memory",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
        ),
        centerTitle: true,
        actions: [
          if (_viewMode == 0)
            IconButton(
              tooltip: "Add fact",
              icon: Icon(Icons.add_rounded, color: HermesTokens.accent),
              onPressed: _showAddFactDialog,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Segmented mode selector
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Container(
                decoration: NeumorphicDecoration.recessed(radius: 12),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _viewMode = 0),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: _viewMode == 0
                              ? NeumorphicDecoration.switcherThumb(radius: 10)
                              : null,
                          child: Center(
                            child: Text(
                              "Facts (${allFacts.length})",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _viewMode == 0 ? FontWeight.w700 : FontWeight.w500,
                                color: _viewMode == 0 ? HermesTokens.accent : HermesTokens.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _viewMode = 1),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: _viewMode == 1
                              ? NeumorphicDecoration.switcherThumb(radius: 10)
                              : null,
                          child: Center(
                            child: Text(
                              "Raw Markdown",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _viewMode == 1 ? FontWeight.w700 : FontWeight.w500,
                                color: _viewMode == 1 ? HermesTokens.accent : HermesTokens.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_viewMode == 0) ...[
              // Search field
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  decoration: NeumorphicDecoration.recessed(radius: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 18, color: HermesTokens.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _searchQuery = v.trim()),
                          style: TextStyle(fontSize: 13, color: HermesTokens.textPrimary),
                          decoration: InputDecoration(
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: "Search facts...",
                            hintStyle: TextStyle(fontSize: 13, color: HermesTokens.textMuted),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = "");
                          },
                          child: Icon(Icons.close_rounded, size: 16, color: HermesTokens.textMuted),
                        ),
                    ],
                  ),
                ),
              ),

              // Facts list
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: HermesTokens.accent,
                        ),
                      )
                    : filteredFacts.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty ? "No facts stored in memory." : "No matching facts.",
                          style: TextStyle(fontSize: 13, color: HermesTokens.textMuted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: filteredFacts.length,
                        itemBuilder: (ctx, i) {
                          final f = filteredFacts[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: NeumorphicDecoration.raised(radius: 12, distance: 2, blur: 4),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          f.category.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                            color: HermesTokens.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          f.text,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: HermesTokens.textPrimary,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.copy_rounded, size: 16, color: HermesTokens.textMuted),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    tooltip: "Copy fact",
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: f.text));
                                      _showSnackBar("Copied fact to clipboard");
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, size: 16, color: HermesTokens.textMuted),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    tooltip: "Remove fact",
                                    onPressed: () => _deleteFact(f.rawLineIndex),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ] else ...[
              // Raw Markdown Editor
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: HermesTokens.accent,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: NeumorphicDecoration.recessed(radius: 16),
                          child: TextField(
                            controller: _ctrl,
                            onChanged: (_) => setState(() => _dirty = true),
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: GoogleFonts.jetBrainsMono(
                              color: HermesTokens.textPrimary,
                              fontSize: 13,
                              height: 1.6,
                            ),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.all(16),
                              hintText: "# Agent Memory\n- Add long-term facts or preferences...",
                              hintStyle: GoogleFonts.jetBrainsMono(
                                color: HermesTokens.textMuted,
                                fontSize: 13,
                                height: 1.6,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              fillColor: Colors.transparent,
                            ),
                          ),
                        ),
                      ),
              ),
            ],

            // Save button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Container(
                width: double.infinity,
                decoration: NeumorphicDecoration.raised(
                  radius: 14,
                  distance: 3.5,
                  blur: 7,
                  color: HermesTokens.accent,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _saving ? null : _saveMemory,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_saving)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          else
                            const Icon(Icons.save_outlined, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            _saving ? "Saving..." : "Save Memory",
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
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
      ),
    );
  }
}
