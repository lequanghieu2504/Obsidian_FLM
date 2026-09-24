import 'package:flutter/material.dart';

/// Minimal Markdown renderer for chat messages — headings (`#`/`##`/`###`),
/// **bold**, *italic*/_italic_, unordered (`-`/`*`) and ordered (`1.`)
/// lists, horizontal rules (`---`), and GitHub-style pipe tables.
///
/// Also normalizes simple inline LaTeX math (`$...$`/`$$...$$`, e.g.
/// `$\ge 4.0$`, `$x^2$`) into plain Unicode characters (`≥`, `x²`, ...)
/// instead of showing the raw backslash-command source, since Gemini's
/// answers use LaTeX-style math but this app has no LaTeX renderer.
///
/// Not a general Markdown engine (no links, code blocks, nested emphasis):
/// Gemini's own answers reliably use only the constructs above, and
/// rendering exactly those — instead of showing the literal `#`/`*`/`|`/`$`
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
  static final _tableSeparatorCell = RegExp(r'^:?-{1,}:?$');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = baseStyle ?? theme.textTheme.bodyLarge!;
    final normalized = _normalizeMath(data);
    final lines = normalized.replaceAll('\r\n', '\n').split('\n');
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

    var i = 0;
    while (i < lines.length) {
      final trimmed = lines[i].trim();

      if (trimmed.isEmpty) {
        flushParagraph();
        i++;
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
        i++;
        continue;
      }

      if (trimmed.contains('|') &&
          i + 1 < lines.length &&
          _isTableSeparator(lines[i + 1])) {
        flushParagraph();
        final headers = _splitTableRow(trimmed);
        final rows = <List<String>>[];
        var j = i + 2;
        while (j < lines.length &&
            lines[j].trim().isNotEmpty &&
            lines[j].trim().contains('|')) {
          rows.add(_splitTableRow(lines[j]));
          j++;
        }
        blocks.add(
          _MarkdownTable(
            headers: headers,
            rows: rows,
            body: body,
            selectable: selectable,
          ),
        );
        i = j;
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
        i++;
        continue;
      }

      final bullet = _bullet.firstMatch(trimmed);
      if (bullet != null) {
        flushParagraph();
        blocks.add(_listItem(context, '•', bullet.group(1)!, body));
        i++;
        continue;
      }

      final ordered = _ordered.firstMatch(trimmed);
      if (ordered != null) {
        flushParagraph();
        blocks.add(
          _listItem(context, '${ordered.group(1)}.', ordered.group(2)!, body),
        );
        i++;
        continue;
      }

      paragraph.add(trimmed);
      i++;
    }
    flushParagraph();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
  }

  bool _isTableSeparator(String line) {
    final cells = _splitTableRow(line);
    if (cells.isEmpty) return false;
    return cells.every((cell) => _tableSeparatorCell.hasMatch(cell.trim()));
  }

  static List<String> _splitTableRow(String line) {
    var trimmed = line.trim();
    if (trimmed.startsWith('|')) trimmed = trimmed.substring(1);
    if (trimmed.endsWith('|')) trimmed = trimmed.substring(0, trimmed.length - 1);
    return trimmed.split('|').map((cell) => cell.trim()).toList();
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

  // --- Inline-math normalization ------------------------------------------
  //
  // Gemini frequently writes simple LaTeX math (`$\ge 4.0$`, `$x^2$`,
  // `$\frac{1}{2}$`) even in plain chat answers. There's no LaTeX renderer
  // here, so instead of showing the raw backslash-command source, `$...$`/
  // `$$...$$` spans are rewritten to the closest plain Unicode text
  // (`≥ 4.0`, `x²`, `1/2`) and the `$` delimiters are dropped.

  static final _blockMath = RegExp(r'\$\$(.+?)\$\$', dotAll: true);
  static final _inlineMath = RegExp(r'\$([^\n$]+?)\$');
  static final _looksLikeMath = RegExp(r'[\\<>=^_]|\d');

  static String _normalizeMath(String input) {
    var out = input.replaceAllMapped(
      _blockMath,
      (match) => _convertLatex(match.group(1)!),
    );
    out = out.replaceAllMapped(_inlineMath, (match) {
      final content = match.group(1)!;
      if (!_looksLikeMath.hasMatch(content)) return match.group(0)!;
      return _convertLatex(content);
    });
    return out;
  }

  static const _superscripts = {
    '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
    '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
    '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾', 'n': 'ⁿ',
  };
  static const _subscripts = {
    '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
    '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
    '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎',
  };

  /// Ordered longest-command-first so e.g. `\geq` is replaced before `\ge`
  /// (otherwise `\geq` would become `≥q`).
  static const _latexSymbols = <String, String>{
    r'\leqslant': '≤', r'\geqslant': '≥',
    r'\rightarrow': '→', r'\Rightarrow': '⇒',
    r'\leftarrow': '←', r'\Leftarrow': '⇐',
    r'\notin': '∉', r'\subseteq': '⊆', r'\supseteq': '⊇',
    r'\approx': '≈', r'\neq': '≠', r'\geq': '≥', r'\leq': '≤',
    r'\times': '×', r'\div': '÷', r'\cdot': '·', r'\pm': '±', r'\mp': '∓',
    r'\infty': '∞', r'\forall': '∀', r'\exists': '∃', r'\in': '∈',
    r'\subset': '⊂', r'\supset': '⊃', r'\cup': '∪', r'\cap': '∩',
    r'\sum': '∑', r'\prod': '∏', r'\int': '∫', r'\partial': '∂',
    r'\sqrt': '√', r'\ldots': '…', r'\cdots': '⋯', r'\to': '→',
    r'\alpha': 'α', r'\beta': 'β', r'\gamma': 'γ', r'\delta': 'δ',
    r'\epsilon': 'ε', r'\theta': 'θ', r'\lambda': 'λ', r'\mu': 'μ',
    r'\pi': 'π', r'\sigma': 'σ', r'\phi': 'φ', r'\omega': 'ω',
    r'\Delta': 'Δ', r'\Sigma': 'Σ', r'\Omega': 'Ω',
    r'\ge': '≥', r'\le': '≤', r'\ne': '≠',
    r'\%': '%',
  };

  static String _convertLatex(String expr) {
    var s = expr;
    // Strip text-mode wrappers, keeping their content: \text{Final Exam} -> Final Exam
    s = s.replaceAllMapped(
      RegExp(r'\\(?:text|mathrm|mathbf|textbf|mathit)\{([^{}]*)\}'),
      (m) => m.group(1)!,
    );
    // \frac{a}{b} -> a/b
    s = s.replaceAllMapped(
      RegExp(r'\\frac\{([^{}]*)\}\{([^{}]*)\}'),
      (m) => '${m.group(1)}/${m.group(2)}',
    );
    for (final entry in _latexSymbols.entries) {
      s = s.replaceAll(entry.key, entry.value);
    }
    // √{x} -> √x (the \sqrt command above already became "√", leaving the
    // argument in braces).
    s = s.replaceAllMapped(RegExp(r'√\{([^{}]*)\}'), (m) => '√${m.group(1)}');
    // Superscript/subscript: map digits/common symbols to Unicode
    // super/subscript characters; anything unmappable is left as-is
    // (dropping only the `^`/`_`/braces) rather than lost.
    s = s.replaceAllMapped(RegExp(r'\^\{([^{}]*)\}|\^(\S)'), (m) {
      final content = m.group(1) ?? m.group(2) ?? '';
      return content.split('').map((c) => _superscripts[c] ?? c).join();
    });
    s = s.replaceAllMapped(RegExp(r'_\{([^{}]*)\}|_(\S)'), (m) {
      final content = m.group(1) ?? m.group(2) ?? '';
      return content.split('').map((c) => _subscripts[c] ?? c).join();
    });
    s = s.replaceAll(r'\left', '').replaceAll(r'\right', '');
    s = s.replaceAll(RegExp(r'\\[,;!]'), ' ');
    s = s.replaceAll('{', '').replaceAll('}', '');
    return s.trim();
  }
}

