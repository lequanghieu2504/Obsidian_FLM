import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_flm_desktop/features/subjects/domain/course_description_formatter.dart';

void main() {
  test('splits flattened prose and bullet streams', () {
    final blocks = formatCourseDescription(
      'Contents include: - Overview of networks - Setting up devices '
      '- End-user security and 3-5 practical exercises',
    );

    expect(blocks.map((block) => block.type), [
      CourseDescriptionBlockType.paragraph,
      CourseDescriptionBlockType.bullets,
    ]);
    expect(blocks.last.items, hasLength(3));
    expect(blocks.last.items.last, contains('End-user'));
  });

  test('recognizes bullets joined directly to punctuation', () {
    final blocks = formatCourseDescription(
      'Topics include:- Overview of networks.- Setting up devices.- Security',
    );

    expect(blocks.last.type, CourseDescriptionBlockType.bullets);
    expect(blocks.last.items, [
      'Overview of networks.',
      'Setting up devices.',
      'Security',
    ]);
  });

  test('recognizes named and numbered section headings', () {
    final blocks = formatCourseDescription(
      'Target: Build core competence. Implementation: Practice in labs. '
      '1) Knowledge: Explain networking concepts. '
      '2) Skills: Configure network devices.',
    );

    expect(
      blocks
          .where((block) => block.type == CourseDescriptionBlockType.heading)
          .map((block) => block.text),
      ['Target', 'Implementation', '1) Knowledge', '2) Skills'],
    );
  });

  test('uses a table for a consistent label and value list', () {
    final blocks = formatCourseDescription(
      'Course facts: - Duration: 45 hours - Delivery: Offline '
      '- Assessment: Project based',
    );

    expect(blocks.last.type, CourseDescriptionBlockType.table);
    expect(blocks.last.rows.map((row) => row.label), [
      'Duration',
      'Delivery',
      'Assessment',
    ]);
  });

  test('repairs missing sentence spacing and groups long prose', () {
    final blocks = formatCourseDescription(
      'Students learn networking.Students configure devices. '
      '${List.filled(45, 'Practice improves technical confidence').join(' ')}.',
    );

    expect(
      blocks.first.text,
      startsWith('Students learn networking. Students'),
    );
    expect(
      blocks.where(
        (block) => block.type == CourseDescriptionBlockType.paragraph,
      ),
      hasLength(greaterThan(1)),
    );
  });
}
