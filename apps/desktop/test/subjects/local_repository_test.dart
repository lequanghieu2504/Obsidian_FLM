import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:obsidian_flm_desktop/features/subjects/data/local_subject_workspace_repository.dart';
import 'package:obsidian_flm_desktop/features/subjects/domain/subject_workspace.dart';

import 'test_support.dart';

void main() {
  late Directory temporary;
  late Directory root;
  late LocalSubjectWorkspaceRepository repository;
  late File source;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp(
      'subject_repository_test_',
    );
    root = Directory(p.join(temporary.path, 'user_data'));
    repository = LocalSubjectWorkspaceRepository(root);
    source = await File(
      p.join(temporary.path, 'my notes.unrecognized'),
    ).writeAsString('original content');
  });
  tearDown(() async {
    await temporary.delete(recursive: true);
  });

  test(
    'arbitrary files are copied and restored independently of original location',
    () async {
      final resource = await repository.importResource(
        workspace(),
        source.path,
      );
      final path = await repository.resourcePath(workspace(), resource);
      expect(p.isWithin(root.path, path), isTrue);
      expect(resource.originalFileName, 'my notes.unrecognized');
      expect(resource.extension, '.unrecognized');
      expect(resource.size, 16);
      await source.rename(p.join(temporary.path, 'moved'));
      final reopened = LocalSubjectWorkspaceRepository(root);
      final rows = await reopened.loadResources(workspace());
      expect(rows.single.toJson(), resource.toJson());
      expect(
        await File(
          await reopened.resourcePath(workspace(), rows.single),
        ).readAsString(),
        'original content',
      );
    },
  );

  test(
    'resources are isolated across subjects AND curriculum versions',
    () async {
      await repository.importResource(workspace(), source.path);
      expect(await repository.loadResources(workspace('DBI202')), isEmpty);
      expect(
        await repository.loadResources(workspace('PRJ301', 'BIT_SE_K19A')),
        isEmpty,
      );
      expect(
        await repository.loadResources(workspace('PRJ301', 'bit_se_k19b')),
        isEmpty,
      );
    },
  );

  test(
    'duplicate names never overwrite; deletion removes only the selected copy',
    () async {
      final first = await repository.importResource(workspace(), source.path);
      await source.writeAsString('second content');
      final second = await repository.importResource(workspace(), source.path);
      final firstPath = await repository.resourcePath(workspace(), first);
      final secondPath = await repository.resourcePath(workspace(), second);
      expect(first.id, isNot(second.id));
      expect(await File(firstPath).readAsString(), 'original content');
      expect(await File(secondPath).readAsString(), 'second content');
      await repository.deleteResource(workspace(), first);
      expect(await File(firstPath).exists(), isFalse);
      expect(
        (await repository.loadResources(workspace())).single.id,
        second.id,
      );
      expect(await source.readAsString(), 'second content');
    },
  );

  test('chat persists role content timestamp and stays isolated', () async {
    final message = ChatMessage(
      role: ChatRole.user,
      content: 'Question',
      timestamp: DateTime.utc(2026, 9, 20),
    );
    await repository.saveChat(workspace(), [message]);
    final reopened = LocalSubjectWorkspaceRepository(root);
    expect(
      (await reopened.loadChat(workspace())).single.toJson(),
      message.toJson(),
    );
    expect(await reopened.loadChat(workspace('DBI202')), isEmpty);
    expect(
      await reopened.loadChat(workspace('PRJ301', 'BIT_SE_K19A')),
      isEmpty,
    );
    await reopened.saveChat(workspace(), []);
    expect(await repository.loadChat(workspace()), isEmpty);
  });

  test(
    'concurrent imports from separate repositories do not lose metadata',
    () async {
      await Future.wait(
        List.generate(
          5,
          (_) => LocalSubjectWorkspaceRepository(
            root,
          ).importResource(workspace(), source.path),
        ),
      );
      expect(await repository.loadResources(workspace()), hasLength(5));
    },
  );

  test(
    'malformed metadata is preserved, not replaced with an empty list',
    () async {
      final resource = await repository.importResource(
        workspace(),
        source.path,
      );
      final path = await repository.resourcePath(workspace(), resource);
      final metadata = File(
        p.join(p.dirname(p.dirname(path)), 'resources.json'),
      );
      await metadata.writeAsString('broken JSON');
      await expectLater(
        repository.importResource(workspace(), source.path),
        throwsFormatException,
      );
      expect(await metadata.readAsString(), 'broken JSON');
      expect(await File(path).exists(), isTrue);
    },
  );

  test('malicious metadata cannot delete an external path', () async {
    final resource = await repository.importResource(workspace(), source.path);
    final path = await repository.resourcePath(workspace(), resource);
    final metadata = File(p.join(p.dirname(p.dirname(path)), 'resources.json'));
    final malicious = resource.toJson()..['storedFileName'] = source.path;
    await metadata.writeAsString(jsonEncode([malicious]));
    await expectLater(
      repository.deleteResource(workspace(), resource),
      throwsFormatException,
    );
    expect(await source.exists(), isTrue);
  });

  test('cross-workspace deletion is rejected', () async {
    final resource = await repository.importResource(workspace(), source.path);
    await expectLater(
      repository.deleteResource(workspace('DBI202'), resource),
      throwsFormatException,
    );
    expect(await repository.loadResources(workspace()), hasLength(1));
  });

  test(
    'interrupted deletion is restored if metadata still owns the copy',
    () async {
      final resource = await repository.importResource(
        workspace(),
        source.path,
      );
      final path = await repository.resourcePath(workspace(), resource);
      await File(path).rename('$path.deleting');
      expect(await repository.loadResources(workspace()), hasLength(1));
      expect(await File(path).exists(), isTrue);
      expect(await File('$path.deleting').exists(), isFalse);
    },
  );

  test('failed import preserves existing resources', () async {
    await repository.importResource(workspace(), source.path);
    await expectLater(
      repository.importResource(workspace(), p.join(temporary.path, 'missing')),
      throwsA(isA<FileSystemException>()),
    );
    expect(await repository.loadResources(workspace()), hasLength(1));
  });
}
