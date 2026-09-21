import '../../knowledge_graph/domain/subject_record.dart';
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

  /// Metadata keys already surfaced as named fields (here, and in
  /// `SubjectOverviewPanel`'s UI) — public so both skip the same set
  /// when dumping [SubjectRecord.metadata]'s remaining entries, instead
  /// of drifting out of sync with two separately maintained lists.
  static const namedMetadataKeys = {
    'Syllabus ID',
    'Subject Code',
    'Syllabus Name',
    'Course Name English',
    'Degree Level',
    'NoCredit',
    'Learning-Teaching Method',
    'Pre-Requisite',
    'Description',
  };

  /// [syllabus] is this subject's full FLM syllabus record, loaded from
  /// `data/subject/` (see `SubjectRepository.loadByCode`) — null if no
  /// matching file was found, in which case the prompt falls back to just
  /// the curriculum's own [SubjectWorkspace.subject] fields.
  String build(SubjectWorkspace workspace, {SubjectRecord? syllabus}) {
    final subject = workspace.subject;
    final buffer = StringBuffer();

    buffer.writeln('You are assisting the user with the selected Subject.');
    buffer.writeln('Current curriculum: ${workspace.curriculumCode}');
    buffer.writeln('Current subject:');
    buffer.writeln('Code: ${subject.code}');
    buffer.writeln('Name: ${subject.name}');
    buffer.writeln('Semester: ${subject.semester}');
    buffer.writeln('Credits: ${subject.credits}');
    buffer.writeln(
      'Prerequisite: '
      '${subject.preRequisite.isEmpty ? 'Not provided' : subject.preRequisite}',
    );

    if (syllabus == null) {
      buffer.writeln(
        'No detailed syllabus record was found for this subject in '
        'data/subject/ — only the fields above are available.',
      );
    } else {
      buffer.writeln();
      buffer.writeln('Full syllabus (from data/subject/):');
      buffer.writeln('Syllabus name: ${syllabus.syllabusName}');
      buffer.writeln('Course name (English): ${syllabus.courseNameEnglish}');
      buffer.writeln('Degree level: ${syllabus.degreeLevel}');
      buffer.writeln(
        'Learning-teaching method: ${syllabus.learningTeachingMethod}',
      );
      buffer.writeln(
        'Prerequisite (syllabus wording): '
        '${syllabus.prerequisiteRaw.isEmpty ? 'Not provided' : syllabus.prerequisiteRaw}',
      );
      buffer.writeln(
        'Description: '
        '${syllabus.description.isEmpty ? 'Not provided' : syllabus.description}',
      );
      if (syllabus.learningOutcomes.isNotEmpty) {
        buffer.writeln('Course learning outcomes (CLOs):');
        for (final outcome in syllabus.learningOutcomes) {
          buffer.writeln('- ${outcome.code}: ${outcome.detail}');
        }
      }

      final extraMetadata = syllabus.metadata.entries.where(
        (entry) =>
            !namedMetadataKeys.contains(entry.key) && entry.value.isNotEmpty,
      );
      if (extraMetadata.isNotEmpty) {
        buffer.writeln();
        buffer.writeln(
          'Other syllabus fields (grading scale, tools, workload, '
          'approval/administrative info, ...):',
        );
        for (final entry in extraMetadata) {
          buffer.writeln('- ${entry.key}: ${entry.value}');
        }
      }

      for (final section in syllabus.sections) {
        if (section.rows.isEmpty) continue;
        buffer.writeln();
        buffer.writeln('${section.heading}:');
        for (final row in section.rows) {
          final cells = section.headers.length == row.length
              ? [
                  for (var i = 0; i < row.length; i++)
                    if (row[i].isNotEmpty) '${section.headers[i]}: ${row[i]}',
                ]
              : row.where((cell) => cell.isNotEmpty).toList();
          if (cells.isEmpty) continue;
          buffer.writeln('- ${cells.join(' | ')}');
        }
      }
    }

    buffer.writeln();
    buffer.writeln(
      'These fields are the only academic source context provided. Do not '
      'invent syllabus content or claim that general knowledge came from '
      'FLM. Clearly distinguish general explanations from the provided '
      'metadata. If information is unavailable, say so. Files are included '
      'only when the user explicitly attaches them to the current message.',
    );
    return buffer.toString();
  }
}
