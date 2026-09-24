import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:obsidian_flm_desktop/features/assistant/application/llm_client.dart';
import 'package:obsidian_flm_desktop/features/assistant/infrastructure/gemini_llm_client.dart';
import 'package:obsidian_flm_desktop/features/subjects/application/subject_detail_controller.dart';
import 'package:obsidian_flm_desktop/features/subjects/domain/subject_workspace.dart';
import 'package:obsidian_flm_desktop/features/subjects/domain/study_roadmap_prompt.dart';

import 'test_support.dart';

void main() {
  test(
    'study roadmap request binds transcript evidence to selected subject',
    () {
      final request = buildStudyRoadmapRequest(
        subjectCode: 'NWC204',
        fileNames: const ['transcript.xlsx', 'grades.png'],
      );
      expect(request, contains('NWC204'));
      expect(request, contains('transcript.xlsx'));
      expect(request, contains('grades.png'));
      expect(request, contains('không tự suy đoán'));
      expect(request, contains('lộ trình theo tuần'));
    },
  );

  test('prompt includes only selected subject academic context', () {
    const builder = SubjectPromptBuilder();
    final java = builder.build(workspace());
    expect(java, contains('Current curriculum: BIT_SE_K19B'));
    expect(java, contains('Code: PRJ301'));
    expect(java, contains('Name: Java Web Application Development'));
    expect(java, contains('Semester: 4'));
    expect(java, contains('Credits: 3'));
    expect(java, contains('Prerequisite: DBI202, PRO192'));
    expect(java, contains('never invent grades'));
    final database = builder.build(workspace('DBI202'));
    expect(database, isNot(contains('PRJ301')));
    expect(database, isNot(contains('Java Web')));
  });

  test(
    'Gemini request contains text history with no file/retrieval payload or URL key',
    () async {
      final keys = MemoryKeys();
      final client = GeminiLlmClient(
        keys: keys,
        client: MockClient((request) async {
          expect(request.url.host, 'generativelanguage.googleapis.com');
          expect(request.url.query, isEmpty);
          expect(request.headers['x-goog-api-key'], 'test-key');
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(
            payload.keys,
            unorderedEquals(['systemInstruction', 'contents']),
          );
          expect(
            payload['systemInstruction']['parts'][0]['text'],
            'Selected subject',
          );
          expect(payload['contents'][0]['role'], 'user');
          expect(payload['contents'][1]['role'], 'model');
          expect(payload['contents'][2]['parts'][0], {'text': 'Question'});
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Answer'},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(client.close);
      final result = await client.send(
        context: 'Selected subject',
        messages: [
          ChatMessage(
            role: ChatRole.user,
            content: 'First',
            timestamp: DateTime.now(),
          ),
          ChatMessage(
            role: ChatRole.assistant,
            content: 'Earlier',
            timestamp: DateTime.now(),
          ),
          ChatMessage(
            role: ChatRole.user,
            content: 'Question',
            timestamp: DateTime.now(),
          ),
        ],
      );
      expect(result, 'Answer');
    },
  );

  for (final status in [400, 401, 403, 404, 429, 500]) {
    test(
      'HTTP $status surfaces safe actionable failure without server body or secret',
      () async {
        final client = GeminiLlmClient(
          keys: MemoryKeys(),
          client: MockClient(
            (_) async => http.Response('test-key private server data', status),
          ),
        );
        addTearDown(client.close);
        await expectLater(
          client.send(context: '', messages: []),
          throwsA(
            isA<WorkspaceFailure>()
                .having(
                  (e) => e.message,
                  'message',
                  isNot(contains('test-key')),
                )
                .having(
                  (e) => e.message,
                  'message',
                  isNot(contains('private server data')),
                ),
          ),
        );
      },
    );
  }

  test('blocked, malformed and empty responses fail cleanly', () async {
    for (final body in [
      '{}',
      'not json',
      '{"candidates":[{"content":{"parts":[]}}]}',
    ]) {
      final client = GeminiLlmClient(
        keys: MemoryKeys(),
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        client.send(context: '', messages: []),
        throwsA(isA<WorkspaceFailure>()),
      );
      client.close();
    }
  });

  test('missing key never calls Gemini', () async {
    final client = GeminiLlmClient(
      keys: MemoryKeys()..value = null,
      client: MockClient((_) async => throw StateError('must not request')),
    );
    addTearDown(client.close);
    await expectLater(
      client.send(context: '', messages: []),
      throwsA(
        isA<WorkspaceFailure>().having(
          (e) => e.message,
          'message',
          contains('Add your Gemini API key'),
        ),
      ),
    );
  });

  test('timeout is retryable and does not expose raw exceptions', () async {
    final client = GeminiLlmClient(
      keys: MemoryKeys(),
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.close);
    await expectLater(
      client.send(context: '', messages: []),
      throwsA(
        isA<WorkspaceFailure>().having(
          (e) => e.message,
          'message',
          contains('timed out'),
        ),
      ),
    );
  });

  group('controller', () {
    late MemoryRepository repository;
    late TestLlm llm;
    late SubjectDetailController controller;
    setUp(() async {
      repository = MemoryRepository();
      llm = TestLlm();
      controller = SubjectDetailController(
        workspace: workspace(),
        repository: repository,
        llm: llm,
        keys: MemoryKeys(),
      );
      await controller.load();
    });
    tearDown(() => controller.dispose());

    test('failure retains user message; retry does not duplicate it', () async {
      llm.fail = true;
      expect(await controller.send('Question'), isTrue);
      expect(controller.chatError, contains('unavailable'));
      expect(controller.sending, isFalse);
      expect(controller.canSend, isFalse);
      expect(controller.canRetry, isTrue);
      expect(
        (await repository.loadChat(workspace())).single.role,
        ChatRole.user,
      );
      llm.fail = false;
      await controller.retry();
      expect(controller.messages, hasLength(2));
      expect(llm.messages, hasLength(1));
      expect(controller.chatError, isNull);
    });

    test(
      'restart restores pending request and isolates another Subject',
      () async {
        llm.fail = true;
        await controller.send('Java question');
        final reopened = SubjectDetailController(
          workspace: workspace(),
          repository: repository,
          llm: TestLlm(),
          keys: MemoryKeys(),
        );
        final other = SubjectDetailController(
          workspace: workspace('DBI202'),
          repository: repository,
          llm: TestLlm(),
          keys: MemoryKeys(),
        );
        addTearDown(reopened.dispose);
        addTearDown(other.dispose);
        await reopened.load();
        await other.load();
        expect(reopened.canRetry, isTrue);
        expect(other.messages, isEmpty);
        await other.send('Database question');
        expect(reopened.messages.single.content, 'Java question');
      },
    );

    test('unsaved user message is not sent to Gemini', () async {
      repository.failWrite = true;
      expect(await controller.send('Question'), isFalse);
      expect(llm.calls, 0);
      expect(controller.messages, isEmpty);
      expect(controller.chatError, contains('could not be saved'));
    });

    test(
      'unsaved assistant answer retries persistence without another API request',
      () async {
        repository.failAnswerWrite = true;
        await controller.send('Question');
        expect(llm.calls, 1);
        expect(controller.messages, hasLength(1));
        repository.failAnswerWrite = false;
        await controller.retry();
        expect(llm.calls, 1);
        expect(controller.messages, hasLength(2));
      },
    );

    test('corrupt chat cannot be overwritten by send or clear', () async {
      await controller.send('Keep me');
      repository.failRead = true;
      await controller.loadChat();
      expect(controller.chatReady, isFalse);
      expect(await controller.send('Do not overwrite'), isFalse);
      await controller.clearChat();
      repository.failRead = false;
      expect(await repository.loadChat(workspace()), hasLength(2));
    });

    test('clear persists an empty scoped conversation', () async {
      await controller.send('Question');
      await controller.clearChat();
      expect(controller.messages, isEmpty);
      expect(await repository.loadChat(workspace()), isEmpty);
    });
  });

  group('explicit attachments', () {
    late MemoryRepository repository;
    late TestLlm llm;
    late TestAttachmentProcessor processor;
    late SubjectDetailController controller;
    late UserResource resource;

    setUp(() async {
      repository = MemoryRepository();
      resource = UserResource(
        id: 'diagram',
        curriculumCode: 'BIT_SE_K19B',
        subjectCode: 'PRJ301',
        originalFileName: 'diagram.png',
        storedFileName: 'diagram.png',
        extension: '.png',
        size: 4,
        importedAt: DateTime.utc(2026),
      );
      repository.resources.add(resource);
      llm = TestLlm();
      processor = TestAttachmentProcessor();
      controller = SubjectDetailController(
        workspace: workspace(),
        repository: repository,
        llm: llm,
        keys: MemoryKeys(),
        attachmentProcessor: processor,
      );
      await controller.load();
    });
    tearDown(() => controller.dispose());

    test('no resource is sent without explicit selection', () async {
      await controller.send('Explain this');
      expect(processor.processedIds, isEmpty);
      expect(llm.attachments, isEmpty);
      expect(controller.messages.first.resourceIds, isEmpty);
    });

    test(
      'selected resources are resolved, sent, and persisted by ID',
      () async {
        controller.setResourceSelected(resource.id, true);
        await controller.send('Explain this diagram');
        expect(processor.processedIds, [resource.id]);
        expect(llm.attachments!.single.resourceId, resource.id);
        expect(controller.messages.first.resourceIds, [resource.id]);
        expect(controller.selectedResourceIds, isEmpty);
      },
    );

    test('removing a selected chip excludes it from the request', () async {
      controller.setResourceSelected(resource.id, true);
      controller.removeSelectedResource(resource.id);
      await controller.send('No attachment');
      expect(llm.attachments, isEmpty);
    });

    test(
      'attachment processing failure is explicit and does not persist',
      () async {
        processor.fail = true;
        controller.setResourceSelected(resource.id, true);
        expect(await controller.send('Explain'), isFalse);
        expect(controller.chatError, contains('processing failed'));
        expect(controller.messages, isEmpty);
        expect(llm.calls, 0);
      },
    );
  });
}
