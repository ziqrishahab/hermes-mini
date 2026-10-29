import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:google_fonts/google_fonts.dart";
import "../../providers/connection_provider.dart";
import "../../theme.dart";

class SoulEditorScreen extends ConsumerStatefulWidget {
  final String? profile;
  const SoulEditorScreen({super.key, this.profile});
  @override
  ConsumerState<SoulEditorScreen> createState() => _SoulEditorScreenState();
}

class _SoulEditorScreenState extends ConsumerState<SoulEditorScreen> {
  late final TextEditingController _ctrl;
  bool _loading = true;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _loadSoul();
  }

  Future<void> _loadSoul() async {
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn != null) {
      try {
        final content = await conn.readSoul(profile: widget.profile);
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

  Future<void> _saveSoul() async {
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) {
      _showSnackBar("Not connected to Hermes Gateway", isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await conn.writeSoul(_ctrl.text, profile: widget.profile);
      setState(() {
        _dirty = false;
        _saving = false;
      });
      _showSnackBar("Soul configuration saved successfully.");
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

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _extractName(String text) {
    final match = RegExp(r'^#\s*(?:Agent\s+)?Personality\s*\n*(.+)', multiLine: true).firstMatch(text);
    if (match != null) {
      final name = match.group(1)?.trim() ?? '';
      final firstToken = name.split('\n').first.split(' ').first.trim();
      if (firstToken.isNotEmpty) return firstToken;
    }
    if (widget.profile != null && widget.profile!.trim().isNotEmpty) {
      return widget.profile!.trim();
    }
    return 'Default Agent';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HermesTokens.bgPrimary,
      appBar: AppBar(
        backgroundColor: HermesTokens.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: HermesTokens.textPrimary),
          onPressed: () {
            if (_dirty) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: HermesTokens.bgElevated,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
                    side: BorderSide(color: HermesTokens.borderBright),
                  ),
                  title: Text("Discard changes?", style: TextStyle(color: HermesTokens.textPrimary, fontSize: 16)),
                  content: Text("You have unsaved changes in the soul file.", style: TextStyle(color: HermesTokens.textSecondary, fontSize: 13)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text("Keep Editing", style: TextStyle(color: HermesTokens.textMuted)),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: HermesTokens.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
                        ),
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
          widget.profile != null ? "Soul (${widget.profile})" : "Soul Configuration",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Profile avatar section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: NeumorphicDecoration.raised(radius: 14),
                    child: Icon(
                      Icons.psychology_outlined,
                      size: 24,
                      color: HermesTokens.accent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _extractName(_ctrl.text),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: HermesTokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Agent system prompt & personality guidelines",
                          style: TextStyle(
                            fontSize: 12,
                            color: HermesTokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: HermesTokens.divider, height: 1),
            // Section label
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "SOUL.MD EDITOR",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: HermesTokens.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // Editor
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
                            hintText: "# Agent Personality\nDefine system instructions, tone, and behavioral directives...",
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

            // Save button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
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
                    onTap: _saving ? null : _saveSoul,
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
                            _saving ? "Saving..." : "Save Configuration",
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
