import '../../../models/subject.dart';

/// User data is identified by both curriculum and subject, never by code alone.
class SubjectWorkspace {
  const SubjectWorkspace({required this.curriculumCode, required this.subject});

  final String curriculumCode;
  final Subject subject;
  String get subjectCode => subject.code;
}

class UserResource {
  const UserResource({
    required this.id,
    required this.curriculumCode,
    required this.subjectCode,
    required this.originalFileName,
    required this.storedFileName,
    required this.extension,
    required this.size,
    required this.importedAt,
  });

  final String id;
  final String curriculumCode;
  final String subjectCode;
  final String originalFileName;
  final String storedFileName;
  final String extension;
  final int size;
  final DateTime importedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'curriculumCode': curriculumCode,
    'subjectCode': subjectCode,
    'originalFileName': originalFileName,
    'storedFileName': storedFileName,
    'extension': extension,
    'size': size,
    'importedAt': importedAt.toUtc().toIso8601String(),
  };

  factory UserResource.fromJson(Map<String, dynamic> json) => UserResource(
    id: json['id'] as String,
    curriculumCode: json['curriculumCode'] as String,
    subjectCode: json['subjectCode'] as String,
    originalFileName: json['originalFileName'] as String,
    storedFileName: json['storedFileName'] as String,
    extension: json['extension'] as String,
    size: json['size'] as int,
    importedAt: DateTime.parse(json['importedAt'] as String),
  );
}

enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    this.id = '',
    required this.role,
    required this.content,
    required this.timestamp,
    this.resourceIds = const [],
    this.resourceFileNames = const {},
  });
  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;
  final List<String> resourceIds;
  final Map<String, String> resourceFileNames;

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'content': content,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'resourceIds': resourceIds,
    'resourceFileNames': resourceFileNames,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String? ?? '',
    role: ChatRole.values.byName(json['role'] as String),
    content: json['content'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    resourceIds:
        (json['resourceIds'] as List<dynamic>?)?.whereType<String>().toList() ??
        const [],
    resourceFileNames:
        (json['resourceFileNames'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value as String),
        ) ??
        const {},
  );
}

abstract interface class SubjectWorkspaceRepository {
  Future<List<UserResource>> loadResources(SubjectWorkspace workspace);
  Future<UserResource> importResource(
    SubjectWorkspace workspace,
    String sourcePath,
  );
  Future<void> deleteResource(
    SubjectWorkspace workspace,
    UserResource resource,
  );
  Future<String> resourcePath(
    SubjectWorkspace workspace,
    UserResource resource,
  );
  Future<List<ChatMessage>> loadChat(SubjectWorkspace workspace);
  Future<void> saveChat(SubjectWorkspace workspace, List<ChatMessage> messages);
}

/// Only intentionally safe, actionable messages cross into the UI.
class WorkspaceFailure implements Exception {
  const WorkspaceFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
