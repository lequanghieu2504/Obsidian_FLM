import 'dart:io';

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

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  SubjectDetailController? _controller;
  bool _failed = false;
  int _generation = 0;
  final _chatKey = GlobalKey();

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

  Widget _wideLayout(
    Widget information,
    Widget chat,
    Widget knowledgeGraph,
  ) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Detail'),
              Tab(text: 'Knowledge Graph'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  // A dedicated widget that owns its own drag state, so
                  // resizing never re-runs this screen's build() — the
                  // [information]/[chat] instances below stay `identical`
                  // across every drag frame and Flutter skips rebuilding
                  // their (heavy) subtrees entirely.
                  child: _ResizableSplit(
                    left: information,
                    right: chat,
                    minWidth: _minPaneWidth,
                    handleWidth: _handleWidth,
                  ),
                ),
                knowledgeGraph,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _narrowLayout(Widget information, Widget chat, Widget knowledgeGraph) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Subject & resources'),
              Tab(text: 'Gemini Assistant'),
              Tab(text: 'Knowledge Graph'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                Padding(padding: const EdgeInsets.all(16), child: information),
                Padding(padding: const EdgeInsets.all(16), child: chat),
                knowledgeGraph,
              ],
            ),
          ),
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
                builder: (context, _) => LayoutBuilder(
                  builder: (context, constraints) {
                    final information = SubjectResourcesPanel(
                      controller: controller,
                    );
                    final chat = SubjectChatPanel(
                      key: _chatKey,
                      controller: controller,
                    );
                    final knowledgeGraph = SubjectKnowledgeGraphTab(
                      subjectCode: widget.subject.code,
                    );
                    return constraints.maxWidth >= 960
                        ? _wideLayout(information, chat, knowledgeGraph)
                        : _narrowLayout(information, chat, knowledgeGraph);
                  },
                ),
              ),
      ),
    );
  }
}

/// A horizontally resizable two-pane split (left pane fixed-width, right
/// pane fills the rest) that owns its own drag state locally.
///
/// This is deliberately its own [StatefulWidget] rather than inline layout
/// in the parent screen: dragging the handle calls `setState` on *this*
/// widget only, so it is the only thing that rebuilds on every drag frame.
/// [left] and [right] are built once by the parent and passed down as
/// already-constructed widget instances — since this widget's own rebuild
/// never touches them, they stay `identical` across drag frames and
/// Flutter's `Element.updateChild` skips rebuilding their subtrees
/// entirely (see `identical(oldWidget, newWidget)` in the framework).
/// Previously the parent screen's `setState` drove the resize, which
/// recreated `SubjectResourcesPanel`/`SubjectChatPanel` on every pixel of
/// drag and made the handle feel laggy.
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
  /// Null until the user drags at least once, in which case [build] falls
  /// back to [_ResizableSplit.initialFraction] of the available width.
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
            SizedBox(width: leftWidth, child: widget.left),
            _PaneResizeHandle(
              width: widget.handleWidth,
              onDrag: (dx) => setState(() {
                _leftWidth = (leftWidth + dx).clamp(
                  widget.minWidth,
                  maxLeftWidth,
                );
              }),
            ),
            Expanded(child: widget.right),
          ],
        );
      },
    );
  }
}

/// Draggable divider between two panes — the "chat panel width the user
/// can customize" this screen didn't have before (it was a fixed 3:2 flex
/// split). Pure presentation; drag state lives in [_ResizableSplitState].
class _PaneResizeHandle extends StatefulWidget {
  const _PaneResizeHandle({required this.width, required this.onDrag});
  final double width;
  final ValueChanged<double> onDrag;

  @override
  State<_PaneResizeHandle> createState() => _PaneResizeHandleState();
}

class _PaneResizeHandleState extends State<_PaneResizeHandle> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) => widget.onDrag(details.delta.dx),
        child: SizedBox(
          width: widget.width,
          child: Align(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: 4,
              height: double.infinity,
              decoration: BoxDecoration(
                color: _hover
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
