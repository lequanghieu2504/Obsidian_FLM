/// Storage-agnostic knowledge-graph node/edge shapes.
///
/// These mirror `schemas/graph-node.schema.json` and
/// `schemas/graph-edge.schema.json` (id/type for a node; sourceId/targetId/
/// relation/category for an edge) so the in-app graph stays compatible with
/// the project's cross-application contracts even though nothing here reads
/// or writes the JSON Schema files directly.
library graph_model;

/// Node kinds this feature produces.
abstract class NodeType {
  /// The one subject currently focused — the centre of its concept graph.
  static const subject = 'subject';

  /// A broad topic (e.g. "Mobile App Development") found in the subject's
  /// Description/CLO text — see `domain/concept_data.dart`.
  static const topic = 'topic';

  /// A narrower concept nested under a topic (e.g. "Flutter", "UI/UX" under
  /// "Mobile App Development").
  static const subtopic = 'subtopic';
}

/// Relation kinds this feature produces.
abstract class RelationType {
  /// Subject -> a topic found in its description/CLO text.
  static const hasTopic = 'HAS_TOPIC';

  /// Topic -> a subtopic nested under it.
  static const hasSubtopic = 'HAS_SUBTOPIC';
}

/// Whether an edge is a sourced FLM fact or a derived/inferred relation.
/// ADR-0003 requires these stay distinguishable. `HAS_TOPIC`/`HAS_SUBTOPIC`
/// edges are always `inferred`: the topic/subtopic data itself is curated
/// (read and organised by hand from each subject's Description/CLO text —
/// see `domain/concept_data.dart`), not a field FLM marks as "this
/// subject's topics" — there is no such field.
abstract class RelationCategory {
  static const official = 'official';
  static const inferred = 'inferred';
}

class GraphNodeData {
  const GraphNodeData({
    required this.id,
    required this.type,
    required this.label,
    this.attributes = const {},
  });

  final String id;
  final String type;
  final String label;

  /// Free-form extra fields (subject name, credits, parent topic, ...),
  /// intentionally untyped to match the schema's `additionalProperties: true`.
  final Map<String, Object?> attributes;
}

class GraphEdgeData {
  const GraphEdgeData({
    required this.sourceId,
    required this.targetId,
    required this.relation,
    required this.category,
    this.attributes = const {},
  });

  final String sourceId;
  final String targetId;
  final String relation;
  final String category;
  final Map<String, Object?> attributes;
}

/// The full graph produced for one render: every node/edge plus the
/// subjects it was built from, keyed for O(1) lookups from the UI.
class KnowledgeGraph {
  KnowledgeGraph({required this.nodes, required this.edges})
      : nodesById = {for (final n in nodes) n.id: n};

  final List<GraphNodeData> nodes;
  final List<GraphEdgeData> edges;
  final Map<String, GraphNodeData> nodesById;
}
