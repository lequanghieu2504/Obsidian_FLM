import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/graph_model.dart';
import 'subject_node_card.dart';

/// Draws one subject's concept graph (subject → topics → subtopics) as a
/// hand-rolled canvas: node positions come from a deterministic radial
/// layout computed once ([_layoutRadial]), edges are painted directly from
/// that same position map every frame, and nodes are plain positioned
/// widgets the person can drag freely with live-updating edges.
///
/// This intentionally does **not** use the `graphview` package that earlier
/// versions of this feature used. See `README.md` "Lần 5" for the full
/// story; in short: `graphview` 1.5.1's `GraphView.builder` resets and
/// re-runs its whole force-directed layout (400 iterations) on *every*
/// Flutter rebuild of the widget it belongs to — not just when the graph
/// itself changes — confirmed by reading its source (a staleness check
/// that would prevent this exists in the package but is commented out). So
/// any interaction that called `setState` anywhere on the page — tapping a
/// node, typing a search query, or (worst of all) dragging, which fires
/// `setState` on every pointer-move frame — retriggered a full, visibly
/// chaotic re-layout of the *entire* graph, not just whatever was touched.
/// Two attempts to work around that from the outside (gating when the
/// commit happens) still wallowed in library-internal behaviour that
/// wasn't fully knowable without a compiler to check assumptions against.
///
/// Computing a simple, deterministic layout ourselves once — no physics,
/// no iterations, so nothing to reshuffle — and drawing/dragging it with
/// plain Flutter widgets (`Stack` + `Positioned` + `CustomPaint`) that this
/// class fully owns removes that whole class of problem: a `setState` here
/// only ever repositions/repaints from data already in hand, so it's safe
/// to call on *every single drag frame*. That's what makes dragging (and
/// its edges) track the pointer live, not just settle on release the way
/// the `graphview`-based attempts had to.
class ConceptGraphCanvas extends StatefulWidget {
  const ConceptGraphCanvas({
    super.key,
    required this.knowledgeGraph,
    required this.subjectId,
    required this.selectedNodeId,
    required this.isHighlighted,
    required this.onNodeTap,
    required this.tooltipMessage,
  });

  final KnowledgeGraph knowledgeGraph;

  /// `knowledgeGraph`'s subject node id — passed explicitly rather than
  /// searched for, since the caller already knows it (it's the same id
  /// used to build this graph in the first place) and it's the one node
  /// every layout/centring calculation anchors on.
  final String subjectId;

  final String? selectedNodeId;
  final bool Function(GraphNodeData node) isHighlighted;
  final ValueChanged<String> onNodeTap;
  final String Function(GraphNodeData node) tooltipMessage;

  @override
  State<ConceptGraphCanvas> createState() => _ConceptGraphCanvasState();
}

class _ConceptGraphCanvasState extends State<ConceptGraphCanvas> {
  /// Size of the fixed virtual canvas nodes are placed on. Generous on
  /// purpose — `InteractiveViewer(constrained: false, ...)` needs the child
  /// to have a size up front, and this just needs to comfortably fit the
  /// radial layout below plus room to pan; it isn't a hard boundary on
  /// where a dragged node can end up (dragging just changes a node's entry
  /// in [_positions], nothing clips it to this box).
  static const double _canvasSize = 6000;
  static const Offset _canvasOrigin = Offset(_canvasSize / 2, _canvasSize / 2);

  static const double _topicRadius = 220;
  static const double _subtopicRadius = 130;

  /// How wide an arc (radians) a topic's subtopics fan out across, centred
  /// on that topic's own direction from the subject — so they spread away
  /// from the subject instead of circling all the way round it and
  /// overlapping neighbouring topics. ~109°.
  static const double _subtopicArcSpan = 1.9;

  final GlobalKey _viewportKey = GlobalKey();
  final TransformationController _transformController =
      TransformationController();

  /// Node id -> position in canvas space (origin at the subject, not at
  /// [_canvasOrigin] — that offset is added only when painting/positioning,
  /// see [_canvasOrigin]). Mutated directly by dragging.
  late Map<String, Offset> _positions;

