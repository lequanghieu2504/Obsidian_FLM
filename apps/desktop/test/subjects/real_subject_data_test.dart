import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_flm_desktop/features/subjects/data/asset_subject_repository.dart';
import 'package:obsidian_flm_desktop/features/subjects/domain/subject_display.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('real BIT_SE_K19B asset', () {
    late AssetSubjectRepository repository;

    setUp(() => repository = AssetSubjectRepository());

    test('loads exact PRJ301 and PRM393 source values', () async {
      final subjects = await repository.loadSubjects('BIT_SE_K19B');

      final prj301 = subjects.singleWhere(
        (subject) => subject.code == 'PRJ301',
      );
      expect(prj301.semester, 4);
      expect(prj301.code, 'PRJ301');
      expect(prj301.name, contains('Java Web Application Development'));
      expect(prj301.name, contains('Phát triển ứng dụng Java web'));
      expect(prj301.credits, '3');
      expect(prj301.preRequisite, 'DBI202, PRO192');

      final prm393 = subjects.singleWhere(
        (subject) => subject.code == 'PRM393',
      );
      expect(prm393.semester, 8);
      expect(prm393.credits, '3');
      expect(prm393.preRequisite, 'PRO192');
    });

    test(
      'groups from semester values, preserves order, and retains semester 0',
      () async {
        final subjects = await repository.loadSubjects('BIT_SE_K19B');
        final groups = groupSubjectsBySemester(subjects);

        expect(groups.keys, orderedEquals([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]));
        expect(groups[0], isNotEmpty);
        expect(groups.values.expand((group) => group), orderedEquals(subjects));
        expect(groups[4]!.map((subject) => subject.code), contains('PRJ301'));
        expect(groups[8]!.map((subject) => subject.code), contains('PRM393'));
      },
    );

    test(
      'bilingual presentation does not mutate the raw source name',
      () async {
        final subject = (await repository.loadSubjects(
          'BIT_SE_K19B',
        )).singleWhere((subject) => subject.code == 'PRJ301');
        final raw = subject.name;
        final display = subjectDisplayName(subject);

        expect(display.primary, 'Java Web Application Development');
        expect(display.secondary, 'Phát triển ứng dụng Java web');
        expect(subject.name, raw);
      },
    );
  });

  test(
    'loads the committed BIT_GD_K19B asset without filtering entries',
    () async {
      final subjects = await AssetSubjectRepository().loadSubjects(
        'BIT_GD_K19B',
      );
      expect(subjects, isNotEmpty);
      expect(subjects.any((subject) => subject.semester == 0), isTrue);
      expect(subjects.any((subject) => subject.code.contains('*')), isTrue);
    },
  );

  test(
    'invalid JSON, non-list JSON, and malformed records fail explicitly',
    () async {
      for (final source in [
        'not-json',
        '{}',
        '[{"semester":4,"code":"BROKEN"}]',
      ]) {
        final repository = AssetSubjectRepository(
          bundle: _StringAssetBundle(source),
        );
        await expectLater(
          repository.loadSubjects('BIT_SE_K19B'),
          throwsA(isA<Object>()),
        );
      }
    },
  );
}

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.source);

  final String source;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(source));
    return ByteData.sublistView(bytes);
  }
}
