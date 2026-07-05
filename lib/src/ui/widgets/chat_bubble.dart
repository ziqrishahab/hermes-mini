import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import 'markdown_body.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isUser = message.role == MessageRole.user;
    final isTool = message.role == MessageRole.tool;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? colorScheme.primaryContainer
              : const Color(0xFF242424),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isTool && message.toolName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.build, size: 14, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      message.toolName!,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                    if (message.toolStatus != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: colorScheme.primary.withValues(alpha: 0.5),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            message.toolStatus!,
                            style: textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (message.content.isNotEmpty)
              MarkdownBodyWidget(content: message.content),
            if (message.isStreaming)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
