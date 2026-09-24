import 'package:flutter/material.dart';

import '../../domain/constructive_questions.dart';
import '../../domain/graph_model.dart';
import '../../domain/node_evidence.dart';
import '../../domain/session_plan.dart';
import '../../domain/subject_record.dart';

/// Non-modal side panel shown next to the graph canvas when a topic/
/// subtopic node is selected — docked beside the canvas (see
/// `SubjectKnowledgeGraphTab`'s build method), never a `showDialog` popup.
/// A `showDialog` popup paints above the *entire* page (via the root
/// `Navigator`), which would also dim/block the page's one [SubjectChatPanel]
/// next to this tab; a docked panel only ever takes space inside this tab's
/// own content area, so the chat stays fully visible and usable — a person
/// can open this panel, read it, ask the assistant about the same concept,
/// and close the panel again, all without either ever blocking the other.
///
/// Pulls together everything the subject's raw JSON has that mentions this
/// node's label — "get everything from the file" rather than a curated
/// subset:
/// - what it is: sentence(s) from the subject's Description/CLOs that
///   actually name it ([nodeContextSnippetsFor]) — the closest thing FLM's
///   export has to a definition, since there's no dedicated per-concept
///   definition field;
/// - "học ở đâu"/"session mấy": which Session plan row(s) cover it, with
///   every column FLM records for that row — teaching type, ITU
///   classification, materials, download link, student tasks, URLs (see
///   `domain/session_plan.dart`);
/// - "câu hỏi trả lời được": the Constructive question(s) tied to each of
///   those same sessions (`domain/constructive_questions.dart`);
/// - anything else: any other syllabus table (reference materials,
///   assessments, ...) whose cells happen to mention the label too
///   ([otherSectionMentionsFor]).
class NodeSessionInfoPanel extends StatelessWidget {
  const NodeSessionInfoPanel({
    super.key,
    required this.node,
    required this.subject,
    required this.graph,
    required this.onClose,
  });

  /// The selected node. Expected to be a [NodeType.topic] or
  /// [NodeType.subtopic] node — callers should not show this panel for a
  /// [NodeType.subject] node (there's no "which session teaches the whole
  /// subject" question to answer).
  final GraphNodeData node;

  /// The subject record the node belongs to (via
  /// `node.attributes['subjectCode']`, resolved by the caller).
  final SubjectRecord subject;

  /// The currently-drawn graph, used only to look up a topic node's own
  /// subtopics (via `HAS_SUBTOPIC` edges) — a curated topic label
  /// ("Vector Spaces") sometimes appears verbatim in the syllabus text
  /// itself, but its session coverage is still best found as the union of
  /// its subtopics' matches too (see [_labelsToMatch]).
  final KnowledgeGraph graph;

  final VoidCallback onClose;

  List<String> _labelsToMatch() {
    final labels = <String>[node.label];
    if (node.type == NodeType.topic) {
      labels.addAll([
        for (final e in graph.edges)
          if (e.relation == RelationType.hasSubtopic && e.sourceId == node.id)
            if (graph.nodesById[e.targetId] != null)
              graph.nodesById[e.targetId]!.label,
      ]);
    }
    return labels;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSubtopic = node.type == NodeType.subtopic;
    final topicLabel = node.attributes['topicLabel']?.toString() ?? '';
    final subjectName = subject.syllabusName;
    final labels = _labelsToMatch();

    final contextSnippets = dedupeContextSnippets([
      for (final label in labels) ...nodeContextSnippetsFor(subject, label),
    ]);

    final sessionEntries = sessionPlanEntriesFor(subject);
    final matches = dedupeSessionPlanEntries([
      for (final label in labels)
        ...matchingSessionPlanEntries(label, sessionEntries),
    ])
      ..sort((a, b) => (int.tryParse(a.session) ?? 1 << 30)
          .compareTo(int.tryParse(b.session) ?? 1 << 30));
    final allQuestions = constructiveQuestionsFor(subject);

    final otherMentions = <OtherSectionMention>[
      for (final label in labels) ...otherSectionMentionsFor(subject, label),
    ];

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
                    child: Text(node.label, style: theme.textTheme.titleLarge),
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
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    isSubtopic
                        ? 'Khái niệm con thuộc chủ đề '
                            '${topicLabel.isEmpty ? '' : '"$topicLabel" '}'
                            'của môn ${subject.subjectCode}'
                            '${subjectName.isEmpty ? '' : ' – $subjectName'}.'
                        : 'Chủ đề thuộc môn ${subject.subjectCode}'
                            '${subjectName.isEmpty ? '' : ' – $subjectName'}.',
                    style: theme.textTheme.bodyMedium,
                  ),

