import 'dart:convert';

class SseEvent {
  final String type;
  final String? content;
  final Map<String, dynamic>? data;

  const SseEvent({required this.type, this.content, this.data});

  /// Parses an SSE line. Supports:
  /// - OpenAI-compatible chat completion chunks (`choices[0].delta.content`)
  /// - `[DONE]` termination markers
  /// - Error payloads (`error.message`)
  /// - Plain text / JSON fallbacks
  factory SseEvent.fromLine(String line) {
    if (!line.startsWith('data: ')) {
      return const SseEvent(type: 'unknown');
    }
    final payload = line.substring(6).trim();
    if (payload.isEmpty) {
      return const SseEvent(type: 'empty');
    }
    if (payload == '[DONE]') {
      return const SseEvent(type: 'done');
    }
    if (payload.startsWith('{')) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;

        final error = data['error'];
        if (error != null) {
          final message = error is Map<String, dynamic>
              ? (error['message'] as String? ?? payload)
              : error.toString();
          return SseEvent(type: 'error', content: message, data: data);
        }

        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final first = choices[0] as Map<String, dynamic>?;
          final delta = first?['delta'] as Map<String, dynamic>?;
          final deltaContent = delta?['content'] as String?;
          if (deltaContent != null) {
            return SseEvent(type: 'delta', content: deltaContent, data: data);
          }
        }

        return SseEvent(type: 'json', content: payload, data: data);
      } catch (_) {
        return SseEvent(type: 'text', content: payload);
      }
    }
    return SseEvent(type: 'text', content: payload);
  }
}
