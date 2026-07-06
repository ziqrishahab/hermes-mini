import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

class SoulEditorScreen extends ConsumerStatefulWidget {
  const SoulEditorScreen({super.key});
  @override
  ConsumerState<SoulEditorScreen> createState() => _SoulEditorScreenState();
}

class _SoulEditorScreenState extends ConsumerState<SoulEditorScreen> {
  late final TextEditingController _ctrl;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _defaultSoul);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static const _defaultSoul = """# Agent Personality
Julian is a highly analytical executive assistant with a focus on precision and rapid execution. He prefers concise communication and proactive problem-solving.

# Communication Style
- Direct and concise
- No sugarcoating
- Uses casual language when appropriate
- Technical depth when needed

# Boundaries
- No emoji or emoticons
- No motivational speeches
- Be honest when you don't know""";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF212121),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF003F7A)),
          onPressed: () {
            if (_dirty) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF212121),
                  title: const Text("Discard changes?", style: TextStyle(color: Color(0xFFECECEC))),
                  content: const Text("You have unsaved changes.", style: TextStyle(color: Color(0xFFB4B4B4))),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Keep Editing", style: TextStyle(color: Color(0xFF8E8E8E))),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
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
        title: const Text(
          "Soul MD Editor",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFECECEC)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Section label
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "EDITOR",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8E8E8E),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),

            // Editor
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF171717),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    onChanged: (_) => setState(() => _dirty = true),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      color: Color(0xFFECECEC),
                      fontSize: 14,
                      height: 1.7,
                      fontFamily: "monospace",
                    ),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.all(16),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),

            // Save button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    setState(() => _dirty = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Soul configuration saved."),
                        backgroundColor: Color(0xFF22C55E),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    context.pop();
                  },
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text("Save Changes"),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
