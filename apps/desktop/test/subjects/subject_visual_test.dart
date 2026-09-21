import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_flm_desktop/features/subjects/application/subject_detail_controller.dart';
import 'package:obsidian_flm_desktop/features/subjects/domain/subject_workspace.dart';
import 'package:obsidian_flm_desktop/features/subjects/presentation/subject_detail_screen.dart';

import 'test_support.dart';

void main() {
  testWidgets(
    'resource list renders with long names and accessible delete controls',
    (tester) async {
      final capture = Platform.environment['SUBJECT_CAPTURE'] == '1';
      if (capture) {
        await tester.runAsync(() async {
          final font = FontLoader('ReviewFont')
            ..addFont(
              File(
                Platform.environment['SUBJECT_REVIEW_FONT']!,
              ).readAsBytes().then(ByteData.sublistView),
            );
          await font.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(
              File(
                Platform.environment['SUBJECT_ICON_FONT']!,
              ).readAsBytes().then(ByteData.sublistView),
            );
          await icons.load();
        });
      }
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      final repository = MemoryRepository();
      for (final name in [
        'lecture.pdf',
        'grades.xlsx',
        'diagram.png',
        'A long filename for an arbitrary user selected resource.unknown',
      ]) {
        repository.resources.add(
          UserResource(
            id: name,
            curriculumCode: 'BIT_SE_K19B',
            subjectCode: 'PRJ301',
            originalFileName: name,
            storedFileName: name,
            extension: '.${name.split('.').last}',
            size: 42000,
            importedAt: DateTime.utc(2026, 9, 20),
          ),
        );
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: capture ? ThemeData(fontFamily: 'ReviewFont') : null,
            home: SubjectDetailScreen(
              curriculumCode: workspace().curriculumCode,
              subject: workspace().subject,
              controllerFactory: (actual) async => SubjectDetailController(
                workspace: actual,
                repository: repository,
                llm: TestLlm(),
                keys: MemoryKeys()..value = null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('lecture.pdf'), findsOneWidget);
      expect(find.byTooltip('Delete lecture.pdf'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Delete lecture.pdf'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('lecture.pdf'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete lecture.pdf'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('lecture.pdf'), findsNothing);
      expect(find.text('Your resources (3)'), findsOneWidget);
      if (capture) {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/subject-review').create(recursive: true);
          await File(
            'build/subject-review/desktop.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
  );
}
