import 'package:flutter/material.dart';

import '../../domain/graph_model.dart';
import '../../domain/subject_record.dart';

/// Side panel shown when a node is selected: full subject metadata (plus its
/// curated topic/subtopic tree) for a subject node, or — for a topic/subtopic
/// node — that node's place in the tree *plus* the subject's own description
/// and full CLO list, since that's the actual source material the topic/
/// subtopic data was curated from (see `domain/concept_data.dart`). Showing
/// it here isn't a claim that a given CLO maps precisely to a given topic —
/// there's no such per-topic mapping stored — just that this is the material
/// a person would want at hand while looking at a topic/subtopic node.
class SubjectDetailPanel extends StatelessWidget {
  const SubjectDetailPanel({
    super.key,
    required this.node,
    required this.subject,
    required this.knowledgeGraph,
    required this.onClose,
  });

  final GraphNodeData node;

  /// The subject record backing [node] — the subject itself for a subject
  /// node, or (via `attributes['subjectCode']`, resolved by the caller) the
  /// subject a topic/subtopic node belongs to. Null only if that lookup
  /// somehow fails to find a subject record at all.
  final SubjectRecord? subject;

  /// The currently-drawn graph, used to look up a topic's subtopics (for a
  /// topic node), a subtopic's sibling subtopics (for a subtopic node), or a
  /// subject's topics (for the subject node) by walking `HAS_TOPIC`/
  /// `HAS_SUBTOPIC` edges rather than re-fetching concept data.
  final KnowledgeGraph knowledgeGraph;

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      node.label,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Đóng',
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: switch (node.type) {
                NodeType.topic => _TopicDetails(
                    node: node,
                    graph: knowledgeGraph,
                    subject: subject,
                  ),
                NodeType.subtopic => _SubtopicDetails(
                    node: node,
                    graph: knowledgeGraph,
                    subject: subject,
                  ),
                _ => subject != null
                    ? _SubjectDetails(subject: subject!, graph: knowledgeGraph)
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Không tìm thấy dữ liệu môn học.'),
                        ),
                      ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectDetails extends StatelessWidget {
  const _SubjectDetails({required this.subject, required this.graph});

  final SubjectRecord subject;
  final KnowledgeGraph graph;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topicEdges = graph.edges.where(
      (e) => e.relation == RelationType.hasTopic && e.sourceId == subject.subjectCode,
    );
    final topicNodes = [
      for (final e in topicEdges)
        if (graph.nodesById[e.targetId] != null) graph.nodesById[e.targetId]!,
    ];
    final subtopicCount = graph.edges
        .where((e) => e.relation == RelationType.hasSubtopic)
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (subject.syllabusName.isNotEmpty)
          Text(subject.syllabusName, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (subject.credits.isNotEmpty)
              Chip(label: Text('${subject.credits} tín chỉ')),
            if (subject.degreeLevel.isNotEmpty)
              Chip(label: Text(subject.degreeLevel)),
            if (subject.learningTeachingMethod.isNotEmpty)
              Chip(label: Text(subject.learningTeachingMethod)),
          ],
        ),
        const SizedBox(height: 16),
        _SectionTitle(
          'Chủ đề được nhận diện (${topicNodes.length} chủ đề · $subtopicCount khái niệm con)',
        ),
        if (topicNodes.isEmpty)
          Text(
            'Chưa có dữ liệu chủ đề được biên soạn cho môn này.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final topicNode in topicNodes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TopicTree(topicNode: topicNode, graph: graph),
                ),
            ],
          ),
        const SizedBox(height: 8),
        _SectionTitle('Điều kiện tiên quyết (nguyên văn FLM)'),
        Text(
          subject.prerequisiteRaw.isEmpty ? 'Không có' : subject.prerequisiteRaw,
          style: theme.textTheme.bodyMedium,
        ),
        if (subject.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionTitle('Mô tả'),
          Text(subject.description, style: theme.textTheme.bodyMedium),
        ],
        if (subject.learningOutcomes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionTitle('Chuẩn đầu ra (${subject.learningOutcomes.length})'),
          _CloList(outcomes: subject.learningOutcomes),
        ],
      ],
    );
  }
}

/// One topic chip plus its subtopic chips underneath, used both inline in
/// `_SubjectDetails` (one per topic) and matching what's drawn in the graph.
class _TopicTree extends StatelessWidget {
  const _TopicTree({required this.topicNode, required this.graph});