  @override
  void initState() {
    super.initState();
    _positions = _layoutRadial();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerOnSubject());
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  /// Deterministic radial/tree layout: the subject sits at the centre, its
  /// topics are spread evenly around it, and each topic's own subtopics
  /// fan out on the arc facing away from the subject. No physics, no
  /// iterations — nothing here ever needs to "converge", so there's
  /// nothing to reshuffle on a rebuild the way `graphview`'s force-directed
  /// algorithm did.
  ///
  /// Not collision-aware: for a subject with many topics that each have
  /// many subtopics, neighbouring topics' subtopic fans could overlap.
  /// Fine for this app's actual data (curated by hand — a handful of
  /// topics, a few subtopics each; see `data/concepts/concepts.json`), and
  /// the person can always drag nodes apart by hand regardless.
  Map<String, Offset> _layoutRadial() {
    final positions = <String, Offset>{widget.subjectId: Offset.zero};

    final topicIds = [
      for (final e in widget.knowledgeGraph.edges)
        if (e.relation == RelationType.hasTopic &&
            e.sourceId == widget.subjectId)
          e.targetId,
    ];
    final topicCount = topicIds.length;

    for (var i = 0; i < topicCount; i++) {
      final topicId = topicIds[i];
      // Start at the top (-pi/2) and go clockwise, purely so the first
      // topic lands at 12 o'clock instead of 3 o'clock — no functional
      // difference either way.
      final topicAngle = (2 * math.pi * i / topicCount) - math.pi / 2;
      final topicPos = Offset(
        _topicRadius * math.cos(topicAngle),
        _topicRadius * math.sin(topicAngle),
      );
      positions[topicId] = topicPos;

      final subtopicIds = [
        for (final e in widget.knowledgeGraph.edges)
          if (e.relation == RelationType.hasSubtopic &&
              e.sourceId == topicId)
            e.targetId,
      ];
      final subtopicCount = subtopicIds.length;
      for (var j = 0; j < subtopicCount; j++) {
        final subAngle = subtopicCount == 1
            ? topicAngle
            : topicAngle -
                _subtopicArcSpan / 2 +
                _subtopicArcSpan * j / (subtopicCount - 1);
        positions[subtopicIds[j]] = topicPos +
            Offset(
              _subtopicRadius * math.cos(subAngle),
              _subtopicRadius * math.sin(subAngle),
            );
      }
    }
    return positions;
  }

  /// Moves the viewport so the subject node sits exactly in the middle of
  /// whatever space this canvas currently has on screen. Needs the
  /// viewport's actual rendered size, which isn't known until after the
  /// first layout pass — hence the post-frame callback rather than doing
  /// this inline in `initState`/`build`.
  void _centerOnSubject() {
    if (!mounted) return;
    final renderBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final subjectPos = _positions[widget.subjectId];
    if (subjectPos == null) return;

    final viewportSize = renderBox.size;
    final target = _canvasOrigin + subjectPos;
    _transformController.value = Matrix4.identity()
      ..translate(
        viewportSize.width / 2 - target.dx,
        viewportSize.height / 2 - target.dy,
      );
  }

  void _onNodeDrag(String id, Offset delta) {
    // A plain setState — safe to call on every pointer-move frame here,
    // unlike the `graphview`-based version this replaced (see this class's
    // doc comment): it only ever repositions/repaints from [_positions],
    // nothing here recomputes a layout from scratch.
    setState(() {
      _positions[id] = (_positions[id] ?? Offset.zero) + delta;
    });
  }

  @override
  Widget build(BuildContext context) {
    final graph = widget.knowledgeGraph;
    return SizedBox.expand(
      key: _viewportKey,
      child: InteractiveViewer(
        transformationController: _transformController,
        // The canvas is a fixed, generously-sized virtual surface the
        // person pans/zooms around in — not something that shrinks to fit
        // its content — which is what `constrained: false` plus an
        // explicitly-sized child (below) means in `InteractiveViewer`.
        constrained: false,
        boundaryMargin: const EdgeInsets.all(4000),
        minScale: 0.2,
        maxScale: 4,
        child: SizedBox(
          width: _canvasSize,
          height: _canvasSize,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _EdgePainter(
                    edges: graph.edges,
                    positions: _positions,
                    canvasOrigin: _canvasOrigin,
                  ),
                ),
              ),
              for (final node in graph.nodes)
                if (_positions[node.id] case final pos?)
                  Positioned(
                    left: _canvasOrigin.dx + pos.dx,
                    top: _canvasOrigin.dy + pos.dy,
                    // Centres the card on (left, top) regardless of the
                    // card's own rendered size (topic/subtopic pills vary
                    // in width with their label) — a plain `Positioned`
                    // would anchor its *top-left corner* there instead.
                    child: FractionalTranslation(
                      translation: const Offset(-0.5, -0.5),
                      child: Tooltip(
                        message: widget.tooltipMessage(node),
                        waitDuration: const Duration(milliseconds: 300),
                        child: GestureDetector(
                          onTap: () => widget.onNodeTap(node.id),
                          onPanUpdate: (details) =>
                              _onNodeDrag(node.id, details.delta),
                          child: SubjectNodeCard(
                            node: node,
                            isSelected: node.id == widget.selectedNodeId,
                            isHighlighted: widget.isHighlighted(node),
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints every edge as a straight line between its two nodes' *current*
/// positions, read fresh from [positions] on every paint — so edges track
/// a dragged node live, in the same frame, with no separate "catch up"
/// step (unlike the `graphview`-based version this replaced).
class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.edges,
    required this.positions,
    required this.canvasOrigin,
  });

  final List<GraphEdgeData> edges;
  final Map<String, Offset> positions;
  final Offset canvasOrigin;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.indigo.withOpacity(0.6)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (final edge in edges) {
      final from = positions[edge.sourceId];
      final to = positions[edge.targetId];
      if (from == null || to == null) continue;
      canvas.drawLine(canvasOrigin + from, canvasOrigin + to, paint);
    }
  }

  // Always true, deliberately: this graph is small (a handful of topics, a
  // few subtopics each) and repainting is cheap, so a finer-grained check
  // isn't worth the risk of getting it subtly wrong and having edges not
  // repaint when they should.
  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) => true;
}
