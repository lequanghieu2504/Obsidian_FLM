import 'concept_data.dart';
import 'graph_model.dart';
import 'subject_record.dart';

/// Builds the small "concept graph" for one subject: the subject itself in
/// the centre, one node per topic curated for it (`SubjectConcepts`, loaded
/// via `ConceptRepository`), and one node per subtopic nested under each
/// topic — a 3-tier star/tree, not a cross-subject graph.
///
/// Earlier versions of this feature built a single graph across all 84
/// subjects, linked by their official `Pre-Requisite` field, then a flat
/// subject->concept star matched by a keyword dictionary at runtime. Both
/// are gone — see `README.md` §0 for the full reasoning, most recently "Lần
/// 3" (why runtime keyword-matching was replaced with curated hierarchical
/// data). `subject.prerequisiteRaw` is still shown verbatim in
/// `SubjectDetailPanel`; it's just never turned into graph edges.
abstract class KnowledgeGraphBuilder {
  static KnowledgeGraph buildConceptGraph(
    SubjectRecord subject,
    SubjectConcepts concepts,
  ) {
    final nodes = <GraphNodeData>[
      GraphNodeData(
        id: subject.subjectCode,
        type: NodeType.subject,
        label: subject.displayLabel,
        attributes: {
          'syllabusId': subject.syllabusId,
          'name': subject.syllabusName,
          'nameEnglish': subject.courseNameEnglish,
          'credits': subject.credits,
          'degreeLevel': subject.degreeLevel,
          'method': subject.learningTeachingMethod,
          'description': subject.description,
          'prerequisiteRaw': subject.prerequisiteRaw,
          'learningOutcomeCount': subject.learningOutcomes.length,
        },
      ),
    ];
    final edges = <GraphEdgeData>[];

    for (final topic in concepts.topics) {
      final topicSlug = _slug(topic.label);
      final topicId = '${subject.subjectCode}::topic:$topicSlug';
      nodes.add(GraphNodeData(
        id: topicId,
        type: NodeType.topic,
        label: topic.label,
        attributes: {
          'subjectCode': subject.subjectCode,
          'subtopicCount': topic.subtopics.length,
        },
      ));
      edges.add(GraphEdgeData(
        sourceId: subject.subjectCode,
        targetId: topicId,
        relation: RelationType.hasTopic,
        category: RelationCategory.inferred,
      ));

      for (final subtopicLabel in topic.subtopics) {
        final subtopicId =
            '$topicId::subtopic:${_slug(subtopicLabel)}';
        nodes.add(GraphNodeData(
          id: subtopicId,
          type: NodeType.subtopic,
          label: subtopicLabel,
          attributes: {
            'subjectCode': subject.subjectCode,
            'topicLabel': topic.label,
          },
        ));
        edges.add(GraphEdgeData(
          sourceId: topicId,
          targetId: subtopicId,
          relation: RelationType.hasSubtopic,
          category: RelationCategory.inferred,
        ));
      }
    }

    return KnowledgeGraph(nodes: nodes, edges: edges);
  }

  /// Lowercase, hyphenated, ASCII-only id fragment for a topic/subtopic
  /// label (which may be Vietnamese, e.g. "Chủ đề giao tiếp"). Diacritics
  /// are stripped rather than percent-encoded so ids stay short and
  /// readable in debug output.
  static String _slug(String label) {
    const withDiacritics =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const withoutDiacritics =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

    var result = label.toLowerCase();
    for (var i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    result = result.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    result = result.replaceAll(RegExp(r'^-+|-+$'), '');
    return result.isEmpty ? 'x' : result;
  }
}
