enum CourseDescriptionBlockType { paragraph, heading, bullets, table }

class CourseDescriptionRow {
  const CourseDescriptionRow(this.label, this.value);

  final String label;
  final String value;
}

class CourseDescriptionBlock {
  const CourseDescriptionBlock._(
    this.type, {
    this.text = '',
    this.items = const [],
    this.rows = const [],
  });

  const CourseDescriptionBlock.paragraph(String text)
    : this._(CourseDescriptionBlockType.paragraph, text: text);

  const CourseDescriptionBlock.heading(String text)
    : this._(CourseDescriptionBlockType.heading, text: text);

  const CourseDescriptionBlock.bullets(List<String> items)
    : this._(CourseDescriptionBlockType.bullets, items: items);

  const CourseDescriptionBlock.table(List<CourseDescriptionRow> rows)
    : this._(CourseDescriptionBlockType.table, rows: rows);

  final CourseDescriptionBlockType type;
  final String text;
  final List<String> items;
  final List<CourseDescriptionRow> rows;
}

/// Turns syllabus descriptions, which are commonly stored as one flattened
/// line, back into readable semantic blocks without changing the source data.
List<CourseDescriptionBlock> formatCourseDescription(String source) {
  var text = source
      .trim()
      .replaceFirst(RegExp(r'''^['"]+'''), '')
      .replaceFirst(RegExp(r'''['"]+$'''), '')
      .replaceAll(RegExp(r'[\t\r\n ]+'), ' ')
      .trim();
  if (text.isEmpty) return const [];

  // Repair the most common export artefact: a full stop immediately followed
  // by the next sentence. Lowercase abbreviations and decimal numbers are left
  // untouched.
  text = text.replaceAllMapped(
    RegExp(r'([.!?])(?=[A-ZÀ-Ỹ])'),
    (match) => '${match.group(1)} ',
  );

  const namedHeadings = <String>{
    'Target',
    'Implementation',
    'Key Learning Outcomes',
    'Major Instructional Areas',
    'Course Objectives',
    'Learning Outcomes',
  };
  for (final heading in namedHeadings) {
    text = text.replaceAllMapped(
      RegExp('(?:^|\\s)(${RegExp.escape(heading)}):\\s*', caseSensitive: false),
      (match) => '\n§${match.group(1)}\n',
    );
  }

  // Numbered labels such as "1) Knowledge:" and
  // "2. the following skills:" are section headings, not prose.
  text = text.replaceAllMapped(
    RegExp(r'(?:^|\s)(\d+[.)]\s*[^:]{2,64}):\s*'),
    (match) => '\n§${match.group(1)!.trim()}\n',
  );

  // A hyphen is a bullet only at a content boundary and before a letter. This
  // deliberately preserves terms such as end-user, 3-5 and URL paths.
  text = text.replaceAll('•', '\n• ');
  text = text.replaceAllMapped(RegExp(r'(^|\s|[:.!?])-\s*(?=[A-ZÀ-Ỹ])'), (
    match,
  ) {
    final boundary = match.group(1)!;
    return '${boundary.trim()}\n• ';
  });

  final blocks = <CourseDescriptionBlock>[];
  final pendingBullets = <String>[];

  void flushBullets() {
    if (pendingBullets.isEmpty) return;
    final rows = pendingBullets.map(_asShortLabelValue).toList();
    if (rows.length >= 3 && rows.every((row) => row != null)) {
      blocks.add(
        CourseDescriptionBlock.table(rows.cast<CourseDescriptionRow>()),
      );
    } else {
      blocks.add(CourseDescriptionBlock.bullets(List.of(pendingBullets)));
    }
    pendingBullets.clear();
  }

  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('•')) {
      final item = line.substring(1).trim();
      if (item.isNotEmpty) pendingBullets.add(item);
      continue;
    }
    flushBullets();
    if (line.startsWith('§')) {
      blocks.add(CourseDescriptionBlock.heading(line.substring(1).trim()));
    } else {
      blocks.addAll(_paragraphs(line));
    }
  }
  flushBullets();
  return blocks;
}

CourseDescriptionRow? _asShortLabelValue(String item) {
  final separator = item.indexOf(':');
  if (separator < 1 || separator > 40 || separator == item.length - 1) {
    return null;
  }
  final label = item.substring(0, separator).trim();
  final value = item.substring(separator + 1).trim();
  if (label.split(RegExp(r'\s+')).length > 6 || value.isEmpty) return null;
  return CourseDescriptionRow(label, value);
}

Iterable<CourseDescriptionBlock> _paragraphs(String text) sync* {
  final sentences = text.split(RegExp(r'(?<=[.!?])\s+(?=[A-ZÀ-Ỹ])'));
  var paragraph = '';
  for (final sentence in sentences) {
    if (paragraph.isNotEmpty && paragraph.length + sentence.length > 320) {
      yield CourseDescriptionBlock.paragraph(paragraph);
      paragraph = sentence;
    } else {
      paragraph = paragraph.isEmpty ? sentence : '$paragraph $sentence';
    }
  }
  if (paragraph.isNotEmpty) yield CourseDescriptionBlock.paragraph(paragraph);
}
