import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_flm_desktop/features/subjects/application/subject_detail_controller.dart';
import 'package:obsidian_flm_desktop/features/subjects/presentation/subject_detail_screen.dart';
import 'package:obsidian_flm_desktop/features/subjects/presentation/subject_list_screen.dart';

import 'test_support.dart';

void main() {
  testWidgets(
    'upstream subjects stay grouped; click opens exact subject and curriculum; back preserves list',
    (tester) async {
      final java = workspace().subject;
      final database = workspace('DBI202').subject;
      await tester.pumpWidget(
        MaterialApp(
          home: SubjectListScreen(
            curriculumCode: 'BIT_SE_K19B',
            subjects: [java, database],
            controllerFactory: (actual) async => SubjectDetailController(
              workspace: actual,
              repository: MemoryRepository(),
              llm: TestLlm(),
              keys: MemoryKeys(),
            ),
          ),
        ),
      );
      expect(find.text('Semester 4'), findsWidgets);
      expect(find.text('PRJ301'), findsOneWidget);
      expect(find.text('Java Web Application Development'), findsOneWidget);
      await tester.tap(find.text('DBI202'));
      await tester.pumpAndSettle();
      final detail = tester.widget<SubjectDetailScreen>(
        find.byType(SubjectDetailScreen),
      );
      expect(detail.curriculumCode, 'BIT_SE_K19B');
      expect(identical(detail.subject, database), isTrue);
      expect(find.text('Database Systems'), findsOneWidget);
      expect(find.text('Java Web Application Development'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('PRJ301'), findsOneWidget);
      expect(find.text('DBI202'), findsOneWidget);
      expect(find.text('All'), findsWidgets);
    },
  );

  testWidgets(
    'empty upstream list shows explicit state without fabricated subjects',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SubjectListScreen(curriculumCode: 'EMPTY', subjects: []),
        ),
      );
      expect(
        find.text('No subjects were provided for this curriculum.'),
        findsOneWidget,
      );
      expect(find.byType(ListTile), findsNothing);
    },
  );
}
