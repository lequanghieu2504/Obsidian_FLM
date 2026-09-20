import '../../subjects/domain/subject_workspace.dart';

abstract interface class LlmClient {
  Future<String> send({
    required String context,
    required List<ChatMessage> messages,
    List<ChatAttachment> attachments = const [],
  });
  void close();
}

class ChatAttachment {
  const ChatAttachment({
    required this.resourceId,
    required this.fileName,
    required this.mimeType,
    this.bytes,
    this.text,
  });

  final String resourceId;
  final String fileName;
  final String mimeType;
  final List<int>? bytes;
  final String? text;
}

abstract interface class ChatAttachmentProcessor {
  Future<ChatAttachment> process(UserResource resource, String appOwnedPath);
}

abstract interface class GeminiKeyStore {
  Future<String?> read();
  Future<void> write(String key);
  Future<void> delete();
}

class SubjectPromptBuilder {
  const SubjectPromptBuilder();

  String build(SubjectWorkspace workspace) {
    final subject = workspace.subject;
    return '''You are assisting the user with the selected Subject.
Current curriculum: ${workspace.curriculumCode}
Current subject:
Code: ${subject.code}
Name: ${subject.name}
Semester: ${subject.semester}
Credits: ${subject.credits}
Prerequisite: ${subject.preRequisite.isEmpty ? 'Not provided' : subject.preRequisite}

These fields are the only academic source context provided. Do not invent
syllabus content or claim that general knowledge came from FLM. Clearly distinguish
general explanations from the provided metadata. If information is unavailable,
say so. Files are included only when the user explicitly attaches them to the
current message.
''';
  }
}
