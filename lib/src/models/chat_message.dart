enum MessageRole { user, assistant, system, tool, reasoning }

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final String? toolName;
  final String? toolStatus;
  final String? toolInput;
  final String? toolOutput;
  final bool isStreaming;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.toolName,
    this.toolStatus,
    this.toolInput,
    this.toolOutput,
    this.isStreaming = false,
  });

  ChatMessage copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    String? toolName,
    String? toolStatus,
    String? toolInput,
    String? toolOutput,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      toolName: toolName ?? this.toolName,
      toolStatus: toolStatus ?? this.toolStatus,
      toolInput: toolInput ?? this.toolInput,
      toolOutput: toolOutput ?? this.toolOutput,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
