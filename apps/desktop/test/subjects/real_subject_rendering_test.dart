import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_flm_desktop/features/subjects/application/subject_detail_controller.dart';
import 'package:obsidian_flm_desktop/features/subjects/data/asset_subject_repository.dart';
import 'package:obsidian_flm_desktop/features/subjects/presentation/subject_detail_screen.dart';
import 'package:obsidian_flm_desktop/models/subject.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Subject Detail renders every real PRJ301 field and switches to PRM393',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final subjects = await AssetSubjectRepository().loadSubjects(
        'BIT_SE_K19B',
      );
      final prj301 = subjects.singleWhere(
        (subject) => subject.code == 'PRJ301',
      );
      final prm393 = subjects.singleWhere(
        (subject) => subject.code == 'PRM393',
      );

      Widget detail(Subject subject) => MaterialApp(
        home: SubjectDetailScreen(
          key: const ValueKey('real-subject-detail'),
          curriculumCode: 'BIT_SE_K19B',
          subject: subject,
          controllerFactory: (workspace) async => SubjectDetailController(
            workspace: workspace,
            repository: MemoryRepository(),
            llm: TestLlm(),
            keys: MemoryKeys(),
          ),
        ),
      );

      await tester.pumpWidget(detail(prj301));
      await tester.pumpAndSettle();
      expect(find.text('PRJ301'), findsWidgets);
      expect(find.text('Java Web Application Development'), findsOneWidget);
      expect(find.text('Phát triển ứng dụng Java web'), findsOneWidget);
      expect(find.text('Code'), findsNothing);
      expect(find.text('Semester'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Credits'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Prerequisite'), findsOneWidget);
      expect(find.text('DBI202, PRO192'), findsOneWidget);

      await tester.pumpWidget(detail(prm393));
      await tester.pumpAndSettle();
      expect(find.text('PRM393'), findsWidgets);
      expect(find.text('Mobile Programming'), findsOneWidget);
      expect(find.text('Lập trình di động'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('PRO192'), findsOneWidget);
      expect(find.text('DBI202, PRO192'), findsNothing);
    },
  );

  testWidgets('empty and multiline prerequisites render without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pump(Subject subject) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SubjectDetailScreen(
            curriculumCode: 'BIT_SE_K19B',
            subject: subject,
            controllerFactory: (workspace) async => SubjectDetailController(
              workspace: workspace,
              repository: MemoryRepository(),
              llm: TestLlm(),
              keys: MemoryKeys(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(
      Subject(
        semester: 0,
        code: 'EMPTY_PRE',
        name: 'Single language name',
        credits: '0',
        preRequisite: '',
      ),
    );
    expect(find.text('No prerequisite information'), findsOneWidget);
    expect(tester.takeException(), isNull);

    const prerequisite =
        'Students must complete the foundation requirements.\n'
        'A second line remains fully readable and is not truncated.';
    await pump(
      Subject(
        semester: 6,
        code: 'LONG_PRE',
        name: 'Long prerequisite subject_Môn có điều kiện dài',
        credits: '10',
        preRequisite: prerequisite,
      ),
    );
    expect(find.text(prerequisite), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
