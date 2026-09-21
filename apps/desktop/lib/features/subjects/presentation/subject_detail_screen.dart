import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../models/subject.dart';
import '../../assistant/infrastructure/gemini_llm_client.dart';
import '../../assistant/infrastructure/local_chat_attachment_processor.dart';
import '../../knowledge_graph/presentation/subject_knowledge_graph_tab.dart';
import '../application/subject_detail_controller.dart';
import '../data/local_subject_workspace_repository.dart';
import '../domain/subject_workspace.dart';
import 'subject_chat_panel.dart';
import 'subject_resources_panel.dart';

typedef SubjectControllerFactory =
    Future<SubjectDetailController> Function(SubjectWorkspace workspace);

Future<SubjectDetailController> createSubjectController(
  SubjectWorkspace workspace,
) async {
  final support = await getApplicationSupportDirectory();
  const keys = SecureGeminiKeyStore();
  return SubjectDetailController(
    workspace: workspace,
    repository: LocalSubjectWorkspaceRepository(
      Directory(p.join(support.path, 'user_data')),
    ),
    llm: GeminiLlmClient(keys: keys),
    keys: keys,
    attachmentProcessor: const LocalChatAttachmentProcessor(),
  );
}

class SubjectDetailScreen extends StatefulWidget {
  const SubjectDetailScreen({
    super.key,
    required this.curriculumCode,
    required this.subject,
    this.controllerFactory = createSubjectController,
  });
  final String curriculumCode;
  final Subject subject;
  final SubjectControllerFactory controllerFactory;

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

/// One tab of the "Detail" side of the screen (everything except the
/// Knowledge Graph tab, which has no paired chat): a title shown on the
/// [Tab] and the information widget shown next to a [SubjectChatPanel] in
/// that tab's body.
class _DetailTab {
  const _DetailTab({required this.title, required this.content});
  final String title;
  final Widget content;
}

/// Builds the ordered list of Detail-side tabs from whatever the controller
/// has loaded so far: the subject overview/resources tab always exists;
/// learning outcomes, other syllabus fields, and each syllabus table
/// (reference materials, session plan, assessments, ...) each get their own
/// tab once the full syllabus has loaded and only when they have content —
/// so the tab bar never shows an empty section, and no tab is ever named
/// after a raw "Table N" placeholder (`SubjectRecord` already resolves
/// those to a real name before this runs).
List<_DetailTab> _buildDetailTabs(SubjectDetailController controller) {
  final tabs = <_DetailTab>[
    _DetailTab(
      title: 'Subject & resources',
      content: SubjectOverviewPanel(controller: controller),
    ),
  ];
  final syllabus = controller.syllabus;
  if (syllabus != null) {
    if (syllabus.learningOutcomes.isNotEmpty) {
      tabs.add(
        _DetailTab(
          title: 'Learning outcomes',
          content: LearningOutcomesPanel(controller: controller),
        ),
      );
    }
    if (otherSyllabusMetadata(syllabus).isNotEmpty) {
      tabs.add(
        _DetailTab(
          title: 'Other syllabus fields',
          content: OtherSyllabusFieldsPanel(controller: controller),
        ),
      );
    }
    for (final section in syllabus.sections) {
      if (section.rows.isEmpty) continue;
      tabs.add(
        _DetailTab(
          title: section.heading,
          content: SyllabusTablePanel(section: section),
        ),
      );
    }
  }
  return tabs;
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  SubjectDetailController? _controller;
  bool _failed = false;
  int _generation = 0;

  /// One stable [GlobalKey] per Detail-side tab index, created lazily and
  /// reused across rebuilds. Wide layouts put a tab's chat panel inside a
  /// [_ResizableSplit]; narrow layouts stack it in a plain [Column] —
  /// completely different ancestor widgets, so a [ValueKey] wouldn't survive
  /// the switch (Flutter only matches those within the same parent's
  /// children list). A [GlobalKey] is matched by identity anywhere in the
  /// tree, so resizing the window keeps each tab's [SubjectChatPanel] state
  /// (typed draft, scroll position) alive instead of recreating it.
  final Map<int, GlobalKey> _chatKeys = {};

  GlobalKey _chatKeyFor(int index) =>
      _chatKeys.putIfAbsent(index, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(SubjectDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.curriculumCode != widget.curriculumCode ||
        oldWidget.subject != widget.subject) {
      _controller?.dispose();
      _controller = null;
      _initialize();
    }
  }

  Future<void> _initialize() async {
    final generation = ++_generation;
    setState(() => _failed = false);
    try {
      final controller = await widget.controllerFactory(
        SubjectWorkspace(
          curriculumCode: widget.curriculumCode,
          subject: widget.subject,
        ),
      );
      if (!mounted || generation != _generation) {
        controller.dispose();
        return;
      }
      _chatKeys.clear();
      setState(() => _controller = controller);
      await controller.load();
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _generation++;
    _controller?.dispose();
    super.dispose();
  }

  static const double _minPaneWidth = 340;
  static const double _handleWidth = 20;

 
  Widget _tabBody({
    required Widget information,
    required Widget chat,
    required bool wide,
  }) {
    if (wide) {
      return Padding(
        padding: const EdgeInsets.all(24),
       
        child: _ResizableSplit(
          left: information,
          right: chat,
          minWidth: _minPaneWidth,
          handleWidth: _handleWidth,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(flex: 3, child: information),
          const SizedBox(height: 12),
          Expanded(flex: 2, child: chat),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.subject.code} · Subject Detail')),
      body: SafeArea(
        child: _failed
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Cannot open local user storage. Check folder permissions.',
                    ),
                    TextButton(
                      onPressed: _initialize,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : controller == null
            ? const Center(child: CircularProgressIndicator())
            : ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final detailTabs = _buildDetailTabs(controller);
                  final knowledgeGraph = SubjectKnowledgeGraphTab(
                    subjectCode: widget.subject.code,
                  );
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 960;
                   
                      return DefaultTabController(
                        length: detailTabs.length + 1,
                        child: Column(
                          children: [
                            TabBar(
                              isScrollable: true,
                              tabAlignment: TabAlignment.start,
                              tabs: [
                                for (final tab in detailTabs)
                                  Tab(text: tab.title),
                                const Tab(text: 'Knowledge Graph'),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  for (
                                    var i = 0;
                                    i < detailTabs.length;
                                    i++
                                  )
                                    _tabBody(
                                      information: detailTabs[i].content,
                                      chat: SubjectChatPanel(
                                        key: _chatKeyFor(i),
                                        controller: controller,
                                      ),
                                      wide: wide,
                                    ),
                                  knowledgeGraph,
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _ResizableSplit extends StatefulWidget {
  const _ResizableSplit({
    required this.left,
    required this.right,
    required this.minWidth,
    required this.handleWidth,
    this.initialFraction = 0.58,
  });

  final Widget left;
  final Widget right;
  final double minWidth;
  final double handleWidth;
  final double initialFraction;

  @override
  State<_ResizableSplit> createState() => _ResizableSplitState();
}

class _ResizableSplitState extends State<_ResizableSplit> {
  double? _leftWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - widget.handleWidth;
        final maxLeftWidth = (available - widget.minWidth).clamp(
          widget.minWidth,
          double.infinity,
        );
        final leftWidth =
            (_leftWidth ?? available * widget.initialFraction).clamp(
              widget.minWidth,
              maxLeftWidth,
            );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: leftWidth,
              child: RepaintBoundary(child: widget.left),
            ),
            _PaneResizeHandle(
              width: widget.handleWidth,
              onDrag: (dx) => setState(() {
                _leftWidth = (leftWidth + dx).clamp(
                  widget.minWidth,
                  maxLeftWidth,
                );
              }),
            ),
            Expanded(child: RepaintBoundary(child: widget.right)),
          ],
        );
      },
    );
  }
}

class _PaneResizeHandle extends StatefulWidget {
  const _PaneResizeHandle({required this.width, required this.onDrag});
  final double width;
  final ValueChanged<double> onDrag;

  @override
  State<_PaneResizeHandle> createState() => _PaneResizeHandleState();
}

class _PaneResizeHandleState extends State<_PaneResizeHandle> {
  bool _hover = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = _hover || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => setState(() => _dragging = true),
        onPointerMove: (event) => widget.onDrag(event.delta.dx),
        onPointerUp: (_) => setState(() => _dragging = false),
        onPointerCancel: (_) => setState(() => _dragging = false),
        child: SizedBox(
          width: widget.width,
          child: Align(
            child: AnimatedContainer(
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: active ? 6 : 4,
              height: double.infinity,
              decoration: BoxDecoration(
                color: active
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
