import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_flm_desktop/features/subjects/data/asset_subject_repository.dart';
import 'package:obsidian_flm_desktop/features/subjects/presentation/subject_catalog_screen.dart';
import 'package:obsidian_flm_desktop/models/subject.dart';

void main() {
  testWidgets('catalog exposes an empty real-data state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SubjectCatalogScreen(
          curriculumCode: 'EMPTY',
          repository: _Repository(subjects: const []),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No subjects were provided for this curriculum.'),
      findsOneWidget,
    );
  });

  testWidgets('catalog exposes load error and retry', (tester) async {
    final repository = _Repository(error: true);
    await tester.pumpWidget(
      MaterialApp(
        home: SubjectCatalogScreen(
          curriculumCode: 'MISSING',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load subject data.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    repository.error = false;
    repository.subjects = [
      Subject(
        semester: 0,
        code: 'FOUND',
        name: 'Recovered subject',
        credits: '2',
        preRequisite: '',
      ),
    ];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('FOUND'), findsOneWidget);
    expect(find.text('Prep'), findsWidgets);
  });
}

class _Repository implements SubjectCatalogRepository {
  _Repository({this.subjects = const [], this.error = false});

  List<Subject> subjects;
  bool error;

  @override
  Future<List<Subject>> loadSubjects(String curriculumCode) async {
    if (error) throw StateError('load failed');
    return subjects;
  }
}
