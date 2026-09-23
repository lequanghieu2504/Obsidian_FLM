import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

/// One tab of the "Detail" side of the screen: a title shown on the [Tab]
/// and the information widget shown for it. There is a single
/// [SubjectChatPanel] for the whole page (built once in
/// [_SubjectDetailScreenState.build], next to the tab content rather than
/// inside it) — every tab talks to the same conversation, so switching tabs
/// never swaps out the chat or resets what's mid-draft in it. (The
/// Knowledge Graph tab shares that one chat panel too — it isn't built from
/// [SubjectRecord] data the way these are, so it doesn't go through
/// [_buildDetailTabs], but it's appended right after them in the tab bar.)
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
///
/// Every panel is wrapped in a [SelectionArea] so all of its text — field
/// values, table cells, everything — can be selected and copied like plain
/// text, not just glanced at. (The chat panel doesn't need this: its
/// messages already render through `SimpleMarkdown`, which is independently
/// selectable.)
List<_DetailTab> _buildDetailTabs(SubjectDetailController controller) {
  final tabs = <_DetailTab>[
    _DetailTab(
      title: 'Subject & resources',
      content: SelectionArea(
        child: SubjectOverviewPanel(controller: controller),
      ),
    ),
  ];
  final syllabus = controller.syllabus;
  if (syllabus != null) {
    if (syllabus.learningOutcomes.isNotEmpty) {
      tabs.add(
        _DetailTab(
          title: 'Learning outcomes',
          content: SelectionArea(
            child: LearningOutcomesPanel(controller: controller),
          ),
        ),
      );
    }
    if (otherSyllabusMetadata(syllabus).isNotEmpty) {
      tabs.add(
        _DetailTab(
          title: 'Other syllabus fields',
          content: SelectionArea(
            child: OtherSyllabusFieldsPanel(controller: controller),
          ),
        ),
      );
    }
    for (final section in syllabus.sections) {
      if (section.rows.isEmpty) continue;
      tabs.add(
        _DetailTab(
          title: section.heading,
          content: SelectionArea(child: SyllabusTablePanel(section: section)),
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

  /// Identity for the page's one [SubjectChatPanel], reused across rebuilds.
  /// Wide layouts put it inside a [_ResizableSplit]; narrow layouts stack it
  /// in a plain [Column] — completely different ancestor widgets, so a
  /// [ValueKey] wouldn't survive the switch (Flutter only matches those
  /// within the same parent's children list). A [GlobalKey] is matched by
  /// identity anywhere in the tree, so resizing the window keeps the chat
  /// panel's own state (typed draft, scroll position) alive instead of
  /// recreating it. Replaced with a fresh key in [_initialize] whenever a
  /// new subject (a new [SubjectDetailController]) loads.
  GlobalKey _chatKey = GlobalKey();

  /// Whether the (single, page-wide) chat panel is currently minimized.
  /// Collapsing swaps it for a small [_CollapsedChatButton]; the information
  /// side takes the freed-up space instead of it just sitting there blank.
  /// Starts collapsed — opening a subject should land on its content, not
  /// its chat; a person who wants the chat taps [_CollapsedChatButton] to
  /// bring it up themselves.
  bool _chatCollapsed = true;

  /// The resizable split's dragged width, persisted here (rather than left
  /// inside [_ResizableSplit]'s own state) so collapsing and then
  /// re-expanding the chat — which unmounts/remounts the split — restores
  /// the same width instead of resetting to the default fraction.
  double? _chatSplitWidth;

  void _toggleChatCollapsed() {
    setState(() => _chatCollapsed = !_chatCollapsed);
  }

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
      _chatKey = GlobalKey();
      _chatCollapsed = true;
      _chatSplitWidth = null;
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

  /// Lays out the page's one chat panel next to (wide) or under (narrow)
  /// [information] — the latter now being the whole tab-switching area, not
  /// a single tab's content, since the chat itself no longer lives inside
  /// any individual tab.
  Widget _tabBody({
    required Widget information,
    required Widget chat,
    required bool wide,
  }) {
    if (wide) {
      if (_chatCollapsed) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: information),
              const SizedBox(width: 12),
              _CollapsedChatButton(onExpand: _toggleChatCollapsed),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(24),
        child: _ResizableSplit(
          left: information,
          right: chat,
          minWidth: _minPaneWidth,
          handleWidth: _handleWidth,
          initialWidth: _chatSplitWidth,
          onWidthChanged: (width) => _chatSplitWidth = width,
        ),
      );
    }
    if (_chatCollapsed) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(child: information),
            const SizedBox(height: 12),
            _CollapsedChatButton(onExpand: _toggleChatCollapsed),
          ],
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
                  // Only the tab content switches here — there's a single
                  // chat panel for the whole page (below), so every tab,
                  // Knowledge Graph included, talks to the same
                  // conversation instead of each getting its own.
                  final tabBarView = TabBarView(
                    children: [
                      for (final tab in detailTabs) tab.content,
                      knowledgeGraph,
                    ],
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
                              child: _tabBody(
                                information: tabBarView,
                                chat: SubjectChatPanel(
                                  key: _chatKey,
                                  controller: controller,
                                  onCollapse: _toggleChatCollapsed,
                                ),
                                wide: wide,
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
    this.initialWidth,
    this.onWidthChanged,
  });

  final Widget left;
  final Widget right;
  final double minWidth;
  final double handleWidth;
  final double initialFraction;

  /// A previously-dragged width to start from instead of [initialFraction]
  /// (e.g. restored after the chat panel was minimized and re-expanded,
  /// which unmounts and remounts this widget). Null uses [initialFraction]
  /// as before.
  final double? initialWidth;

  /// Called with the new left-pane width whenever a drag settles it, so a
  /// caller that wants the width to survive this widget being unmounted
  /// (see [initialWidth]) can hold onto it.
  final ValueChanged<double>? onWidthChanged;

  @override
  State<_ResizableSplit> createState() => _ResizableSplitState();
}

class _ResizableSplitState extends State<_ResizableSplit> {
  late double? _leftWidth = widget.initialWidth;

  // Raw pointer-move events can fire many times per rendered frame (high
  // poll-rate mice, trackpads). Calling setState() straight from onDrag()
  // forced a full layout of both panes (including the chat panel) on every
  // single event, which made the handle feel heavy/laggy while dragging.
  // Instead we accumulate the delta and flush it at most once per frame.
  double _pendingDelta = 0;
  bool _frameScheduled = false;
  double _minWidthForFrame = 0;
  double _maxWidthForFrame = 0;

  void _queueDrag(double dx) {
    _pendingDelta += dx;
    if (_frameScheduled) return;
    _frameScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (!mounted || _pendingDelta == 0) {
        _pendingDelta = 0;
        return;
      }
      setState(() {
        final current = _leftWidth ?? _minWidthForFrame;
        _leftWidth = (current + _pendingDelta).clamp(
          _minWidthForFrame,
          _maxWidthForFrame,
        );
        _pendingDelta = 0;
      });
      widget.onWidthChanged?.call(_leftWidth!);
    });
  }

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
        _minWidthForFrame = widget.minWidth;
        _maxWidthForFrame = maxLeftWidth;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: leftWidth,
              child: RepaintBoundary(child: widget.left),
            ),
            _PaneResizeHandle(
              width: widget.handleWidth,
              onDrag: _queueDrag,
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

/// What a tab's chat pane becomes while minimized: a single small icon
/// button (instead of the full [SubjectChatPanel] or a wide rail) that
/// hands essentially all the freed-up space back to the information panel
/// next to it, with one affordance — tap it — to bring the chat back.
class _CollapsedChatButton extends StatelessWidget {
  const _CollapsedChatButton({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Expand chat',
      child: IconButton.filledTonal(
        onPressed: onExpand,
        icon: const Icon(Icons.chat_bubble_outline),
      ),
    );
  }
}
