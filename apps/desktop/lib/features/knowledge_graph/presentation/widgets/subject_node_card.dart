import 'package:flutter/material.dart';

import '../../domain/graph_model.dart';

/// The widget rendered for one graph node. Kept intentionally small and
/// fixed-size: GraphView measures whatever this returns and lays every
/// node out around that size, so a node that grows unpredictably (e.g. an
/// unbounded multi-line description) would fight the layout algorithm.
class SubjectNodeCard extends StatelessWidget {
  const SubjectNodeCard({
    super.key,
    required this.node,
    required this.isSelected,
    required this.isHighlighted,
  });

  final GraphNodeData node;
  final bool isSelected;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    switch (node.type) {
      case NodeType.topic:
        return _buildPill(context, big: true);
      case NodeType.subtopic:
        return _buildPill(context, big: false);
      case NodeType.subject:
      default:
        return _buildSubject(context);
    }
  }

  Widget _buildSubject(BuildContext context) {
    final theme = Theme.of(context);
    final credits = (node.attributes['credits'] ?? '').toString();
    final name = (node.attributes['name'] ?? '').toString();

    final Color background = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.primaryContainer;
    final Color foreground = isSelected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onPrimaryContainer;

    return Container(
      width: 168,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlighted
              ? Colors.amber
              : (isSelected ? theme.colorScheme.primary : Colors.transparent),
          width: isHighlighted ? 3 : 2,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  node.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (credits.isNotEmpty && credits != '0')
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: foreground.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$credits tc',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
            ],
          ),
          if (name.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              name,
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  /// A topic or subtopic from the subject's curated concept data (e.g.
  /// "Mobile App Development" as a topic, "Flutter"/"UI/UX" as its
  /// subtopics) — a pill so many of them fit comfortably around the subject
  /// card without dominating the view. Topics use the app's secondary
  /// colour and a slightly larger/bolder style than subtopics, which use
  /// the tertiary colour, so the two tiers stay visually distinct even
  /// before reading the detail panel.
  Widget _buildPill(BuildContext context, {required bool big}) {
    final theme = Theme.of(context);
    final Color background = big
        ? (isSelected
            ? theme.colorScheme.secondary
            : theme.colorScheme.secondaryContainer)
        : (isSelected
            ? theme.colorScheme.tertiary
            : theme.colorScheme.tertiaryContainer);
    final Color foreground = big
        ? (isSelected
            ? theme.colorScheme.onSecondary
            : theme.colorScheme.onSecondaryContainer)
        : (isSelected
            ? theme.colorScheme.onTertiary
            : theme.colorScheme.onTertiaryContainer);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: big ? 12 : 10,
        vertical: big ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: isHighlighted
            ? Border.all(color: Colors.amber, width: 3)
            : Border.all(color: Colors.transparent, width: 3),
      ),
      child: Text(
        node.label,
        style: (big ? theme.textTheme.labelLarge : theme.textTheme.labelMedium)
            ?.copyWith(
          color: foreground,
          fontWeight: big ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}
