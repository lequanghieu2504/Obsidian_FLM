import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_flm_desktop/features/knowledge_graph/domain/subject_record.dart';
import 'package:obsidian_flm_desktop/features/subjects/presentation/subject_resources_panel.dart';

void main() {
  testWidgets(
    'reference table keeps readable single-line headers and scrolls',
    (tester) async {
      tester.view.physicalSize = const Size(540, 620);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SyllabusTablePanel(
              section: SyllabusSection(
                heading: 'Reference materials',
                headers: [
                  'No',
                  'materialdescription',
                  'author',
                  'publisher',
                  'publisheddate',
                  'ismainmaterial',
                  'ishardcopy',
                  'isonline',
                ],
                rows: [
                  [
                    '1',
                    'A complete introduction to computer networking',
                    'Cisco',
                    'Cisco Press',
                    '2024',
                    'Yes',
                    'No',
                    'Yes',
                  ],
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in [
        'Material Description',
        'Published Date',
        'Main Material',
        'Hardcopy',
        'Online',
      ]) {
        final text = tester.widget<Text>(find.text(label));
        expect(text.maxLines, 1);
        expect(text.softWrap, isFalse);
      }
      expect(tester.getSize(find.byType(Table)).width, greaterThan(540));

      final horizontal = find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      );
      final before = tester.getTopLeft(find.text('Online')).dx;
      await tester.drag(horizontal, const Offset(-420, 0));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Online')).dx, lessThan(before));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'session plan prioritizes prose columns at wide and narrow sizes',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const section = SyllabusSection(
        heading: 'Session plan',
        headers: [
          'session',
          'topic',
          'learningteachingtype',
          'CLO',
          'ITU',
          'studentmaterials',
          'sdownload',
          'studentstasks',
        ],
        rows: [
          [
            '1',
            'Course overview and networking fundamentals',
            'Offline',
            'CLO1',
            'T',
            'Module 1: Networking and supporting documents',
            'Yes',
            'Complete exercises and prepare the assigned laboratory work',
          ],
        ],
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SyllabusTablePanel(section: section)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Teaching Method'), findsOneWidget);
      expect(find.text('Student Materials'), findsOneWidget);
      expect(find.text('Student Tasks'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(390, 700);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(Table)).width, greaterThan(390));
      expect(tester.takeException(), isNull);
    },
  );
}
