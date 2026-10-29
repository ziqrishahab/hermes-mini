import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme.dart';

class MarkdownBodyWidget extends StatelessWidget {
  final String content;
  final Color? textColor;

  const MarkdownBodyWidget({super.key, required this.content, this.textColor});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = textColor ?? HermesTokens.textPrimary;
    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: GoogleFonts.inter(
          fontSize: HermesTokens.fontSizeBody,
          height: HermesTokens.lineHeightChat,
          color: effectiveColor,
        ),
        strong: GoogleFonts.inter(
          fontSize: HermesTokens.fontSizeBody,
          fontWeight: FontWeight.w700,
          color: effectiveColor,
        ),
        em: GoogleFonts.inter(
          fontSize: HermesTokens.fontSizeBody,
          fontStyle: FontStyle.italic,
          color: effectiveColor,
        ),
        code: GoogleFonts.jetBrainsMono(
          backgroundColor: (textColor != null && textColor == Colors.white)
              ? const Color(0x33FFFFFF)
              : HermesTokens.codeBg,
          fontSize: HermesTokens.fontSizeCode,
          color: effectiveColor,
        ),
        codeblockDecoration: BoxDecoration(
          color: (textColor != null && textColor == Colors.white)
              ? const Color(0x22FFFFFF)
              : HermesTokens.codeBg,
          borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
          border: Border.all(
              color: (textColor != null && textColor == Colors.white)
                  ? const Color(0x33FFFFFF)
                  : HermesTokens.border),
        ),
        h1: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: effectiveColor,
        ),
        h2: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: effectiveColor,
        ),
        h3: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: effectiveColor,
        ),
        h4: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: effectiveColor,
        ),
        a: GoogleFonts.inter(
          color: (textColor != null && textColor == Colors.white)
              ? const Color(0xFF93C5FD)
              : HermesTokens.accent,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: (textColor != null && textColor == Colors.white)
              ? const Color(0xFF93C5FD)
              : HermesTokens.accent,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: HermesTokens.accent, width: 3)),
          color: HermesTokens.accentSubtle,
        ),
        listBullet: GoogleFonts.inter(color: effectiveColor),
        listIndent: 20,
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
    final displayLanguage = language.isEmpty ? 'CODE' : language.toUpperCase();

    // Compact inline badge for inline code snippets (e.g. `/help`, commands, variables)
    if (!code.contains('\n') && language.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: HermesTokens.bgTertiary,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: HermesTokens.border, width: 0.8),
        ),
        child: Text(
          code,
          style: GoogleFonts.jetBrainsMono(
            fontSize: HermesTokens.fontSizeCode - 0.5,
            color: HermesTokens.accentText,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Builder(
      builder: (context) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: HermesTokens.codeBg,
            borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
            border: Border.all(color: HermesTokens.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Language label header with functional copy button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: HermesTokens.bgTertiary,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(HermesTokens.radiusSm - 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      displayLanguage,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: HermesTokens.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Code copied to clipboard'),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Icon(
                                Icons.copy_rounded,
                                size: 13,
                                color: HermesTokens.textMuted,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Copy",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: HermesTokens.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        InkWell(
                          onTap: () => _openFullScreenCodeViewer(
                            context,
                            code,
                            displayLanguage,
                            language,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.fullscreen_rounded,
                                size: 16,
                                color: HermesTokens.accent,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Expand",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: HermesTokens.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Code content with dark syntax highlighting and capped max-height
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: HighlightView(
                        code,
                        language: language.isEmpty ? 'plaintext' : language,
                        theme: atomOneDarkTheme,
                        padding: const EdgeInsets.all(12),
                        textStyle: GoogleFonts.jetBrainsMono(
                          fontSize: HermesTokens.fontSizeCode,
                          height: 1.5,
                        ),
                      ),
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

  void _openFullScreenCodeViewer(
    BuildContext context,
    String code,
    String displayLanguage,
    String language,
  ) {
    final lines = code.split('\n');
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
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF181B22),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF282C34),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0x33FFFFFF)),
                      ),
                      child: Text(
                        displayLanguage,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF61AFEF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "${lines.length} lines",
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: const Color(0xFFABB2BF),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("All code copied to clipboard"),
                            duration: Duration(seconds: 1),
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
                            Icon(Icons.copy_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              "Copy All",
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
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFFABB2BF), size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Line numbers gutter
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
                        // Syntax highlighted code
                        HighlightView(
                          code,
                          language: language.isEmpty ? 'plaintext' : language,
                          theme: atomOneDarkTheme,
                          padding: EdgeInsets.zero,
                          textStyle: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            height: 1.5,
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
}
