import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:url_launcher/url_launcher.dart';

class MarkdownBodyWidget extends StatelessWidget {
  final String content;

  const MarkdownBodyWidget({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(
          fontSize: 14,
          height: 1.65,
          color: Color(0xFFECECEC),
        ),
        code: const TextStyle(
          backgroundColor: Color(0xFF1A1A1A),
          fontFamily: 'monospace',
          fontSize: 12,
          color: Color(0xFFECECEC),
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(6),
        ),
        h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFFECECEC)),
        h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFFECECEC)),
        h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFECECEC)),
        a: const TextStyle(color: Color(0xFF006ACD)),
        blockquoteDecoration: BoxDecoration(
          border: const Border(left: BorderSide(color: Color(0xFF003F7A), width: 3)),
          color: const Color(0xFF003F7A).withValues(alpha: 0.08),
        ),
      ),
      onTapLink: (text, href, title) {
        if (href != null) {
          final uri = Uri.tryParse(href);
          if (uri != null && uri.hasScheme) {
            try {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {}
          }
        }
      },
      builders: {'code': CodeElementBuilder()},
    );
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(element, preferredStyle) {
    final language =
        element.attributes['class']?.replaceFirst('language-', '') ?? '';
    final code = element.textContent;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: HighlightView(
        code,
        language: language.isEmpty ? 'plaintext' : language,
        theme: githubTheme,
        padding: const EdgeInsets.all(12),
        textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}
