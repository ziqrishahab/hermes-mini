import "package:flutter/material.dart";
import "../../theme.dart";

class ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextStyle? actionStyle;

  const ExpandableText({
    super.key,
    required this.text,
    this.style,
    this.maxLines = 3,
    this.actionStyle,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();

    final defaultStyle = widget.style ??
        const TextStyle(
          fontSize: 12,
          color: HermesTokens.textMuted,
          height: 1.35,
        );
    final linkStyle = widget.actionStyle ??
        const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: HermesTokens.accent,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = TextSpan(text: widget.text, style: defaultStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          maxLines: widget.maxLines,
        )..layout(maxWidth: constraints.maxWidth > 0 ? constraints.maxWidth : 300);

        if (!textPainter.didExceedMaxLines) {
          return Text(widget.text, style: defaultStyle);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.text,
              style: defaultStyle,
              maxLines: _isExpanded ? null : widget.maxLines,
              overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  _isExpanded ? "Read less" : "Read more",
                  style: linkStyle,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
