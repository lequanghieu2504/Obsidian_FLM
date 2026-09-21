import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../assistant/application/llm_client.dart';
import '../../knowledge_graph/domain/subject_record.dart';
import '../application/subject_detail_controller.dart';
import '../domain/subject_display.dart';
import '../domain/subject_workspace.dart';

/// [syllabus.metadata], minus the handful of keys already shown as
/// dedicated fields elsewhere (syllabus name, description, ...) —
/// everything else the raw file carries (grading scale, workload, tools,
/// approval/admin info, ...) so nothing the Gemini prompt already has is
/// hidden from the "Other syllabus fields" tab.
Map<String, String> otherSyllabusMetadata(SubjectRecord syllabus) => {
  for (final entry in syllabus.metadata.entries)
    if (!SubjectPromptBuilder.namedMetadataKeys.contains(entry.key) &&
        entry.value.isNotEmpty)
      entry.key: entry.value,
};

class SubjectOverviewPanel extends StatelessWidget {
  const SubjectOverviewPanel({super.key, required this.controller});
  final SubjectDetailController controller;

  Future<void> _import(BuildContext context) async {
    try {
      final files = await openFiles();
      if (files.isEmpty) return;
      await controller.importFiles(files.map((f) => f.path).toList());
      if (context.mounted && controller.resourceError == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resources copied to your local workspace.'),
          ),
        );
      }
    } catch (_) {
      controller.reportResourceError(
        'Could not open the file picker. Please try again.',
      );
    }
  }

  Future<void> _open(UserResource resource) async {
    try {
      final path = await controller.repository.resourcePath(
        controller.workspace,
        resource,
      );
      if (!await launchUrl(Uri.file(path))) {
        controller.reportResourceError(
          'No application could open this file. Install an application for this file type.',
        );
      }
    } catch (_) {
      controller.reportResourceError(
        'Cannot open this local copy. Check that the file exists and a suitable application is installed.',
      );
    }
  }

  Future<void> _delete(BuildContext context, UserResource resource) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete local resource?'),
        content: Text(
          'Delete “${resource.originalFileName}” from this workspace? Your original file is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteResource(resource);
  }

  IconData _icon(String extension) => switch (extension) {
    '.pdf' => Icons.picture_as_pdf_outlined,
    '.png' || '.jpg' || '.jpeg' || '.webp' || '.gif' => Icons.image_outlined,
    '.xlsx' || '.xls' || '.csv' => Icons.table_chart_outlined,
    '.ppt' || '.pptx' => Icons.slideshow_outlined,
    '.doc' || '.docx' || '.txt' => Icons.description_outlined,
    '.zip' || '.7z' || '.rar' => Icons.folder_zip_outlined,
    _ => Icons.insert_drive_file_outlined,
  };

  String _size(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final subject = controller.workspace.subject;
    final displayName = subjectDisplayName(subject);
    final theme = Theme.of(context);
    return Card(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.workspace.curriculumCode,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    subject.code,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    displayName.primary,
                    style: theme.textTheme.headlineSmall,
                  ),
                  if (displayName.secondary case final secondary?) ...[
                    const SizedBox(height: 4),
                    SelectableText(
                      secondary,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  const _SectionHeader(
                    icon: Icons.menu_book_outlined,
                    title: 'Subject information',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _InformationField(label: 'Code', value: subject.code),
                      _InformationField(
                        label: 'Semester',
                        value: subject.semester.toString(),
                      ),
                      _InformationField(
                        label: 'Credits',
                        value: subject.credits,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InformationField(
                    label: 'Prerequisite',
                    value: prerequisiteDisplay(subject),
                    wide: true,
                  ),
                  const SizedBox(height: 32),
                  _SyllabusSection(controller: controller),
                  const SizedBox(height: 32),
                  Divider(color: theme.colorScheme.outlineVariant),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      _SectionHeader(
                        icon: Icons.folder_outlined,
                        title: 'Your resources (${controller.resources.length})',
                      ),
                      FilledButton.icon(
                        onPressed:
                            controller.resourceBusy ||
                                !controller.resourcesReady
                            ? null
                            : () => _import(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Upload resource'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Resources stay on this device unless you explicitly attach them to a Gemini message.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (controller.resourceBusy ||
                      controller.resourcesLoading) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(
                      semanticsLabel: 'Updating local resources',
                    ),
                  ],
                  if (controller.resourceError != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        controller.resourceError!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                    TextButton(
                      onPressed: controller.resourceBusy
                          ? null
                          : controller.loadResources,
                      child: const Text('Reload resources'),
                    ),
                  ],
                  if (!controller.resourcesLoading &&
                      controller.resourcesReady &&
                      controller.resources.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.folder_open_outlined,
                            size: 40,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Keep your study files together',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add notes, slides, spreadsheets, images, or any other file. A local copy will be kept for this Subject.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            sliver: SliverList.builder(
              itemCount: controller.resources.length,
              itemBuilder: (context, index) {
                final resource = controller.resources[index];
                final date = MaterialLocalizations.of(
                  context,
                ).formatShortDate(resource.importedAt.toLocal());
                return ListTile(
                  leading: Icon(_icon(resource.extension)),
                  title: Tooltip(
                    message: resource.originalFileName,
                    child: Text(
                      resource.originalFileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  subtitle: Text('${_size(resource.size)} · $date'),
                  onTap: controller.resourceBusy ? null : () => _open(resource),
                  trailing: IconButton(
                    tooltip: 'Delete ${resource.originalFileName}',
                    onPressed: controller.resourceBusy
                        ? null
                        : () => _delete(context, resource),
                    icon: const Icon(Icons.delete_outline),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Consistent section header — icon + a colored, bold title — used for
/// every major block of this panel so the visual hierarchy comes from
/// size/weight/color (per the design system), not from every header
/// looking the same.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InformationField extends StatelessWidget {
  const _InformationField({
    required this.label,
    required this.value,
    this.wide = false,
  });

  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: wide ? 280 : 120,
        maxWidth: wide ? 720 : 220,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// The subject's full FLM syllabus (`data/subject/<id>.json`, loaded by
/// `SubjectDetailController.loadSyllabus` via the knowledge-graph feature's
/// `SubjectRepository`) — description, learning outcomes, and the other
/// fields the curriculum file (`Subject`) doesn't carry. This is the same
/// record sent to Gemini as context (`SubjectPromptBuilder`), shown here so
/// the user can see exactly what the assistant already knows about the
/// subject.
class _SyllabusSection extends StatelessWidget {
  const _SyllabusSection({required this.controller});
  final SubjectDetailController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (controller.syllabusLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(
          semanticsLabel: 'Loading full syllabus',
        ),
      );
    }

    final syllabus = controller.syllabus;
    if (syllabus == null) {
      return Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              controller.syllabusError ??
                  'No detailed syllabus found in data/subject/ for this subject.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(icon: Icons.article_outlined, title: 'Syllabus'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (syllabus.syllabusName.isNotEmpty)
              _InformationField(
                label: 'Syllabus name',
                value: syllabus.syllabusName,
                wide: true,
              ),
            if (syllabus.courseNameEnglish.isNotEmpty)
              _InformationField(
                label: 'Course name (English)',
                value: syllabus.courseNameEnglish,
                wide: true,
              ),
            if (syllabus.degreeLevel.isNotEmpty)
              _InformationField(
                label: 'Degree level',
                value: syllabus.degreeLevel,
              ),
            if (syllabus.learningTeachingMethod.isNotEmpty)
              _InformationField(
                label: 'Learning-teaching method',
                value: syllabus.learningTeachingMethod,
                wide: true,
              ),
          ],
        ),
        if (syllabus.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          _InformationField(
            label: 'Description',
            value: syllabus.description,
            wide: true,
          ),
        ],
      ],
    );
  }
}

/// Dedicated tab for a subject's learning outcomes (CLOs) — split out of
/// the overview so this doesn't turn into one long scrolling page.
class LearningOutcomesPanel extends StatelessWidget {
  const LearningOutcomesPanel({super.key, required this.controller});
  final SubjectDetailController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outcomes = controller.syllabus?.learningOutcomes ?? const [];
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.flag_outlined,
              title: 'Learning outcomes',
            ),
            const SizedBox(height: 16),
            for (final outcome in outcomes)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SelectableText.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${outcome.code}: ',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      TextSpan(
                        text: outcome.detail,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dedicated tab for the syllabus metadata that isn't already shown as a
/// named field elsewhere (grading scale, workload, tools, approval/admin
/// info, ...).
class OtherSyllabusFieldsPanel extends StatelessWidget {
  const OtherSyllabusFieldsPanel({super.key, required this.controller});
  final SubjectDetailController controller;

  @override
  Widget build(BuildContext context) {
    final syllabus = controller.syllabus;
    final fields = syllabus == null
        ? const <String, String>{}
        : otherSyllabusMetadata(syllabus);
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.list_alt_outlined,
              title: 'Other syllabus fields',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final entry in fields.entries)
                  _InformationField(
                    label: entry.key,
                    value: entry.value,
                    wide: entry.value.length > 48,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dedicated tab for one of a syllabus's other tables (reference materials,
/// week-by-week session plan, an assessment breakdown, constructive
/// questions, ...) drawn as an actual data grid — header row, zebra-striped
/// body rows, horizontal scroll for wide tables — instead of joined bullet
/// text. Some of these tables run to dozens or hundreds of rows (e.g. a
/// full bank of constructive questions), so the vertical scroll also gets
/// an always-visible [Scrollbar], in addition to the horizontal one
/// [_DataGrid] draws for its own axis.
class SyllabusTablePanel extends StatefulWidget {
  const SyllabusTablePanel({super.key, required this.section});
  final SyllabusSection section;

  @override
  State<SyllabusTablePanel> createState() => _SyllabusTablePanelState();
}

class _SyllabusTablePanelState extends State<SyllabusTablePanel> {
  final _verticalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final section = widget.section;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    section.heading,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${section.rows.length} dòng',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Expanded(
            child: Scrollbar(
              controller: _verticalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _verticalController,
                child: _DataGrid(
                  headers: section.headers,
                  rows: section.rows,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A plain, scrollable data grid — header row + zebra-striped body rows —
/// for tabular `SyllabusSection` data whose columns aren't known ahead of
/// time. Column widths are sized from each column's longest cell (capped),
/// so short columns (session number, Yes/No flags) stay narrow and
/// long-text columns (topic, description) get room to wrap rather than
/// forcing every column to the same width.
///
/// Wide tables (most syllabus tables have 6+ columns) scroll horizontally
/// under an always-visible [Scrollbar] — a `StatefulWidget` only so it can
/// own the [ScrollController] that ties the scrollbar's thumb to that one
/// scroll view (an unscoped `Scrollbar` can't tell which of the nested
/// horizontal/vertical scroll views it belongs to).
class _DataGrid extends StatefulWidget {
  const _DataGrid({required this.headers, required this.rows});
  final List<String> headers;
  final List<List<String>> rows;

  @override
  State<_DataGrid> createState() => _DataGridState();
}

class _DataGridState extends State<_DataGrid> {
  final _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  double _columnWidth(int index) {
    var maxLen = index < widget.headers.length ? widget.headers[index].length : 0;
    for (final row in widget.rows) {
      if (index < row.length && row[index].length > maxLen) {
        maxLen = row[index].length;
      }
    }
    return (maxLen * 6.8 + 28).clamp(90, 320);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headers = widget.headers;
    final rows = widget.rows;

    if (headers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final row in rows)
              if (row.any((cell) => cell.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    row.where((cell) => cell.isNotEmpty).join(' · '),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
          ],
        ),
      );
    }

    return Scrollbar(
      controller: _horizontalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Table(
          border: TableBorder(
            horizontalInside: BorderSide(color: theme.colorScheme.outlineVariant),
            top: BorderSide(color: theme.colorScheme.outlineVariant),
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          columnWidths: {
            for (var i = 0; i < headers.length; i++)
              i: FixedColumnWidth(_columnWidth(i)),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              children: [
                for (final header in headers)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Text(
                      header,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            for (var r = 0; r < rows.length; r++)
              TableRow(
                decoration: BoxDecoration(
                  color: r.isEven
                      ? theme.colorScheme.surface
                      : theme.colorScheme.surfaceContainerLow,
                ),
                children: [
                  for (var c = 0; c < headers.length; c++)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Text(
                        c < rows[r].length ? rows[r][c] : '',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
