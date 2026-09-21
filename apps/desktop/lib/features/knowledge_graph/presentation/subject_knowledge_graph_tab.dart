import 'package:flutter/material.dart';

import '../data/concept_repository.dart';
import '../data/subject_repository.dart';
import '../domain/concept_data.dart';
import '../domain/graph_model.dart';
import '../domain/knowledge_graph_builder.dart';
import '../domain/subject_record.dart';
import 'widgets/concept_graph_canvas.dart';
import 'widgets/graph_tooltip.dart';

/// The "graph" half of [KnowledgeGraphPage] — the concept graph for one
/// already-known subject — without its picker grid, search box or back
/// button, so it can be embedded as a tab inside [SubjectDetailScreen].
///
/// Deliberately does **not** show [SubjectDetailPanel] on node tap: full
/// subject metadata (description, CLOs, ...) now lives in the detail
/// screen's own "Subject & resources" tab (see `SubjectResourcesPanel`),
/// so repeating it here on every node tap would just be a duplicate.
/// Tapping a node still selects/highlights it on the canvas.
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
                child: ConceptGraphCanvas(
                  key: ValueKey('subject-tab-graph-${widget.subjectCode}'),
                  knowledgeGraph: knowledgeGraph,
                  subjectId: widget.subjectCode,
                  selectedNodeId: _selectedNodeId,
                  isHighlighted: _neverHighlighted,
                  onNodeTap: _onNodeTap,
                  tooltipMessage: graphNodeTooltipMessage,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
