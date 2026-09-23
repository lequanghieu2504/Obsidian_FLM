import '../../domain/graph_model.dart';

/// Short multi-line hover text for a node, shown as a `Tooltip` wherever a
/// [ConceptGraphCanvas] is drawn ([KnowledgeGraphPage] and
/// [SubjectKnowledgeGraphTab]). Subject nodes get their name/credits/degree
/// level and a trimmed description; topic/subtopic nodes get which
/// subject/topic they belong to.
String graphNodeTooltipMessage(GraphNodeData data) {
  switch (data.type) {
    case NodeType.topic:
      final subjectCode = (data.attributes['subjectCode'] ?? '').toString();
      final subtopicCount = data.attributes['subtopicCount'] ?? 0;
      return '${data.label}\n'
          'Chủ đề của môn $subjectCode · $subtopicCount khái niệm con\n'
          'Bấm để xem thuộc buổi học nào';
    case NodeType.subtopic:
      final subjectCode = (data.attributes['subjectCode'] ?? '').toString();
      final topicLabel = (data.attributes['topicLabel'] ?? '').toString();
      return '${data.label}\n'
          'Thuộc chủ đề "$topicLabel" · Môn $subjectCode\n'
          'Bấm để xem thuộc buổi học nào';
    case NodeType.subject:
    default:
      final name = (data.attributes['name'] ?? '').toString();
      final credits = (data.attributes['credits'] ?? '').toString();
      final degreeLevel = (data.attributes['degreeLevel'] ?? '').toString();
      final description = (data.attributes['description'] ?? '').toString();

      final lines = <String>[data.label];
      if (name.isNotEmpty) lines.add(name);
      final meta = [
        if (credits.isNotEmpty && credits != '0') '$credits tín chỉ',
        if (degreeLevel.isNotEmpty) degreeLevel,
      ].join(' · ');
      if (meta.isNotEmpty) lines.add(meta);
      if (description.isNotEmpty) {
        lines.add(
          description.length > 160
              ? '${description.substring(0, 160)}…'
              : description,
        );
      }
      return lines.join('\n');
  }
}
