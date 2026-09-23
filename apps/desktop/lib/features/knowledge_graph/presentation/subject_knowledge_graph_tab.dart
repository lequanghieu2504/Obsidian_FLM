import 'package:flutter/material.dart';

import '../data/concept_repository.dart';
import '../data/subject_repository.dart';
import '../domain/concept_data.dart';
import '../domain/graph_model.dart';
import '../domain/knowledge_graph_builder.dart';
import '../domain/subject_record.dart';
import 'widgets/concept_graph_canvas.dart';
import 'widgets/graph_tooltip.dart';
import 'widgets/node_session_info_panel.dart';

/// The "graph" half of [KnowledgeGraphPage] — the concept graph for one
/// already-known subject — without its picker grid, search box or back
/// button, so it can be embedded as a tab inside [SubjectDetailScreen].
///
/// Deliberately does **not** show the full [SubjectDetailPanel] on node
/// tap: subject-wide metadata (description, CLOs, the raw Session plan
/// table, ...) already lives in the detail screen's own Detail-side tabs
/// (see `SubjectOverviewPanel`, `LearningOutcomesPanel`,
/// `OtherSyllabusFieldsPanel`, and `SyllabusTablePanel` in
/// `subject_resources_panel.dart`), so repeating it here on every node tap
/// would just be a duplicate.
///
/// Tapping a topic/subtopic node still selects/highlights it on the canvas
/// *and* docks [NodeSessionInfoPanel] beside it — the one thing those
/// sibling tabs don't already answer for a specific topic/subtopic: which
/// session(s) of the subject's own Session plan actually cover it (see
/// `domain/session_plan.dart`). That panel is a plain docked side panel,
/// not a `showDialog` popup — it never blocks or dims the canvas, so
/// clicking around the graph with it open still works. Tapping the subject
/// (centre) node only selects/highlights it; there's no per-session
/// question to answer for the whole subject.
///
/// Loads the same `data/subject/` + `data/concepts/concepts.json` assets
/// independently (this tab may be opened before the subjects feature's own
/// data has loaded, and the two features intentionally don't share a
/// repository), then looks up [subjectCode] the same way
/// [KnowledgeGraphPage] does.
class SubjectKnowledgeGraphTab extends StatefulWidget {
  const SubjectKnowledgeGraphTab({
    super.key,
    required this.subjectCode,
    this.repository = const SubjectRepository(),
    this.conceptRepository = const ConceptRepository(),
  });

  /// Joined against [SubjectRecord.subjectCode] — the same business key
  /// (e.g. `MAE101`) the subjects feature's `Subject.code` uses.
  final String subjectCode;
  final SubjectRepository repository;
  final ConceptRepository conceptRepository;

  @override
  State<SubjectKnowledgeGraphTab> createState() =>
      _SubjectKnowledgeGraphTabState();
}

class _SubjectKnowledgeGraphTabState extends State<SubjectKnowledgeGraphTab> {
  late Future<KnowledgeGraph?> _loadFuture;
  String? _selectedNodeId;

  /// Set by [_load] alongside the returned graph — kept separately
  /// because [build] needs the subject record (for [NodeSessionInfoPanel])
  /// and [_load]'s own return type only carries the graph.
  SubjectRecord? _subject;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  @override
  void didUpdateWidget(covariant SubjectKnowledgeGraphTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subjectCode != widget.subjectCode) {
      setState(() {
        _selectedNodeId = null;
        _loadFuture = _load();
      });
    }
  }

  Future<KnowledgeGraph?> _load() async {
    final results = await Future.wait([
      widget.repository.loadAll(),
      widget.conceptRepository.loadAll(),
    ]);
    final subjects = results[0] as List<SubjectRecord>;
    final conceptsByCode = results[1] as Map<String, SubjectConcepts>;

    SubjectRecord? subject;
    for (final candidate in subjects) {
      if (candidate.subjectCode == widget.subjectCode) {
        subject = candidate;
        break;
      }
    }
    _subject = subject;
    if (subject == null) return null;

    final concepts =
        conceptsByCode[widget.subjectCode] ?? SubjectConcepts.empty;
    _selectedNodeId = widget.subjectCode;
    return KnowledgeGraphBuilder.buildConceptGraph(subject, concepts);
  }

  void _onNodeTap(String id) {
    setState(() => _selectedNodeId = _selectedNodeId == id ? null : id);
  }

  // No search box on this tab, so no node is ever query-highlighted.
  bool _neverHighlighted(GraphNodeData node) => false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<KnowledgeGraph?>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Không tải được đồ thị tri thức:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final knowledgeGraph = snapshot.data;
        if (knowledgeGraph == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Không tìm thấy dữ liệu đồ thị tri thức cho môn '
                '${widget.subjectCode} trong data/subject/.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final subject = _subject;
        final selectedNode = _selectedNodeId == null
            ? null
            : knowledgeGraph.nodesById[_selectedNodeId];

        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              if (knowledgeGraph.edges.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Chưa có dữ liệu chủ đề được biên soạn cho môn này — chỉ '
                    'có node của chính môn học.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Fixed-width panel + Expanded canvas would overflow
                    // ("RenderFlex overflowed... on the right") whenever
                    // this tab's own share of the page is narrower than
                    // the panel's fixed width — e.g. the person drags the
                    // page's chat/detail split so this side sits near its
                    // floor. Sizing the panel as a fraction of whatever
                    // width this tab actually has, capped at 380 and
                    // floored at 240, means the canvas's own Expanded
                    // share can never go negative, so the row can never
                    // overflow regardless of how the split is dragged.
                    final rawPanelWidth = constraints.maxWidth * 0.45;
                    final panelWidth = rawPanelWidth < 240
                        ? 240.0
                        : rawPanelWidth > 380
                            ? 380.0
                            : rawPanelWidth;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Docked on the left of the canvas (the Detail
                        // side's own left edge) rather than the right, so
                        // it never sits flush against the boundary with
                        // the page's separate chat panel.
                        if (subject != null &&
                            selectedNode != null &&
                            selectedNode.type != NodeType.subject)
                          SizedBox(
                            width: panelWidth,
                            child: NodeSessionInfoPanel(
                              node: selectedNode,
                              subject: subject,
                              graph: knowledgeGraph,
                              onClose: () =>
                                  setState(() => _selectedNodeId = null),
                            ),
                          ),
                        Expanded(
                          child: ConceptGraphCanvas(
                            key: ValueKey(
                              'subject-tab-graph-${widget.subjectCode}',
                            ),
                            knowledgeGraph: knowledgeGraph,
                            subjectId: widget.subjectCode,
                            selectedNodeId: _selectedNodeId,
                            isHighlighted: _neverHighlighted,
                            onNodeTap: _onNodeTap,
                            tooltipMessage: graphNodeTooltipMessage,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
