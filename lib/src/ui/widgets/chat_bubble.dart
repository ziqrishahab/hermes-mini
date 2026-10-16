import 'dart:convert';
import 'package:flutter/material.dart';
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
  String? thinking;
  bool isThinkingComplete = true;

  // 1. Matches completed <think>...</think> or <thinking>...</thinking>
  final completeRegex = RegExp(r'<(?:think|thinking)>([\s\S]*?)<\/(?:think|thinking)>', caseSensitive: false);
  final match = completeRegex.firstMatch(text);

  if (match != null) {
    thinking = match.group(1)?.trim();
    text = text.replaceFirst(completeRegex, '').trim();
  } else {
    // 2. Matches unclosed <think> or <thinking> while still streaming
    final openRegex = RegExp(r'<(?:think|thinking)>([\s\S]*)$', caseSensitive: false);
    final openMatch = openRegex.firstMatch(text);
    if (openMatch != null) {
      thinking = openMatch.group(1)?.trim();
      isThinkingComplete = false;
      text = text.substring(0, openMatch.start).trim();
    }
  }

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

  return _ParsedMessage(
    thinkingContent: thinking,
    isThinkingComplete: isThinkingComplete,
    toolCalls: toolCalls,
    mainContent: text,
  );
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

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
            const Padding(
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
                    content: parsed.thinkingContent!,
                    isStreaming: !parsed.isThinkingComplete && message.isStreaming,
                    isComplete: parsed.isThinkingComplete,
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
                      content: message.content,
                      textColor: Colors.white,
                    ),
                  )
                else if (!isTool && parsed != null && parsed.mainContent.isNotEmpty)
                  DefaultTextStyle(
                    style: const TextStyle(
                      fontSize: HermesTokens.fontSizeBody,
                      height: HermesTokens.lineHeightChat,
                      color: HermesTokens.agentBubbleText,
                    ),
                    child: MarkdownBodyWidget(
                      content: parsed.mainContent,
                      textColor: HermesTokens.agentBubbleText,
                    ),
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
                        const SizedBox(
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
                          style: const TextStyle(
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
              style: const TextStyle(
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

  const _ThinkingBlock({
    required this.content,
    required this.isStreaming,
    required this.isComplete,
  });

  @override
  State<_ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<_ThinkingBlock> {
  bool? _isExpanded;

  bool get expanded => _isExpanded ?? (widget.isStreaming || !widget.isComplete);

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
                  Icon(
                    expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: HermesTokens.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: HermesTokens.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: DefaultTextStyle(
                style: const TextStyle(
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
      style: const TextStyle(
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

  const _ToolCallAccordion({
    required this.toolName,
    this.toolStatus,
    this.input,
    this.output,
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
    return const Text(
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
                      style: const TextStyle(
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
            const Divider(height: 1, color: HermesTokens.border),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.input != null && widget.input!.isNotEmpty) ...[
                    const Text(
                      "INPUT",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: HermesTokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: HermesTokens.codeBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: HermesTokens.border),
                      ),
                      child: SelectableText(
                        _formatInputDisplay(widget.input!),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: HermesTokens.textPrimary,
                        ),
                      ),
                    ),
                  ],
                  if (widget.output != null && widget.output!.isNotEmpty) ...[
                    if (widget.input != null && widget.input!.isNotEmpty)
                      const SizedBox(height: 8),
                    const Text(
                      "OUTPUT",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: HermesTokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: HermesTokens.codeBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: HermesTokens.border),
                      ),
                      child: SelectableText(
                        _formatOutputDisplay(widget.output!),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: HermesTokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