                  if (contextSnippets.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionTitle('Định nghĩa / ngữ cảnh trong syllabus'),
                    for (final c in contextSnippets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: RichText(
                          text: TextSpan(
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.onSurface),
                            children: [
                              TextSpan(
                                text: '${c.source}: ',
                                style:
                                    const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(text: c.sentence),
                            ],
                          ),
                        ),
                      ),
                  ],

                  const SizedBox(height: 16),
                  Text(
                    sessionEntries.isEmpty
                        ? 'Môn này chưa có bảng kế hoạch buổi học (Session '
                            'plan) trong dữ liệu.'
                        : matches.isEmpty
                            ? 'Buổi học liên quan'
                            : 'Xuất hiện trong ${matches.length} buổi học:',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  if (sessionEntries.isNotEmpty && matches.isEmpty)
                    Text(
                      'Không tìm thấy buổi học nào nhắc trực tiếp tới '
                      '"${node.label}" trong Session plan của môn — có thể '
                      'khái niệm này được dạy lồng ghép trong một buổi mà '
                      'tiêu đề không nêu tên rõ.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  for (final m in matches)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _SessionMatchTile(
                        entry: m,
                        questions: constructiveQuestionsForSession(
                          m.session,
                          allQuestions,
                        ),
                      ),
                    ),

                  if (otherMentions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _SectionTitle('Nhắc tới thêm trong dữ liệu môn học'),
                    for (final mention in otherMentions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _OtherMentionTile(mention: mention),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One matched session's full record: title, module reference, teaching
/// type/ITU/CLOs, download link and student tasks — every column FLM's
/// Session plan table has — plus, when the subject's data has them, the
/// constructive questions tied to that same session number.
class _SessionMatchTile extends StatelessWidget {
  const _SessionMatchTile({required this.entry, required this.questions});

  final SessionPlanEntry entry;
  final List<ConstructiveQuestion> questions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.outline);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Buổi ${entry.session.isEmpty ? '?' : entry.session}: '
          '${entry.topic}',
          style:
              theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (entry.materials.isNotEmpty)
          Text(entry.materials, style: outline),
        if (entry.learningTeachingType.isNotEmpty ||
            entry.itu.isNotEmpty ||
            entry.learningOutcomes.isNotEmpty)
          Text(
            [
              if (entry.learningTeachingType.isNotEmpty)
                entry.learningTeachingType,
              if (entry.itu.isNotEmpty) 'ITU: ${entry.itu}',
              if (entry.learningOutcomes.isNotEmpty) entry.learningOutcomes,
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
        if (entry.studentTasks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Việc cần làm: ${entry.studentTasks}',
                style: theme.textTheme.bodySmall),
          ),
        if (entry.downloadLink.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Tài liệu: ${entry.downloadLink}', style: outline),
          ),
        if (entry.urls.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Link: ${entry.urls}', style: outline),
          ),
        if (questions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Câu hỏi gợi mở buổi này (${questions.length})',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          for (final q in questions)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurface),
                  children: [
                    if (q.name.isNotEmpty)
                      TextSpan(
                        text: '${q.name}: ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    TextSpan(text: q.details),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// One row from some other syllabus table (reference materials, an
/// assessment, ...) that happened to mention the node's label — shown as a
/// plain "column: value" list since this feature doesn't otherwise know
/// that table's shape.
class _OtherMentionTile extends StatelessWidget {
  const _OtherMentionTile({required this.mention});

  final OtherSectionMention mention;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          mention.sectionHeading,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        for (final e in mention.fields.entries)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurface),
                children: [
                  TextSpan(
                    text: '${e.key}: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: e.value),
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