  final GraphNodeData topicNode;
  final KnowledgeGraph graph;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtopicNodes = [
      for (final e in graph.edges)
        if (e.relation == RelationType.hasSubtopic && e.sourceId == topicNode.id)
          if (graph.nodesById[e.targetId] != null) graph.nodesById[e.targetId]!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(
          label: Text(topicNode.label),
          backgroundColor: theme.colorScheme.secondaryContainer,
          labelStyle: TextStyle(
            color: theme.colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtopicNodes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in subtopicNodes)
                  Chip(
                    label: Text(s.label),
                    backgroundColor: theme.colorScheme.tertiaryContainer,
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onTertiaryContainer,
                      fontSize: 12,
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Shown when the selected node is a topic: the subject it belongs to, its
/// subtopics, and (when the subject record is available) the subject's own
/// description and full CLO list — the source material this topic was
/// curated from.
class _TopicDetails extends StatelessWidget {
  const _TopicDetails({
    required this.node,
    required this.graph,
    required this.subject,
  });

  final GraphNodeData node;
  final KnowledgeGraph graph;
  final SubjectRecord? subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjectCode = node.attributes['subjectCode']?.toString() ?? '';
    final subtopicNodes = [
      for (final e in graph.edges)
        if (e.relation == RelationType.hasSubtopic && e.sourceId == node.id)
          if (graph.nodesById[e.targetId] != null) graph.nodesById[e.targetId]!,
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Chủ đề "${node.label}" thuộc môn '
          '${subjectCode.isEmpty ? '' : subjectCode} (biên soạn từ Mô tả/'
          'CLO của môn, không phải trường dữ liệu có sẵn từ FLM).',
          style: theme.textTheme.bodyMedium,
        ),
        if (subtopicNodes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionTitle('Khái niệm con (${subtopicNodes.length})'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in subtopicNodes) Chip(label: Text(s.label)),
            ],
          ),
        ],
        if (subject != null) ..._subjectSourceSections(subject!),
      ],
    );
  }
}

/// Shown when the selected node is a subtopic: which subject and which
/// parent topic it's nested under, its sibling subtopics under that same
/// topic, and (when the subject record is available) the subject's own
/// description and full CLO list.
class _SubtopicDetails extends StatelessWidget {
  const _SubtopicDetails({
    required this.node,
    required this.graph,
    required this.subject,
  });

  final GraphNodeData node;
  final KnowledgeGraph graph;
  final SubjectRecord? subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjectCode = node.attributes['subjectCode']?.toString() ?? '';
    final topicLabel = node.attributes['topicLabel']?.toString() ?? '';

    // Find the parent topic by scanning for the HAS_SUBTOPIC edge that
    // points at this node, then every sibling subtopic hanging off that same
    // parent (excluding this node itself).
    String? parentTopicId;
    for (final e in graph.edges) {
      if (e.relation == RelationType.hasSubtopic && e.targetId == node.id) {
        parentTopicId = e.sourceId;
        break;
      }
    }
    final siblingNodes = parentTopicId == null
        ? const <GraphNodeData>[]
        : [
            for (final e in graph.edges)
              if (e.relation == RelationType.hasSubtopic &&
                  e.sourceId == parentTopicId &&
                  e.targetId != node.id)
                if (graph.nodesById[e.targetId] != null)
                  graph.nodesById[e.targetId]!,
          ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Khái niệm "${node.label}" thuộc chủ đề '
          '${topicLabel.isEmpty ? '' : '"$topicLabel" '}của môn '
          '${subjectCode.isEmpty ? '' : subjectCode} (biên soạn từ Mô tả/'
          'CLO của môn, không phải trường dữ liệu có sẵn từ FLM).',
          style: theme.textTheme.bodyMedium,
        ),
        if (siblingNodes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionTitle(
            'Khái niệm khác cùng chủ đề (${siblingNodes.length})',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in siblingNodes) Chip(label: Text(s.label)),
            ],
          ),
        ],
        if (subject != null) ..._subjectSourceSections(subject!),
      ],
    );
  }
}

/// Shared tail section appended to `_TopicDetails`/`_SubtopicDetails`: the
/// subject's description and full CLO list, framed explicitly as the source
/// material the topic/subtopic tree was curated from — not a claim that any
/// one CLO maps specifically to the node being viewed.
List<Widget> _subjectSourceSections(SubjectRecord subject) {
  return [
    if (subject.description.isNotEmpty) ...[
      const SizedBox(height: 20),
      const Divider(),
      const SizedBox(height: 8),
      _SectionTitle('Mô tả môn (nguồn biên soạn chủ đề/khái niệm này)'),
      Builder(
        builder: (context) => Text(
          subject.description,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    ],
    if (subject.learningOutcomes.isNotEmpty) ...[
      const SizedBox(height: 16),
      _SectionTitle(
        'Chuẩn đầu ra (CLO) của môn (${subject.learningOutcomes.length})',
      ),
      _CloList(outcomes: subject.learningOutcomes),
    ],
  ];
}

/// Renders a subject's CLO list as `CLO1: <detail>` rows — shared by
/// `_SubjectDetails` and the topic/subtopic "source sections" so both look
/// identical.
class _CloList extends StatelessWidget {
  const _CloList({required this.outcomes});

  final List<LearningOutcome> outcomes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final lo in outcomes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: '${lo.code}: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: lo.detail),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
