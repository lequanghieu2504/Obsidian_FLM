import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_flm_desktop/features/assistant/infrastructure/local_chat_attachment_processor.dart';
import 'package:obsidian_flm_desktop/features/subjects/domain/subject_workspace.dart';

void main() {
  late Directory root;
  setUp(
    () async => root = await Directory.systemTemp.createTemp('attachments'),
  );
  tearDown(() async => root.delete(recursive: true));

  UserResource resource(String extension) => UserResource(
    id: 'resource-1',
    curriculumCode: 'BIT_SE_K19B',
    subjectCode: 'PRJ301',
    originalFileName: 'study$extension',
    storedFileName: 'resource-1$extension',
    extension: extension,
    size: 4,
    importedAt: DateTime.utc(2026),
  );

  test(
    'text attachments are extracted without changing the local file',
    () async {
      final file = File('${root.path}/study.txt');
      await file.writeAsString('local notes');
      final attachment = await const LocalChatAttachmentProcessor().process(
        resource('.txt'),
        file.path,
      );
      expect(attachment.text, 'local notes');
      expect(attachment.resourceId, 'resource-1');
      expect(await file.readAsString(), 'local notes');
    },
  );

  test(
    'unsupported local files fail explicitly instead of being ignored',
    () async {
      final file = File('${root.path}/study.xlsx');
      await file.writeAsBytes([1, 2, 3, 4]);
      expect(
        () => const LocalChatAttachmentProcessor().process(
          resource('.xlsx'),
          file.path,
        ),
        throwsA(
          isA<WorkspaceFailure>().having(
            (failure) => failure.message,
            'message',
            contains('not supported'),
          ),
        ),
      );
    },
  );

  test('chat JSON persists resource IDs but never binary file data', () {
    final message = ChatMessage(
      id: 'message-1',
      role: ChatRole.user,
      content: 'Explain this diagram.',
      timestamp: DateTime.utc(2026),
      resourceIds: const ['resource-1'],
    );
    final json = message.toJson();
    expect(json['resourceIds'], ['resource-1']);
    expect(json.containsKey('bytes'), isFalse);
    expect(ChatMessage.fromJson(json).resourceIds, ['resource-1']);
  });
}
