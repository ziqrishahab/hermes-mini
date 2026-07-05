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
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: HighlightView(
        code,
        language: language.isEmpty ? 'plaintext' : language,
        theme: githubTheme,
        padding: const EdgeInsets.all(12),
        textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    );
  }
}
