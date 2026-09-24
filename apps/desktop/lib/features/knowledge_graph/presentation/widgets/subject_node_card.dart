import 'package:flutter/material.dart';

import '../../domain/graph_model.dart';

/// The widget rendered for one graph node. Designed with modern, luxury
/// aesthetics: subject root cards use deep royal gradients and formatted sub-titles,
/// topic nodes use vibrant tier-specific gradients with icons, and subtopics
/// use crisp surface pills with color-matched borders to ensure absolute clarity
/// and zero text overlap.
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
        return _buildTopicCard(context);
      case NodeType.subtopic:
        return _buildSubtopicCard(context);
      case NodeType.subject:
      default:
        return _buildSubjectCard(context);
    }
  }

  Widget _buildSubjectCard(BuildContext context) {
    final credits = (node.attributes['credits'] ?? '').toString();
    final rawName = (node.attributes['name'] ?? '').toString();

    String mainTitle = rawName;
    String? subTitle;
    if (rawName.contains('_')) {
      final parts = rawName.split('_');
      mainTitle = parts[0].trim();
      subTitle = parts[1].trim();
    }

    final isDark = isSelected;
    final gradientColors = isDark
        ? const [Color(0xFF1E3A8A), Color(0xFF2563EB)]
        : const [Color(0xFF1E40AF), Color(0xFF3B82F6)];

    final borderColor = isHighlighted
        ? Colors.amber
        : (isSelected ? Colors.white : const Color(0xFF93C5FD));

    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      scale: isSelected ? 1.05 : 1.0,
      child: Container(
        width: 240,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isHighlighted ? 3 : (isSelected ? 2.5 : 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x331E40AF),
              blurRadius: isSelected ? 20 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (credits.isNotEmpty && credits != '0')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$credits tc',
                      style: const TextStyle(
                        color: Color(0xFF1E40AF),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            if (mainTitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                mainTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (subTitle != null && subTitle.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                subTitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w400,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopicCard(BuildContext context) {
    final label = node.label;
    final lower = label.toLowerCase();

    List<Color> gradient;
    IconData icon;

    if (lower.contains('data structure') || lower.contains('cấu trúc')) {
      gradient = const [Color(0xFF2563EB), Color(0xFF1D4ED8)];
      icon = Icons.schema_rounded;
    } else if (lower.contains('algorithm') || lower.contains('giải thuật') || lower.contains('thuật toán')) {
      gradient = const [Color(0xFF7C3AED), Color(0xFF6D28D9)];
      icon = Icons.psychology_rounded;
    } else if (lower.contains('java') || lower.contains('c++') || lower.contains('python') || lower.contains('code') || lower.contains('prerequisite')) {
      gradient = const [Color(0xFF059669), Color(0xFF047857)];
      icon = Icons.code_rounded;
    } else {
      gradient = const [Color(0xFF0284C7), Color(0xFF0369A1)];
      icon = Icons.auto_awesome_rounded;
    }

    final borderColor = isHighlighted
        ? Colors.amber
        : (isSelected ? Colors.white : Colors.transparent);

    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      scale: isSelected ? 1.08 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: isHighlighted ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.3),
              blurRadius: isSelected ? 14 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtopicCard(BuildContext context) {
    final topicLabel = (node.attributes['topicLabel'] ?? '').toString().toLowerCase();

    Color accentColor;
    if (topicLabel.contains('algorithm') || topicLabel.contains('giải thuật')) {
      accentColor = const Color(0xFF8B5CF6);
    } else if (topicLabel.contains('data structure') || topicLabel.contains('cấu trúc')) {
      accentColor = const Color(0xFF3B82F6);
    } else if (topicLabel.contains('java') || topicLabel.contains('code')) {
      accentColor = const Color(0xFF10B981);
    } else {
      accentColor = const Color(0xFF0284C7);
    }

    final isDark = isSelected;
    final backgroundColor = isDark
        ? accentColor
        : (isHighlighted ? const Color(0xFFFEF3C7) : Colors.white);

    final textColor = isDark
        ? Colors.white
        : (isHighlighted ? const Color(0xFF92400E) : const Color(0xFF1E293B));

    final borderColor = isHighlighted
        ? Colors.amber
        : (isSelected ? Colors.white : accentColor.withOpacity(0.5));

    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      scale: isSelected ? 1.08 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isSelected || isHighlighted ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? accentColor.withOpacity(0.3)
                  : Colors.black.withOpacity(0.04),
              blurRadius: isSelected ? 10 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isDark ? Colors.white : accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              node.label,
              style: TextStyle(
                color: textColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