/// A GitHub-style pipe table rendered as an actual data grid — bold header
/// row, zebra-striped body, and an always-visible horizontal [Scrollbar]
/// for wide tables — instead of the raw `| a | b |` text or an invisible
/// scroll area the user has to guess is there. A `StatefulWidget` only so
/// it can own the [ScrollController] the scrollbar needs (an unscoped
/// `Scrollbar` can't tell which scroll view — this table's, or the
/// surrounding message list's — it belongs to).
class _MarkdownTable extends StatefulWidget {
  const _MarkdownTable({
    required this.headers,
    required this.rows,
    required this.body,
    required this.selectable,
  });

  final List<String> headers;
  final List<List<String>> rows;
  final TextStyle body;
  final bool selectable;

  @override
  State<_MarkdownTable> createState() => _MarkdownTableState();
}

class _MarkdownTableState extends State<_MarkdownTable> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _columnWidth(int index) {
    final headers = widget.headers;
    var maxLen = index < headers.length ? headers[index].length : 0;
    for (final row in widget.rows) {
      if (index < row.length && row[index].length > maxLen) {
        maxLen = row[index].length;
      }
    }
    return (maxLen * 7.0 + 24).clamp(72, 320);
  }

  Widget _cell(String text, TextStyle style) {
    final spans = SimpleMarkdown._inlineSpans(text, style);
    return widget.selectable
        ? SelectableText.rich(TextSpan(children: spans))
        : RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headers = widget.headers;
    final rows = widget.rows;
    final body = widget.body;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Scrollbar(
          controller: _controller,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.top,
              border: TableBorder(
                horizontalInside: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              columnWidths: {
                for (var i = 0; i < headers.length; i++)
                  i: FixedColumnWidth(_columnWidth(i)),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  children: [
                    for (final header in headers)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: _cell(
                          header,
                          body.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
                for (var r = 0; r < rows.length; r++)
                  TableRow(
                    decoration: BoxDecoration(
                      color: r.isEven
                          ? Colors.transparent
                          : theme.colorScheme.surfaceContainerLow,
                    ),
                    children: [
                      for (var c = 0; c < headers.length; c++)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: _cell(
                            c < rows[r].length ? rows[r][c] : '',
                            body,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
