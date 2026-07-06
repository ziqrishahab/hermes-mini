import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import 'markdown_body.dart';

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

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Agent label
          if (!isUser && !isTool)
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                "HERMES",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8E8E8E),
                  letterSpacing: 1,
                ),
              ),
            ),

          // Bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFF003F7A) : const Color(0xFF2F2F2F),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isUser ? 14 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isTool && message.toolName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.build, size: 13, color: Color(0xFF003F7A)),
                        const SizedBox(width: 4),
                        Text(
                          message.toolName!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF003F7A),
                          ),
                        ),
                        if (message.toolStatus != null)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFF003F7A).withValues(alpha: 0.4)),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              message.toolStatus!,
                              style: const TextStyle(fontSize: 9, color: Color(0xFF003F7A)),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (message.content.isNotEmpty)
                  MarkdownBodyWidget(content: message.content),
                if (message.isStreaming)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF003F7A),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Timestamp
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _formatTime(message.timestamp),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8E8E8E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
