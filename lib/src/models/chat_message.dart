enum MessageRole { user, assistant, system, tool, reasoning }

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final String? toolName;
  final String? toolStatus;
  final bool isStreaming;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.toolName,
    this.toolStatus,
    this.isStreaming = false,
  });

  ChatMessage copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    String? toolName,
    String? toolStatus,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      toolName: toolName ?? this.toolName,
      toolStatus: toolStatus ?? this.toolStatus,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
