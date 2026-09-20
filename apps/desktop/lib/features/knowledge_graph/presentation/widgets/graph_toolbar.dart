import 'package:flutter/material.dart';

/// Top bar for both screens [KnowledgeGraphPage] can show.
///
/// - Subject picker (no subject focused yet): just the search box (filters
///   the subject grid) and a subject count.
/// - Graph view (a subject is focused): adds a back button + the focused
///   subject's code to the title, and a live node/edge count for the
///   concept graph currently drawn.
///
/// Rendered as a plain [AppBar] placed at the top of a [Column] (not inside
/// `Scaffold.appBar`), so the page can put the graph canvas and the optional
/// detail panel side by side underneath it.
class GraphToolbar extends StatelessWidget {
  const GraphToolbar({
    super.key,
    this.focusedSubjectCode,
    this.onBack,
    required this.onQueryChanged,
    required this.subjectCount,
    this.nodeCount,
    this.edgeCount,
  });

  /// Null while the subject picker is showing; the subject code once the
  /// user has picked one and its concept graph is on screen.
  final String? focusedSubjectCode;
  final VoidCallback? onBack;

  final ValueChanged<String> onQueryChanged;
  final int subjectCount;

  /// Node/edge counts for the graph currently drawn (the focused subject
  /// plus the concepts found for it). Null in picker mode, where there is
  /// no graph yet.
  final int? nodeCount;
  final int? edgeCount;

  @override
  Widget build(BuildContext context) {
    final isGraphView = focusedSubjectCode != null;

    return AppBar(
      leading: onBack == null
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Chọn môn khác',
              onPressed: onBack,
            ),
      title: Text(
        isGraphView
            ? 'Đồ thị tri thức môn học · ${focusedSubjectCode!}'
            : 'Đồ thị tri thức môn học',
      ),
      titleSpacing: onBack == null ? 16 : 0,
      toolbarHeight: kToolbarHeight + 16,
      actions: [
        SizedBox(
          width: 240,
          height: 40,
          child: TextField(
            key: ValueKey('search-${focusedSubjectCode ?? ''}'),
            onChanged: onQueryChanged,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              prefixIcon: const Icon(Icons.search, size: 18),
              hintText: isGraphView ? 'Tìm trong đồ thị…' : 'Tìm mã môn / tên môn…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Text(
            isGraphView
                ? '${nodeCount ?? 0} nút · ${edgeCount ?? 0} cạnh'
                : '$subjectCount môn',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
