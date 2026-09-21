import 'dart:async';

import 'package:flutter/material.dart';

import '../data/concept_repository.dart';
import '../data/subject_repository.dart';
import '../domain/concept_data.dart';
import '../domain/graph_model.dart';
import '../domain/knowledge_graph_builder.dart';
import '../domain/subject_record.dart';
import 'widgets/concept_graph_canvas.dart';
import 'widgets/graph_tooltip.dart';
import 'widgets/graph_toolbar.dart';
import 'widgets/subject_detail_panel.dart';
import 'widgets/subject_picker_grid.dart';

/// Two screens in one page, switched by whether a subject is focused:
///
/// 1. **Picker** ([_focusedSubjectCode] is null) — every subject as a
///    searchable grid. This is what the user sees first.
/// 2. **Graph** ([_focusedSubjectCode] set) — that one subject's concept
///    graph: the subject in the centre, one node per curated topic (e.g.
///    "Mobile App Development"), and one node per subtopic nested under
///    each topic (e.g. "Flutter", "UI/UX") — a 3-tier tree, not a
///    cross-subject graph, drawn by [ConceptGraphCanvas]. See `README.md`
///    §0 for why the earlier prerequisite-based version was dropped,
///    "Lần 3" for why the topic data is curated ahead of time
///    (`data/concepts/concepts.json`) rather than matched from a runtime
///    keyword dictionary, and "Lần 5" for why the graph is drawn with a
///    hand-rolled canvas instead of the `graphview` package this feature
///    used through "Lần 4".
class KnowledgeGraphPage extends StatefulWidget {
  const KnowledgeGraphPage({
    super.key,
    this.repository = const SubjectRepository(),
    this.conceptRepository = const ConceptRepository(),
  });

  final SubjectRepository repository;
  final ConceptRepository conceptRepository;

  @override
  State<KnowledgeGraphPage> createState() => _KnowledgeGraphPageState();
}

class _KnowledgeGraphPageState extends State<KnowledgeGraphPage> {
  late final Future<void> _loadFuture;

  List<SubjectRecord> _subjects = const [];
  Map<String, SubjectRecord> _subjectsByCode = const {};
  Map<String, SubjectConcepts> _conceptsByCode = const {};

  String _query = '';
  String? _selectedNodeId;
  Timer? _searchDebounce;

  /// The subject the user picked, or null while the picker grid is showing.
  String? _focusedSubjectCode;

  KnowledgeGraph? _knowledgeGraph;

  @override
  void initState() {
    super.initState();
    _loadFuture = Future.wait([
      widget.repository.loadAll(),
      widget.conceptRepository.loadAll(),
    ]).then((results) {
      if (!mounted) return;
      setState(() {
        _subjects = results[0] as List<SubjectRecord>;
        _subjectsByCode = {for (final s in _subjects) s.subjectCode: s};
        _conceptsByCode = results[1] as Map<String, SubjectConcepts>;
      });
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _rebuildFocusedGraphObjects() {
    final subjectCode = _focusedSubjectCode;
    final subject = subjectCode == null ? null : _subjectsByCode[subjectCode];
    if (subject == null) return;

    final concepts = _conceptsByCode[subjectCode] ?? SubjectConcepts.empty;
    _knowledgeGraph = KnowledgeGraphBuilder.buildConceptGraph(subject, concepts);
  }

  void _onSubjectSelected(String subjectCode) {
    setState(() {
      _focusedSubjectCode = subjectCode;
      _selectedNodeId = subjectCode;
      _query = '';
      _rebuildFocusedGraphObjects();
    });
  }

  void _onBackToPicker() {
    setState(() {
      _focusedSubjectCode = null;
      _selectedNodeId = null;
      _knowledgeGraph = null;
      _query = '';
    });
  }

  void _onQueryChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _query = value.trim().toLowerCase());
    });
  }

  void _onNodeTap(String id) {
    setState(() => _selectedNodeId = _selectedNodeId == id ? null : id);
  }

  bool _nodeMatchesQuery(GraphNodeData node) {
    if (_query.isEmpty) return false;
    if (node.label.toLowerCase().contains(_query)) return true;
    final name = node.attributes['name']?.toString().toLowerCase() ?? '';
    return name.contains(_query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
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
                  'Không tải được dữ liệu môn học:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (_subjects.isEmpty) {
            return const Center(
              child: Text(
                'Không tìm thấy file nào trong data/subject/.\n'
                'Hãy chắc chắn thư mục apps/desktop/data/subject chứa các '
                'file subject *.json và đã được khai báo trong pubspec.yaml.',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (_focusedSubjectCode == null) {
            return Column(
              children: [
                GraphToolbar(
                  focusedSubjectCode: null,
                  onQueryChanged: _onQueryChanged,
                  subjectCount: _subjects.length,
                ),
                Expanded(
                  child: SubjectPickerGrid(
                    subjects: _subjects,
                    query: _query,
                    onSelect: _onSubjectSelected,
                  ),
                ),
              ],
            );
          }

          final knowledgeGraph = _knowledgeGraph;
          if (knowledgeGraph == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final selectedNode = _selectedNodeId == null
              ? null
              : knowledgeGraph.nodesById[_selectedNodeId];

          return Column(
            children: [
              GraphToolbar(
                focusedSubjectCode: _focusedSubjectCode,
                onBack: _onBackToPicker,
                onQueryChanged: _onQueryChanged,
                subjectCount: _subjects.length,
                nodeCount: knowledgeGraph.nodes.length,
                edgeCount: knowledgeGraph.edges.length,
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ColoredBox(
                        color: Theme.of(context).colorScheme.surface,
                        child: Column(
                          children: [
                            if (knowledgeGraph.edges.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'Chưa có dữ liệu chủ đề được biên soạn cho '
                                  'môn này — chỉ có node của chính môn học.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            Expanded(
                              child: ConceptGraphCanvas(
                                // New instance (and so a fresh layout +
                                // re-centre) whenever the focused subject
                                // changes; unrelated rebuilds of this page
                                // (search, node selection) reuse the same
                                // key and so the same State — dragged
                                // positions aren't lost by, say, typing in
                                // the search box.
                                key: ValueKey('graph-$_focusedSubjectCode'),
                                knowledgeGraph: knowledgeGraph,
                                subjectId: _focusedSubjectCode!,
                                selectedNodeId: _selectedNodeId,
                                isHighlighted: _nodeMatchesQuery,
                                onNodeTap: _onNodeTap,
                                tooltipMessage: graphNodeTooltipMessage,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (selectedNode != null)
                      SizedBox(
                        width: 380,
                        child: SubjectDetailPanel(
                          node: selectedNode,
                          // A subject node's own id *is* the subject code;
                          // a topic/subtopic node carries it in
                          // `attributes['subjectCode']` instead (set by
                          // `KnowledgeGraphBuilder`) — falling back to
                          // `selectedNode.id` when that's absent covers
                          // both, so the panel gets the full subject
                          // record (description + every CLO) regardless of
                          // which tier of node was clicked, not just for
                          // the subject node.
                          subject: _subjectsByCode[
                              selectedNode.attributes['subjectCode']
                                      ?.toString() ??
                                  selectedNode.id],
                          knowledgeGraph: knowledgeGraph,
                          onClose: () => setState(() => _selectedNodeId = null),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
