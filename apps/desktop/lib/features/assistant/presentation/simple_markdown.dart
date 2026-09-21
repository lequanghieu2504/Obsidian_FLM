import 'package:flutter/material.dart';

/// Minimal Markdown renderer for chat messages — headings (`#`/`##`/`###`),
/// **bold**, *italic*/_italic_, unordered (`-`/`*`) and ordered (`1.`)
/// lists, and horizontal rules (`---`).
///
/// Not a general Markdown engine (no tables, links, code blocks, nested
/// emphasis): Gemini's own answers reliably use only the constructs above,
/// and rendering exactly those — instead of showing the literal `#`/`*`
/// characters as plain text — is what was actually missing.
class SimpleMarkdown extends StatelessWidget {
  const SimpleMarkdown({
    super.key,
    required this.data,
    this.baseStyle,
    this.selectable = true,
  });

  final String data;
  final TextStyle? baseStyle;
  final bool selectable;

  static final _ruleLine = RegExp(r'^(-{3,}|\*{3,})$');
  static final _heading = RegExp(r'^(#{1,4})\s+(.*)$');
  static final _bullet = RegExp(r'^[-*]\s+(.*)$');
  static final _ordered = RegExp(r'^(\d+)\.\s+(.*)$');
  static final _emphasis = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|_(.+?)_');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = baseStyle ?? theme.textTheme.bodyLarge!;
    final lines = data.replaceAll('\r\n', '\n').split('\n');
    final blocks = <Widget>[];
    var paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _richText(paragraph.join(' '), body),
        ),
      );
      paragraph = [];
    }

    for (final rawLine in lines) {
      final trimmed = rawLine.trim();

      if (trimmed.isEmpty) {
        flushParagraph();
        continue;
      }

      if (_ruleLine.hasMatch(trimmed)) {
        flushParagraph();
        blocks.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ),
        );
        continue;
      }

      final heading = _heading.firstMatch(trimmed);
      if (heading != null) {
        flushParagraph();
        final level = heading.group(1)!.length;
        final text = heading.group(2)!;
        final style = switch (level) {
          1 => theme.textTheme.headlineSmall,
          2 => theme.textTheme.titleLarge,
          3 => theme.textTheme.titleMedium,
          _ => theme.textTheme.titleSmall,
        }?.copyWith(
          color: body.color,
          fontWeight: FontWeight.w700,
        );
        blocks.add(
          Padding(
            padding: EdgeInsets.only(top: level == 1 ? 4 : 12, bottom: 6),
            child: _richText(text, style ?? body),
          ),
        );
        continue;
      }

      final bullet = _bullet.firstMatch(trimmed);
      if (bullet != null) {
        flushParagraph();
        blocks.add(_listItem(context, '•', bullet.group(1)!, body));
        continue;
      }

      final ordered = _ordered.firstMatch(trimmed);
      if (ordered != null) {
        flushParagraph();
        blocks.add(
          _listItem(context, '${ordered.group(1)}.', ordered.group(2)!, body),
        );
        continue;
      }

      paragraph.add(trimmed);
    }
    flushParagraph();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
  }

  Widget _listItem(BuildContext context, String marker, String text, TextStyle style) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              marker,
              style: style.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: _richText(text, style)),
        ],
      ),
    );
  }

  Widget _richText(String text, TextStyle style) {
    final spans = _inlineSpans(text, style);
    return selectable
        ? SelectableText.rich(TextSpan(children: spans))
        : RichText(text: TextSpan(children: spans));
  }

  /// Parses `**bold**` and `*italic*`/`_italic_` inline, left to right, in
  /// one pass — single-level, non-nested emphasis, which is all Gemini's
  /// responses use.
  static List<InlineSpan> _inlineSpans(String text, TextStyle style) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in _emphasis.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start), style: style));
      }
      final bold = match.group(1);
      if (bold != null) {
        spans.add(TextSpan(text: bold, style: style.copyWith(fontWeight: FontWeight.bold)));
      } else {
        final italic = match.group(2) ?? match.group(3) ?? '';
        spans.add(TextSpan(text: italic, style: style.copyWith(fontStyle: FontStyle.italic)));
      }
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: style));
    }
    if (spans.isEmpty) spans.add(TextSpan(text: text, style: style));
    return spans;
  }
}
