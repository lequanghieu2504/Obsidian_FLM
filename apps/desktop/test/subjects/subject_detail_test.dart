import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_flm_desktop/features/assistant/infrastructure/gemini_llm_client.dart';
import 'package:obsidian_flm_desktop/features/knowledge_graph/domain/subject_record.dart';
import 'package:obsidian_flm_desktop/features/subjects/application/subject_detail_controller.dart';
import 'package:obsidian_flm_desktop/features/subjects/presentation/subject_detail_screen.dart';
import 'package:obsidian_flm_desktop/features/subjects/presentation/subject_resources_panel.dart';
import 'package:obsidian_flm_desktop/models/subject.dart';
import 'package:obsidian_flm_desktop/utils/user_settings.dart';

import 'test_support.dart';

void main() {
  testWidgets(
    'selected metadata and curriculum render; resize preserves draft; failures retry',
    (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final llm = TestLlm()..fail = true;
      final selected = workspace();
      await tester.pumpWidget(
        MaterialApp(
          home: SubjectDetailScreen(
            curriculumCode: selected.curriculumCode,
            subject: selected.subject,
            controllerFactory: (actual) async => SubjectDetailController(
              workspace: actual,
              repository: MemoryRepository(),
              llm: llm,
              keys: MemoryKeys(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Subject Detail'), findsNothing);
      expect(find.text('BIT_SE_K19B'), findsOneWidget);
      expect(find.text('Java Web Application Development'), findsOneWidget);
      expect(find.text('Semester'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Credits'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Prerequisite'), findsOneWidget);
      expect(find.text('DBI202, PRO192'), findsOneWidget);
      await tester.tap(find.byTooltip('Expand chat'));
      await tester.pumpAndSettle();
      expect(find.text('Lộ trình từ bảng điểm'), findsOneWidget);
      expect(find.byTooltip('Cấu hình API Key & model'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Explain a servlet');
      tester.view.physicalSize = const Size(600, 850);
      await tester.pumpAndSettle();
      expect(find.text('Explain a servlet'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Gửi'));
      await tester.pumpAndSettle();
      expect(find.text('Gemini is unavailable. Please retry.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      llm.fail = false;
      await tester.tap(find.text('Thử lại câu trả lời'));
      await tester.pumpAndSettle();
      expect(find.text('Test response'), findsOneWidget);
      expect(llm.context, contains('Code: PRJ301'));
      await tester.tap(find.byTooltip('Xóa lịch sử chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Test response'), findsOneWidget);
      await tester.tap(find.byTooltip('Xóa lịch sử chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa lịch sử'));
      await tester.pumpAndSettle();
      expect(find.text('Test response'), findsNothing);
    },
  );

  testWidgets('long metadata and scaled text fit a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: SubjectDetailScreen(
          curriculumCode: 'BIT_SE_K19B',
          subject: Subject(
            semester: 4,
            code: 'PRJ301',
            name: 'A very long subject name ' * 8,
            credits: '3',
            preRequisite: 'A long prerequisite description ' * 12,
          ),
          controllerFactory: (actual) async => SubjectDetailController(
            workspace: actual,
            repository: MemoryRepository(),
            llm: TestLlm(),
            keys: MemoryKeys(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Expand chat'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('other syllabus fields use responsive grouped grids', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final selected = workspace();
    final controller =
        SubjectDetailController(
            workspace: selected,
            repository: MemoryRepository(),
            llm: TestLlm(),
            keys: MemoryKeys(),
          )
          ..syllabus = const SubjectRecord(
            syllabusId: 'test',
            subjectCode: 'PRJ301',
            syllabusName: 'Test syllabus',
            courseNameEnglish: 'Test course',
            degreeLevel: 'Bachelor',
            credits: '3',
            learningTeachingMethod: 'Offline',
            prerequisiteRaw: '',
            description: '',
            learningOutcomes: [],
            metadata: {
              'Time Allocation': '45 contact hours and 105 self-study hours',
              'StudentTasks':
                  '- Attend at least 80% of sessions - Submit all assignments on time',
              'Tools': 'Laptop, IDE and Internet access',
              'Scoring Scale': '10',
              'MinAvgMarkToPass': '5',
              'DecisionNo MM/dd/yyyy': '358/QĐ-ĐHFPT dated 04/03/2024',
              'ApprovedDate': '4/3/2024',
              'IsApproved': 'True',
              'Is Scored': 'False',
              'IsActive': 'True',
            },
          );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OtherSyllabusFieldsPanel(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Course Requirements'), findsOneWidget);
    expect(find.text('Course Resources & Evaluation'), findsOneWidget);
    expect(find.text('Administrative Information'), findsOneWidget);
    expect(find.text('StudentTasks'), findsOneWidget);
    expect(find.text('IsApproved'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final size in [const Size(760, 900), const Size(390, 820)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(find.text('Course Requirements'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'missing key disables send; key set in Trợ lý học vụ enables it',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // The subject chat uses the app-wide key (same as Trợ lý học vụ).
      FlutterSecureStorage.setMockInitialValues({});
      await tester.runAsync(() => UserSettings.ensureLoaded());
      await tester.runAsync(() => UserSettings.clearApiKey());
      const keys = SecureGeminiKeyStore();
      await tester.pumpWidget(
        MaterialApp(
          home: SubjectDetailScreen(
            curriculumCode: workspace().curriculumCode,
            subject: workspace().subject,
            controllerFactory: (actual) async => SubjectDetailController(
              workspace: actual,
              repository: MemoryRepository(),
              llm: TestLlm(),
              keys: keys,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Expand chat'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Question');
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Gửi'))
            .onPressed,
        isNull,
      );
      // The subject chat has no key UI; the key is set in Trợ lý học vụ
      // (UserSettings) and the panel picks it up.
      await tester.runAsync(
        () => UserSettings.saveGeminiSettings(
          'new-test-key',
          UserSettings.geminiModel,
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(UserSettings.geminiApiKey, 'new-test-key');
      expect(find.text('new-test-key'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Gửi'))
            .onPressed,
        isNotNull,
      );
    },
  );
}
