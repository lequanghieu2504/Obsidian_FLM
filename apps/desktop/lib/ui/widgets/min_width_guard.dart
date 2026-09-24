import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Never lays [child] out narrower than [minWidth]: when the available width
/// is smaller (e.g. a side panel was dragged wide), the child keeps
/// [minWidth] and the area scrolls horizontally instead of throwing
/// "RenderFlex overflowed" errors / squashing its content.
///
/// The widget tree is identical whether or not the guard is active, so
/// crossing the threshold while dragging never recreates [child]'s state.
class MinWidthGuard extends StatefulWidget {
  const MinWidthGuard({super.key, required this.minWidth, required this.child});

  final double minWidth;
  final Widget child;

  @override
  State<MinWidthGuard> createState() => _MinWidthGuardState();
}

class _MinWidthGuardState extends State<MinWidthGuard> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(widget.minWidth, constraints.maxWidth);
        final squeezed = constraints.maxWidth < widget.minWidth;
        return Scrollbar(
          controller: _scroll,
          thumbVisibility: squeezed,
          notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: squeezed
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: width,
              height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
