import 'package:flutter/material.dart';

/// Vertical drag handle for resizing a side pane — same look and feel as the
/// handle between the panes of the subject detail screen.
class PaneResizeHandle extends StatefulWidget {
  const PaneResizeHandle({
    super.key,
    required this.onDrag,
    this.onDragStart,
    this.onDragEnd,
    this.width = 8,
  });

  final double width;

  /// Horizontal pointer delta (logical pixels) for each move event.
  final ValueChanged<double> onDrag;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  @override
  State<PaneResizeHandle> createState() => _PaneResizeHandleState();
}

class _PaneResizeHandleState extends State<PaneResizeHandle> {
  bool _hover = false;
  bool _dragging = false;

  void _setDragging(bool value) {
    if (_dragging == value) return;
    setState(() => _dragging = value);
    value ? widget.onDragStart?.call() : widget.onDragEnd?.call();
  }

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
        onPointerDown: (_) => _setDragging(true),
        onPointerMove: (event) => widget.onDrag(event.delta.dx),
        onPointerUp: (_) => _setDragging(false),
        onPointerCancel: (_) => _setDragging(false),
        child: Tooltip(
          message: 'Kéo để đổi độ rộng',
          waitDuration: const Duration(milliseconds: 600),
          child: SizedBox(
            width: widget.width,
            child: Align(
              child: AnimatedContainer(
                duration: _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                width: active ? 2 : 1,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: active
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
