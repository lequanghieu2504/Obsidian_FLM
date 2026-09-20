import 'package:obsidian_flm_desktop/features/assistant/application/llm_client.dart';
import 'package:obsidian_flm_desktop/features/subjects/domain/subject_workspace.dart';
import 'package:obsidian_flm_desktop/models/subject.dart';

SubjectWorkspace workspace([
  String code = 'PRJ301',
  String curriculum = 'BIT_SE_K19B',
]) => SubjectWorkspace(
  curriculumCode: curriculum,
  subject: Subject(
    semester: 4,
    code: code,
    name: code == 'PRJ301'
        ? 'Java Web Application Development'
        : 'Database Systems',
    credits: '3',
    preRequisite: code == 'PRJ301' ? 'DBI202, PRO192' : 'PRO192',
  ),
);

class MemoryKeys implements GeminiKeyStore {
  String? value = 'test-key';
  bool fail = false;
  @override
  Future<String?> read() async {
    if (fail) throw StateError('secret');
    return value;
  }

  @override
  Future<void> write(String key) async {
    if (fail) throw StateError('secret');
    value = key;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

class TestLlm implements LlmClient {
  int calls = 0;
  bool fail = false;
  String? context;
  List<ChatMessage>? messages;
  List<ChatAttachment>? attachments;
  @override
  Future<String> send({
    required String context,
    required List<ChatMessage> messages,
    List<ChatAttachment> attachments = const [],
  }) async {
    calls++;
    this.context = context;
    this.messages = messages;
    this.attachments = attachments;
    if (fail) {
      throw const WorkspaceFailure('Gemini is unavailable. Please retry.');
    }
    return 'Test response';
  }

  @override
  void close() {}
}

class MemoryRepository implements SubjectWorkspaceRepository {
  final Map<String, List<ChatMessage>> chats = {};
  final List<UserResource> resources = [];
  bool failRead = false;
  bool failWrite = false;
  bool failAnswerWrite = false;
  String key(SubjectWorkspace workspace) =>
      '${workspace.curriculumCode}/${workspace.subjectCode}';
  @override
  Future<List<ChatMessage>> loadChat(SubjectWorkspace workspace) async {
    if (failRead) throw StateError('read failed');
    return List.of(chats[key(workspace)] ?? []);
  }

  @override
  Future<void> saveChat(
    SubjectWorkspace workspace,
    List<ChatMessage> messages,
  ) async {
    if (failWrite ||
        (failAnswerWrite && messages.lastOrNull?.role == ChatRole.assistant)) {
      throw StateError('write failed');
    }
    chats[key(workspace)] = List.of(messages);
  }

  @override
  Future<List<UserResource>> loadResources(SubjectWorkspace workspace) async {
    if (failRead) throw StateError('read failed');
    return List.of(resources);
  }

  @override
  Future<UserResource> importResource(
    SubjectWorkspace workspace,
    String sourcePath,
  ) async => throw UnimplementedError();
  @override
  Future<void> deleteResource(
    SubjectWorkspace workspace,
    UserResource resource,
  ) async {
    resources.remove(resource);
  }

  @override
  Future<String> resourcePath(
    SubjectWorkspace workspace,
    UserResource resource,
  ) async => 'app-owned/${resource.storedFileName}';
}

class TestAttachmentProcessor implements ChatAttachmentProcessor {
  final List<String> processedIds = [];
  bool fail = false;

  @override
  Future<ChatAttachment> process(
    UserResource resource,
    String appOwnedPath,
  ) async {
    if (fail) throw const WorkspaceFailure('Attachment processing failed.');
    processedIds.add(resource.id);
    return ChatAttachment(
      resourceId: resource.id,
      fileName: resource.originalFileName,
      mimeType: 'text/plain',
      text: 'attachment text',
    );
  }
}
