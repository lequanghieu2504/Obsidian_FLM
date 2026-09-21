import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_flm_desktop/features/subjects/domain/subject_display.dart';
import 'package:obsidian_flm_desktop/features/subjects/presentation/subject_list_screen.dart';
import 'package:obsidian_flm_desktop/models/subject.dart';

void main() {
  final subjects = [
    Subject(
      semester: 0,
      code: 'OTP101',
      name: 'Orientation_Định hướng',
      credits: '0',
      preRequisite: 'None.',
    ),
    Subject(
      semester: 4,
      code: 'DBI202',
      name: 'Database Systems_Các hệ cơ sở dữ liệu',
      credits: '3',
      preRequisite: 'PRO192',
    ),
    Subject(
      semester: 4,
      code: 'PRJ301',
      name: 'Java Web Application Development_Phát triển ứng dụng Java web',
      credits: '3',
      preRequisite: 'DBI202, PRO192',
    ),
    Subject(
      semester: 8,
      code: 'PRM393',
      name: 'Mobile Programming_Lập trình di động',
      credits: '3',
      preRequisite: 'PRO192',
    ),
  ];

  Future<void> pumpBrowser(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: SubjectListScreen(
          curriculumCode: 'BIT_SE_K19B',
          subjects: subjects,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('search matches code, English, and Vietnamese names', (
    tester,
  ) async {
    await pumpBrowser(tester);
    final search = find.byKey(const Key('subject-search'));

    await tester.enterText(search, 'PRM');
    await tester.pump();
    expect(find.text('PRM393'), findsOneWidget);
    expect(find.text('PRJ301'), findsNothing);

    await tester.enterText(search, 'database');
    await tester.pump();
    expect(find.text('DBI202'), findsOneWidget);

    await tester.enterText(search, 'lập trình di động');
    await tester.pump();
    expect(find.text('PRM393'), findsOneWidget);
  });

  testWidgets('semester navigation filters immediately and supports Prep', (
    tester,
  ) async {
    await pumpBrowser(tester);
    await tester.tap(find.text('Sem 4'));
    await tester.pump();
    expect(find.text('PRJ301'), findsOneWidget);
    expect(find.text('DBI202'), findsOneWidget);
    expect(find.text('PRM393'), findsNothing);

    await tester.tap(find.text('Prep'));
    await tester.pump();
    expect(find.text('OTP101'), findsOneWidget);
    expect(find.text('PRJ301'), findsNothing);
  });

  testWidgets('grid and list controls render without losing results', (
    tester,
  ) async {
    await pumpBrowser(tester);
    expect(find.byType(GridView), findsOneWidget);
    await tester.tap(find.text('List'));
    await tester.pump();
    expect(find.byType(ListView), findsWidgets);
    expect(find.text('PRM393'), findsOneWidget);
  });

  testWidgets('credits and prerequisite filters use real normalized values', (
    tester,
  ) async {
    await pumpBrowser(tester);
    await tester.tap(find.byKey(const Key('credits-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0').last);
    await tester.pumpAndSettle();
    expect(find.text('OTP101'), findsOneWidget);
    expect(find.text('PRJ301'), findsNothing);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('prerequisite-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No prerequisite').last);
    await tester.pumpAndSettle();
    expect(find.text('OTP101'), findsOneWidget);
    expect(find.text('PRJ301'), findsNothing);
  });

  test('prerequisite normalization covers real empty variants', () {
    for (final value in ['', 'None', 'None.', 'Không']) {
      final subject = Subject(
        semester: 1,
        code: value.isEmpty ? 'EMPTY' : value,
        name: 'Test',
        credits: '3',
        preRequisite: value,
      );
      expect(hasPrerequisite(subject), isFalse);
    }
    expect(hasPrerequisite(subjects[1]), isTrue);
  });
}
