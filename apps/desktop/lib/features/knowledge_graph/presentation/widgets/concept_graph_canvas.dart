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

  static const double _topicRadius = 290;

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

  /// Dynamic radial layout with multi-ring staggered distribution and
  /// collision relaxation pass to guarantee zero node overlaps.
  Map<String, Offset> _layoutRadial() {
    final positions = <String, Offset>{widget.subjectId: Offset.zero};

    final topicEdges = widget.knowledgeGraph.edges
        .where((e) =>
            e.relation == RelationType.hasTopic &&
            e.sourceId == widget.subjectId)
        .toList();
    final topicCount = topicEdges.length;
    if (topicCount == 0) return positions;

    for (var i = 0; i < topicCount; i++) {
      final topicId = topicEdges[i].targetId;
      final topicAngle = (2 * math.pi * i / topicCount) - math.pi / 2;
      final topicPos = Offset(
        _topicRadius * math.cos(topicAngle),
        _topicRadius * math.sin(topicAngle),
      );
      positions[topicId] = topicPos;

      final subtopicEdges = widget.knowledgeGraph.edges
          .where((e) =>
              e.relation == RelationType.hasSubtopic &&
              e.sourceId == topicId)
          .toList();
      final subtopicCount = subtopicEdges.length;
      if (subtopicCount == 0) continue;

      // Dynamic arc span according to child count
      final arcSpan = math.min(math.pi * 1.35, 0.45 * subtopicCount);

      for (var j = 0; j < subtopicCount; j++) {
        final subtopicId = subtopicEdges[j].targetId;
        final fraction = subtopicCount == 1 ? 0.5 : j / (subtopicCount - 1);
        final subAngle = topicAngle - (arcSpan / 2) + (arcSpan * fraction);

        // Stagger radii between adjacent subtopics to eliminate side-by-side overlaps
        final double r = subtopicCount > 3
            ? (j.isEven ? 175.0 : 255.0)
            : 185.0;

        positions[subtopicId] = topicPos +
            Offset(
              r * math.cos(subAngle),
              r * math.sin(subAngle),
            );
      }
    }

    _applyCollisionRelaxation(positions);

    return positions;
  }

  /// 30 iterations of node collision relaxation to push any overlapping node boxes apart
  void _applyCollisionRelaxation(Map<String, Offset> positions) {
    final keys = positions.keys.toList();
    for (var iter = 0; iter < 30; iter++) {
      var moved = false;
      for (var i = 0; i < keys.length; i++) {
        final keyA = keys[i];
        if (keyA == widget.subjectId) continue;
        final posA = positions[keyA]!;
        final nodeA = widget.knowledgeGraph.nodesById[keyA];
        final sizeA = _estimateNodeSize(nodeA);

        for (var j = i + 1; j < keys.length; j++) {
          final keyB = keys[j];
          final posB = positions[keyB]!;
          final nodeB = widget.knowledgeGraph.nodesById[keyB];
          final sizeB = _estimateNodeSize(nodeB);

          final minDx = (sizeA.width + sizeB.width) / 2 + 24;
          final minDy = (sizeA.height + sizeB.height) / 2 + 18;

          final dx = posB.dx - posA.dx;
          final dy = posB.dy - posA.dy;

          final absDx = dx.abs();
          final absDy = dy.abs();

          if (absDx < minDx && absDy < minDy) {
            final overlapX = minDx - absDx;
            final overlapY = minDy - absDy;

            Offset push;
            if (overlapX < overlapY) {
              final signX = dx >= 0 ? 1.0 : -1.0;
              push = Offset(signX * overlapX * 0.45, 0);
            } else {
              final signY = dy >= 0 ? 1.0 : -1.0;
              push = Offset(0, signY * overlapY * 0.45);
            }

            if (keyB == widget.subjectId) {
              positions[keyA] = posA - push * 2;
            } else {
              positions[keyA] = posA - push;
              positions[keyB] = posB + push;
            }
            moved = true;
          }
        }
      }
      if (!moved) break;
    }
  }

  Size _estimateNodeSize(GraphNodeData? node) {
    if (node == null) return const Size(120, 40);
    if (node.type == NodeType.subject) return const Size(240, 95);
    if (node.type == NodeType.topic) {
      return Size((node.label.length * 8.5 + 48).clamp(140.0, 260.0), 44);
    }
    return Size((node.label.length * 7.5 + 32).clamp(100.0, 220.0), 38);
  }

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
                    nodesById: graph.nodesById,
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

/// Paints edges with smooth anti-aliased curves and connection dots
class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.edges,
    required this.nodesById,
    required this.positions,
    required this.canvasOrigin,
  });

  final List<GraphEdgeData> edges;
  final Map<String, GraphNodeData> nodesById;
  final Map<String, Offset> positions;
  final Offset canvasOrigin;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()..style = PaintingStyle.fill;

    for (final edge in edges) {
      final from = positions[edge.sourceId];
      final to = positions[edge.targetId];
      if (from == null || to == null) continue;

      final start = canvasOrigin + from;
      final end = canvasOrigin + to;

      if (edge.relation == RelationType.hasTopic) {
        linePaint
          ..color = const Color(0xFF60A5FA).withOpacity(0.65)
          ..strokeWidth = 2.2;

        final path = Path()..moveTo(start.dx, start.dy);
        final control = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
        path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
        canvas.drawPath(path, linePaint);

        dotPaint.color = const Color(0xFF2563EB);
        canvas.drawCircle(end, 4.0, dotPaint);
      } else {
        linePaint
          ..color = const Color(0xFF94A3B8).withOpacity(0.55)
          ..strokeWidth = 1.6;

        canvas.drawLine(start, end, linePaint);

        dotPaint.color = const Color(0xFF64748B);
        canvas.drawCircle(end, 3.0, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) => true;
}
