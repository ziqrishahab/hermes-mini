import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/chat_message.dart';
import '../../theme.dart';
import 'markdown_body.dart';

class _ParsedToolCall {
  final String name;
  final String? input;
  final String? status;
  final String? output;

  const _ParsedToolCall({
    required this.name,
    this.input,
    this.status,
    this.output,
  });
}

class _ParsedMessage {
  final String? thinkingContent;
  final bool isThinkingComplete;
  final List<_ParsedToolCall> toolCalls;
  final String mainContent;

  const _ParsedMessage({
    this.thinkingContent,
    required this.isThinkingComplete,
    this.toolCalls = const [],
    required this.mainContent,
  });
}

_ParsedMessage _parseThinking(String raw) {
  String text = raw;
  final thinkingList = <String>[];
  bool isThinkingComplete = true;

  // 1. Matches completed <think>...</think> or <thinking>...</thinking>
  final completeRegex = RegExp(r'<(?:think|thinking)>([\s\S]*?)<\/(?:think|thinking)>', caseSensitive: false);
  for (final m in completeRegex.allMatches(text)) {
    final t = m.group(1)?.trim();
    if (t != null && t.isNotEmpty) {
      thinkingList.add(t);
    }
  }
  text = text.replaceAll(completeRegex, '').trim();

  // 2. Matches unclosed <think> or <thinking> while still streaming
  final openRegex = RegExp(r'<(?:think|thinking)>([\s\S]*)$', caseSensitive: false);
  final openMatch = openRegex.firstMatch(text);
  if (openMatch != null) {
    final t = openMatch.group(1)?.trim();
    if (t != null && t.isNotEmpty) {
      thinkingList.add(t);
    }
    isThinkingComplete = false;
    text = text.substring(0, openMatch.start).trim();
  }

  String? thinking = thinkingList.isNotEmpty ? thinkingList.join('\n\n') : null;
  if (thinking != null) {
    // Strip any CLI kaomoji spinner tickers (e.g. "(⊙_⊙) contemplating...", "( ˘ ͜ʖ ˘)♡ reasoning...")
    final tickerRegex = RegExp(r'[(\[（][^)\]）\n]*?[)\]）]\s*(?:contemplating|reasoning|brainstorming|reflecting|ruminating|cogitating|formulating|thinking)\.{3}\s*', caseSensitive: false);
    thinking = thinking.replaceAll(tickerRegex, '').trim();
    if (thinking.isEmpty) {
      thinking = null;
    }
  }

  // 3. Extract embedded <tool_call> tags
  final toolCalls = <_ParsedToolCall>[];
  final toolRegex = RegExp(r'<(?:tool_call|tool)(?:\s+name="([^"]+)")?>([\s\S]*?)<\/(?:tool_call|tool)>', caseSensitive: false);
  for (final m in toolRegex.allMatches(text)) {
    final nameAttr = m.group(1);
    final body = m.group(2)?.trim() ?? '';
    final nameMatch = RegExp(r'<name>([^<]+)<\/name>').firstMatch(body);
    final name = nameAttr ?? nameMatch?.group(1)?.trim() ?? 'tool';
    final argMatch = RegExp(r'<arguments>([\s\S]*?)<\/arguments>').firstMatch(body);
    final outMatch = RegExp(r'<(?:output|result)>([\s\S]*?)<\/(?:output|result)>').firstMatch(body);
    final input = argMatch?.group(1)?.trim() ?? (nameAttr != null ? body : null);
    final output = outMatch?.group(1)?.trim();
    
    toolCalls.add(_ParsedToolCall(
      name: name,
      input: input,
      status: 'completed',
      output: output,
    ));
  }
  text = text.replaceAll(toolRegex, '').trim();

  // 4. Extract unclosed streaming tool_call
  final openToolRegex = RegExp(r'<(?:tool_call|tool)(?:\s+name="([^"]+)")?>([\s\S]*)$', caseSensitive: false);
  final openToolMatch = openToolRegex.firstMatch(text);
  if (openToolMatch != null) {
    final nameAttr = openToolMatch.group(1);
    final body = openToolMatch.group(2)?.trim() ?? '';
    final nameMatch = RegExp(r'<name>([^<]+)<\/name>').firstMatch(body);
    final name = nameAttr ?? nameMatch?.group(1)?.trim() ?? 'tool';
    final argMatch = RegExp(r'<arguments>([\s\S]*?)<\/arguments>').firstMatch(body);
    final input = argMatch?.group(1)?.trim() ?? (nameAttr != null ? body : null);
    
    toolCalls.add(_ParsedToolCall(
      name: name,
      input: input,
      status: 'running',
      output: null,
    ));
    text = text.substring(0, openToolMatch.start).trim();
  }

  // 5. Extract completed mobile_action blocks
  final mobileMdRegex = RegExp(r'```mobile_action\s*([\s\S]*?)```', caseSensitive: false);
  for (final m in mobileMdRegex.allMatches(text)) {
    final rawJson = m.group(1)?.trim() ?? '';
    String actName = 'mobile_action';
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map && decoded['action'] != null) {
        actName = 'mobile_${decoded['action']}';
      }
    } catch (_) {}
    toolCalls.add(_ParsedToolCall(
      name: actName,
      input: rawJson,
      status: 'completed',
      output: null,
    ));
  }
  text = text.replaceAll(mobileMdRegex, '').trim();

  final mobileTagRegex = RegExp(r'<mobile_action>([\s\S]*?)</mobile_action>', caseSensitive: false);
  for (final m in mobileTagRegex.allMatches(text)) {
    final rawJson = m.group(1)?.trim() ?? '';
    String actName = 'mobile_action';
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map && decoded['action'] != null) {
        actName = 'mobile_${decoded['action']}';
      }
    } catch (_) {}
    toolCalls.add(_ParsedToolCall(
      name: actName,
      input: rawJson,
      status: 'completed',
      output: null,
    ));
  }
  text = text.replaceAll(mobileTagRegex, '').trim();

  // 6. Extract streaming unclosed mobile_action
  final openMobileMdRegex = RegExp(r'```mobile_action\s*([\s\S]*)$', caseSensitive: false);
  final openMobileMdMatch = openMobileMdRegex.firstMatch(text);
  if (openMobileMdMatch != null) {
    final rawJson = openMobileMdMatch.group(1)?.trim() ?? '';
    String actName = 'mobile_action';
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map && decoded['action'] != null) {
        actName = 'mobile_${decoded['action']}';
      }
    } catch (_) {}
    toolCalls.add(_ParsedToolCall(
      name: actName,
      input: rawJson,
      status: 'running',
      output: null,
    ));
    text = text.substring(0, openMobileMdMatch.start).trim();
  }

  return _ParsedMessage(
    thinkingContent: thinking,
    isThinkingComplete: isThinkingComplete,
    toolCalls: toolCalls,
    mainContent: text,
  );
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final void Function(String messageId)? onApprove;
  final void Function(String messageId)? onReject;
  final void Function(String messageId)? onContinue;

  const ChatBubble({
    super.key,
    required this.message,
    this.onApprove,
    this.onReject,
    this.onContinue,
  });

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final a = dt.hour >= 12 ? 'PM' : 'AM';
    return "$h:$m $a";
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final isTool = message.role == MessageRole.tool;
    final parsed = isUser ? null : _parseThinking(message.content);

    // Clean any injected device capability prompt from user bubble display
    String userDisplayContent = message.content;
    if (isUser) {
      if (userDisplayContent.contains('[DEVICE CONTROL CAPABILITY]')) {
        userDisplayContent = userDisplayContent.split('[DEVICE CONTROL CAPABILITY]').first.trim();
      }
      if (userDisplayContent.contains('[PRIVILEGED SHELL CAPABILITY]')) {
        userDisplayContent = userDisplayContent.split('[PRIVILEGED SHELL CAPABILITY]').first.trim();
      }
      if (userDisplayContent.contains('[RECENT LOCAL DEVICE CONTEXT:')) {
        userDisplayContent = userDisplayContent.split('[RECENT LOCAL DEVICE CONTEXT:').first.trim();
      }
      if (userDisplayContent.contains('[INSTRUCTION:')) {
        userDisplayContent = userDisplayContent.split('[INSTRUCTION:').first.trim();
      }

      final trimmed = userDisplayContent.trim();
      final lower = trimmed.toLowerCase();
      final isSynthetic =
          trimmed.isEmpty ||
          lower.startsWith("user approved mobile action") ||
          lower.startsWith("user declined/rejected the mobile action") ||
          lower.startsWith("user rejected the execution of mobile action") ||
          lower.startsWith("user declined the mobile action") ||
          lower.startsWith("observation from mobile execution:") ||
          lower.startsWith("you concluded your reasoning in <think>");

      if (isSynthetic) {
        return const SizedBox.shrink();
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: HermesTokens.messageGap),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
          // Agent label
          if (!isUser && !isTool)
            Padding(
              padding: EdgeInsets.only(left: 6, bottom: 5),
              child: Text(
                "HERMES",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: HermesTokens.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ),

          // Bubble Container with Asymmetric Border Radius (Tail)
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.86,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: HermesTokens.chatBubblePaddingH,
              vertical: HermesTokens.chatBubblePaddingV,
            ),
            decoration: BoxDecoration(
              color: isUser ? HermesTokens.userBubble : HermesTokens.agentBubble,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(HermesTokens.radiusLg),
                topRight: const Radius.circular(HermesTokens.radiusLg),
                bottomLeft: Radius.circular(isUser ? HermesTokens.radiusLg : 4.0),
                bottomRight: Radius.circular(isUser ? 4.0 : HermesTokens.radiusLg),
              ),
              border: isUser ? null : Border.all(color: HermesTokens.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Standalone Tool Message Accordion (if role is tool)
                if (isTool)
                  _ToolCallAccordion(
                    toolName: message.toolName ?? "tool",
                    toolStatus: message.toolStatus ?? (message.isStreaming ? "running" : "completed"),
                    input: message.toolInput,
                    output: message.toolOutput ?? (message.content.isNotEmpty ? message.content : null),
                    onApprove: onApprove != null ? () => onApprove!(message.id) : null,
                    onReject: onReject != null ? () => onReject!(message.id) : null,
                  ),

                // Tool calls with message.toolName on assistant messages
                if (!isTool && message.toolName != null)
                  _ToolCallAccordion(
                    toolName: message.toolName!,
                    toolStatus: message.toolStatus ?? (message.isStreaming ? "running" : "completed"),
                    input: message.toolInput,
                    output: message.toolOutput,
                  ),

                // Embedded Tool Calls inside parsed content
                if (parsed != null && parsed.toolCalls.isNotEmpty)
                  ...parsed.toolCalls.map(
                    (tc) => _ToolCallAccordion(
                      toolName: tc.name,
                      toolStatus: tc.status,
                      input: tc.input,
                      output: tc.output,
                    ),
                  ),

                // Thinking / Reasoning Block (if present)
                if (!isUser && parsed != null && parsed.thinkingContent != null && parsed.thinkingContent!.isNotEmpty)
                  _ThinkingBlock(
                    key: ValueKey('thinking_${message.id}'),
                    content: parsed.thinkingContent!,
                    isStreaming: !parsed.isThinkingComplete && message.isStreaming,
                    isComplete: parsed.isThinkingComplete,
                    hasResponseStarted: parsed.mainContent.trim().isNotEmpty,
                  ),

                // Main Answer Content
                if (isUser)
                  DefaultTextStyle(
                    style: const TextStyle(
                      fontSize: HermesTokens.fontSizeBody,
                      height: HermesTokens.lineHeightChat,
                      color: Colors.white,
                    ),
                    child: MarkdownBodyWidget(
                      content: userDisplayContent,
                      textColor: Colors.white,
                    ),
                  )
                else if (!isTool && parsed != null && parsed.mainContent.trim().isNotEmpty)
                  DefaultTextStyle(
                    style: TextStyle(
                      fontSize: HermesTokens.fontSizeBody,
                      height: HermesTokens.lineHeightChat,
                      color: HermesTokens.agentBubbleText,
                    ),
                    child: MarkdownBodyWidget(
                      content: parsed.mainContent,
                      textColor: HermesTokens.agentBubbleText,
                    ),
                  )
                else if (!isTool &&
                    !isUser &&
                    !message.isStreaming &&
                    message.toolName == null &&
                    (parsed == null || (parsed.mainContent.trim().isEmpty && parsed.toolCalls.isEmpty)))
                  _EmptyResponseNotice(
                    hasThinking: parsed?.thinkingContent != null && parsed!.thinkingContent!.trim().isNotEmpty,
                    onContinue: onContinue != null ? () => onContinue!(message.id) : null,
                  ),

                // Streaming indicator
                if (message.isStreaming)
                  Padding(
                    padding: EdgeInsets.only(
                      top: (parsed != null && parsed.mainContent.isNotEmpty) ? 6 : 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: HermesTokens.accent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          (parsed == null || (parsed.mainContent.isEmpty && (parsed.thinkingContent == null || parsed.thinkingContent!.isEmpty)))
                              ? "Thinking & preparing response..."
                              : "Responding...",
                          style: TextStyle(
                            fontSize: 11,
                            color: HermesTokens.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Timestamp
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: HermesTokens.fontSizeTime,
                color: HermesTokens.textMuted,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}

/// Collapsible Thinking / Reasoning Block
class _ThinkingBlock extends StatefulWidget {
  final String content;
  final bool isStreaming;
  final bool isComplete;
  final bool hasResponseStarted;

  const _ThinkingBlock({
    super.key,
    required this.content,
    required this.isStreaming,
    required this.isComplete,
    this.hasResponseStarted = false,
  });

  @override
  State<_ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<_ThinkingBlock> {
  bool? _isExpanded;

  // While model is actively thinking in stream, keep open.
  // As soon as thinking finishes and response starts, auto-collapse so UI stays clean!
  bool get expanded {
    if (_isExpanded != null) return _isExpanded!;
    if (widget.hasResponseStarted || widget.isComplete) return false;
    return widget.isStreaming;
  }

  @override
  void didUpdateWidget(covariant _ThinkingBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When thinking completes or response begins streaming, auto-collapse cleanly
    if ((!oldWidget.isComplete && widget.isComplete) ||
        (!oldWidget.hasResponseStarted && widget.hasResponseStarted)) {
      if (_isExpanded != false) {
        setState(() {
          _isExpanded = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: HermesTokens.bgTertiary.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
        border: Border.all(color: HermesTokens.borderBright, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Toggle
          InkWell(
            onTap: () => setState(() => _isExpanded = !expanded),
            borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  Icon(
                    widget.isStreaming ? Icons.psychology : Icons.psychology_outlined,
                    size: 15,
                    color: widget.isStreaming ? HermesTokens.accent : HermesTokens.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.isStreaming ? "Thinking..." : "Thought Process",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.isStreaming ? HermesTokens.accentText : HermesTokens.textMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  if (expanded && widget.content.length > 250) ...[
                    InkWell(
                      onTap: () => _openFullScreenViewer(
                        context,
                        title: "Thought Process",
                        content: widget.content,
                        badge: "THINKING",
                      ),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fullscreen_rounded,
                              size: 15,
                              color: HermesTokens.accent,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              "Expand",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: HermesTokens.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Icon(
                    expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: HermesTokens.textMuted,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(height: 1, color: HermesTokens.border),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: Scrollbar(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                            child: DefaultTextStyle(
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: HermesTokens.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                              child: MarkdownBodyWidget(
                                content: widget.content,
                                textColor: HermesTokens.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _isExpanded = false),
                        borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: HermesTokens.borderBright, width: 0.8)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.keyboard_arrow_up_rounded, size: 15, color: HermesTokens.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                "Minimize",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: HermesTokens.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}


class _EmptyResponseNotice extends StatelessWidget {
  final bool hasThinking;
  final VoidCallback? onContinue;

  const _EmptyResponseNotice({
    required this.hasThinking,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: HermesTokens.bgTertiary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
        border: Border.all(color: HermesTokens.borderBright, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hasThinking
                ? 'Model menyelesaikan penalaran tanpa mengeluarkan tindakan atau jawaban teks.'
                : 'Respons model kosong.',
            style: TextStyle(
              fontSize: 12,
              color: HermesTokens.textMuted,
              height: 1.4,
            ),
          ),
          if (onContinue != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: onContinue,
              borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: HermesTokens.cardBg,
                  borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
                  border: Border.all(color: HermesTokens.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 14,
                      color: HermesTokens.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Lanjutkan Respons',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: HermesTokens.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Running dots animation (Running. -> Running.. -> Running...)
class _RunningDots extends StatefulWidget {
  const _RunningDots();

  @override
  State<_RunningDots> createState() => _RunningDotsState();
}

class _RunningDotsState extends State<_RunningDots> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _dots = 1;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addListener(() {
        final step = (_ctrl.value * 3).floor() + 1;
        if (step != _dots && mounted) {
          setState(() => _dots = step);
        }
      })..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      "Running${'.' * _dots}",
      style: TextStyle(
        fontSize: 11,
        color: HermesTokens.textMuted,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Hermes-desktop style Collapsible Tool Call Accordion
class _ToolCallAccordion extends StatefulWidget {
  final String toolName;
  final String? toolStatus;
  final String? input;
  final String? output;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _ToolCallAccordion({
    required this.toolName,
    this.toolStatus,
    this.input,
    this.output,
    this.onApprove,
    this.onReject,

  });

  @override
  State<_ToolCallAccordion> createState() => _ToolCallAccordionState();
}

class _ToolCallAccordionState extends State<_ToolCallAccordion> {
  bool _expanded = false;

  String _formatInputDisplay(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        if (decoded.containsKey('command') && decoded.length == 1) {
          return '\$ ${decoded['command']}';
        }
        if (decoded.containsKey('cmd') && decoded.length == 1) {
          return '\$ ${decoded['cmd']}';
        }
        if (decoded.containsKey('CommandLine') && decoded.length == 1) {
          return '\$ ${decoded['CommandLine']}';
        }
        const encoder = JsonEncoder.withIndent('  ');
        return encoder.convert(decoded);
      }
    } catch (_) {}
    return raw;
  }

  String _formatOutputDisplay(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map || decoded is List) {
        const encoder = JsonEncoder.withIndent('  ');
        return encoder.convert(decoded);
      }
    } catch (_) {}
    return raw;
  }

  IconData _iconForTool(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('adb_shell') || lower.contains('shizuku_shell')) {
      return Icons.terminal_rounded;
    }
    if (lower.contains('mobile') ||
        lower.contains('device') ||
        lower.contains('phone') ||
        lower.contains('android')) {
      return Icons.phone_android_rounded;
    }
    if (lower.contains('bash') ||
        lower.contains('exec') ||
        lower.contains('cmd') ||
        lower.contains('sh') ||
        lower.contains('terminal')) {
      return Icons.terminal_rounded;
    }
    if (lower.contains('search') ||
        lower.contains('web') ||
        lower.contains('browser') ||
        lower.contains('fetch') ||
        lower.contains('curl')) {
      return Icons.travel_explore_rounded;
    }
    if (lower.contains('file') ||
        lower.contains('read') ||
        lower.contains('write') ||
        lower.contains('edit')) {
      return Icons.description_outlined;
    }
    if (lower.contains('cron') ||
        lower.contains('schedule') ||
        lower.contains('time')) {
      return Icons.schedule_rounded;
    }
    return Icons.build_outlined;
  }

  Widget _buildStatusText() {
    final status = (widget.toolStatus ?? 'completed').toLowerCase();
    if (status.contains('pending')) {
      return const Text(
        "Perlu Izin",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: HermesTokens.warning,
        ),
      );
    }
    if (status.contains('reject')) {
      return Text(
        "Ditolak",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: HermesTokens.textMuted,
        ),
      );
    }
    if (status.contains('run')) {
      return const _RunningDots();
    }
    if (status.contains('fail') || status.contains('err')) {
      return const Text(
        "Failed",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: HermesTokens.error,
        ),
      );
    }
    return Text(
      "Completed",
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: HermesTokens.textMuted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasDetails = (widget.input != null && widget.input!.isNotEmpty) ||
        (widget.output != null && widget.output!.isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: HermesTokens.bgTertiary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
        border: Border.all(color: HermesTokens.borderBright, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Approval Section for Sensitive Tools
          if (widget.toolStatus == 'pending_approval')
            Container(
              margin: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: HermesTokens.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
                border: Border.all(color: HermesTokens.warning.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "This action requires permission to execute:",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: HermesTokens.textPrimary,
                    ),
                  ),
                  if (widget.output != null && widget.output!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    SelectableText(
                      widget.output!,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: widget.toolName.toLowerCase().contains('shell') ? 'monospace' : null,
                        color: HermesTokens.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HermesTokens.textMuted,
                          side: BorderSide(color: HermesTokens.border),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: widget.onReject,
                        child: const Text("Tolak", style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HermesTokens.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: widget.onApprove,
                        child: const Text("Izinkan", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Header Row (Clickable)
          InkWell(
            onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
            borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  Icon(
                    _iconForTool(widget.toolName),
                    size: 15,
                    color: HermesTokens.textSecondary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      widget.toolName,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: HermesTokens.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Clean status text (Strictly NO badge background!)
                  _buildStatusText(),
                  if (hasDetails) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 16,
                      color: HermesTokens.textMuted,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Collapsible Details (Input & Output)
          if (_expanded && hasDetails) ...[
            Divider(height: 1, color: HermesTokens.border),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.input != null && widget.input!.isNotEmpty) ...[
                    Builder(
                      builder: (ctx) {
                        final formattedInput = _formatInputDisplay(widget.input!);
                        final inputLines = formattedInput.split('\n');
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "INPUT",
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: HermesTokens.textMuted,
                                  ),
                                ),
                                if (inputLines.length > 1) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    "(${inputLines.length} lines)",
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: HermesTokens.textMuted,
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: formattedInput));
                                    HapticFeedback.lightImpact();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Tool input copied"),
                                        duration: Duration(milliseconds: 900),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.copy_rounded, size: 11, color: HermesTokens.textMuted),
                                        const SizedBox(width: 3),
                                        Text(
                                          "Copy",
                                          style: TextStyle(fontSize: 10, color: HermesTokens.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (inputLines.length > 6 || formattedInput.length > 250) ...[
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => _openFullScreenViewer(
                                      context,
                                      title: "${widget.toolName} Input",
                                      content: formattedInput,
                                      badge: "INPUT",
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.fullscreen_rounded, size: 14, color: HermesTokens.accent),
                                          const SizedBox(width: 2),
                                          Text(
                                            "Expand",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: HermesTokens.accent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: HermesTokens.codeBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: HermesTokens.border),
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 200),
                                child: Scrollbar(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    padding: const EdgeInsets.all(8),
                                    child: SelectableText(
                                      formattedInput,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        color: HermesTokens.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                  if (widget.output != null && widget.output!.isNotEmpty) ...[
                    if (widget.input != null && widget.input!.isNotEmpty)
                      const SizedBox(height: 8),
                    Builder(
                      builder: (ctx) {
                        final formattedOutput = _formatOutputDisplay(widget.output!);
                        final outputLines = formattedOutput.split('\n');
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "OUTPUT",
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: HermesTokens.textMuted,
                                  ),
                                ),
                                if (outputLines.length > 1) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    "(${outputLines.length} lines)",
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: HermesTokens.textMuted,
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: formattedOutput));
                                    HapticFeedback.lightImpact();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Tool output copied"),
                                        duration: Duration(milliseconds: 900),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.copy_rounded, size: 11, color: HermesTokens.textMuted),
                                        const SizedBox(width: 3),
                                        Text(
                                          "Copy",
                                          style: TextStyle(fontSize: 10, color: HermesTokens.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (outputLines.length > 6 || formattedOutput.length > 250) ...[
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => _openFullScreenViewer(
                                      context,
                                      title: "${widget.toolName} Output",
                                      content: formattedOutput,
                                      badge: "OUTPUT",
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.fullscreen_rounded, size: 14, color: HermesTokens.accent),
                                          const SizedBox(width: 2),
                                          Text(
                                            "Expand",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: HermesTokens.accent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: HermesTokens.codeBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: HermesTokens.border),
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 280),
                                child: Scrollbar(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    padding: const EdgeInsets.all(8),
                                    child: SelectableText(
                                      formattedOutput,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        color: HermesTokens.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => setState(() => _expanded = false),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: HermesTokens.bgTertiary.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: HermesTokens.borderBright, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 15,
                            color: HermesTokens.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Minimize",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: HermesTokens.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),          ],
        ],
      ),
    );
  }
}



void _openFullScreenViewer(
  BuildContext context, {
  required String title,
  required String content,
  String? badge,
}) {
  final lines = content.split('\n');
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: const BoxDecoration(
          color: Color(0xFF1E222B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF181B22),
              ),
              child: Row(
                children: [
                  if (badge != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF282C34),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0x33FFFFFF)),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF61AFEF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    "${lines.length} lines",
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: const Color(0xFFABB2BF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: content));
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Copied to clipboard"),
                          duration: Duration(milliseconds: 900),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF282C34),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.copy_rounded, size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            "Copy",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFFABB2BF), size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(lines.length, (i) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Text(
                              "${i + 1}",
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                height: 1.5,
                                color: const Color(0xFF4B5263),
                              ),
                            ),
                          );
                        }),
                      ),
                      SelectableText(
                        content,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          height: 1.5,
                          color: const Color(0xFFABB2BF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
