import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../models/subject.dart';
import '../../assistant/application/llm_client.dart';
import '../../knowledge_graph/domain/subject_record.dart';
import '../application/subject_detail_controller.dart';
import '../domain/course_description_formatter.dart';
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
    final syllabus = controller.syllabus;
    return Material(
      color: const Color(0xFFF7FBFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFDCEBFF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SubjectHero(
                    curriculumCode: controller.workspace.curriculumCode,
                    subject: subject,
                    displayName: displayName,
                  ),
                  const SizedBox(height: 10),
                  _SubjectFacts(subject: subject, syllabus: syllabus),
                  const SizedBox(height: 10),
                  _PrerequisiteCard(value: prerequisiteDisplay(subject)),
                  if (controller.syllabusLoading) ...[
                    const SizedBox(height: 10),
                    const _StatusCard(
                      icon: Icons.hourglass_top_rounded,
                      message: 'Loading full syllabus…',
                    ),
                  ] else if (syllabus?.description.isNotEmpty ?? false) ...[
                    const SizedBox(height: 10),
                    _AboutCourseCard(description: syllabus!.description),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDCEBFF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 16,
                          runSpacing: 12,
                          children: [
                            _SectionHeader(
                              icon: Icons.folder_outlined,
                              title:
                                  'Your resources (${controller.resources.length})',
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

class _SubjectHero extends StatelessWidget {
  const _SubjectHero({
    required this.curriculumCode,
    required this.subject,
    required this.displayName,
  });

  final String curriculumCode;
  final Subject subject;
  final SubjectDisplayName displayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1F8FF), Color(0xFFD6E9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFDCEBFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Text(
                curriculumCode,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF2457A6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            subject.code,
            style: theme.textTheme.displaySmall?.copyWith(
              color: const Color(0xFF082F73),
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
          SelectableText(
            displayName.primary,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF082F73),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (displayName.secondary case final secondary?)
            SelectableText(
              secondary,
              style: theme.textTheme.titleLarge?.copyWith(
                color: const Color(0xFF123E7C),
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
    );
  }
}

class _SubjectFacts extends StatelessWidget {
  const _SubjectFacts({required this.subject, required this.syllabus});
  final Subject subject;
  final SubjectRecord? syllabus;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final facts = <(String, String)>[
        ('Semester', subject.semester.toString()),
        ('Credits', subject.credits),
        if (syllabus?.degreeLevel.isNotEmpty ?? false)
          ('Degree level', syllabus!.degreeLevel),
        if (syllabus?.learningTeachingMethod.isNotEmpty ?? false)
          ('Learning–teaching method', syllabus!.learningTeachingMethod),
      ];
      final width = constraints.maxWidth < 620
          ? constraints.maxWidth
          : (constraints.maxWidth - (facts.length - 1) * 8) / facts.length;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final fact in facts)
            SizedBox(
              width: width,
              child: _FactTile(label: fact.$1, value: fact.$2),
            ),
        ],
      );
    },
  );
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 76),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFEEF6FF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _PrerequisiteCard extends StatelessWidget {
  const _PrerequisiteCard({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
    decoration: BoxDecoration(
      color: const Color(0xFFEDF6FF),
      border: const Border(
        left: BorderSide(color: Color(0xFF8BBEFF), width: 6),
      ),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Prerequisite',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        SelectableText(value),
      ],
    ),
  );
}

class _AboutCourseCard extends StatelessWidget {
  const _AboutCourseCard({required this.description});
  final String description;

  @override
  Widget build(BuildContext context) {
    final blocks = formatCourseDescription(description);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCEBFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.menu_book_outlined,
            title: 'About this course',
          ),
          const SizedBox(height: 12),
          SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < blocks.length; index++) ...[
                  if (index > 0) const SizedBox(height: 12),
                  _CourseDescriptionBlockView(block: blocks[index]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseDescriptionBlockView extends StatelessWidget {
  const _CourseDescriptionBlockView({required this.block});

  final CourseDescriptionBlock block;

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case CourseDescriptionBlockType.heading:
        return Text(
          block.text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: const Color(0xFF123E7C),
            fontWeight: FontWeight.w700,
          ),
        );
      case CourseDescriptionBlockType.bullets:
        return Column(
          children: [for (final item in block.items) _DescriptionBullet(item)],
        );
      case CourseDescriptionBlockType.table:
        return _DescriptionTable(rows: block.rows);
      case CourseDescriptionBlockType.paragraph:
        return Text(block.text, style: const TextStyle(height: 1.55));
    }
  }
}

class _DescriptionBullet extends StatelessWidget {
  const _DescriptionBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8, right: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFF075CE5),
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(dimension: 6),
          ),
        ),
        Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
      ],
    ),
  );
}

class _DescriptionTable extends StatelessWidget {
  const _DescriptionTable({required this.rows});

  final List<CourseDescriptionRow> rows;

  @override
  Widget build(BuildContext context) => Table(
    columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(5)},
    border: TableBorder.all(color: const Color(0xFFD7E6F8)),
    children: [
      for (final row in rows)
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF7FAFE)),
          children: [
            _DescriptionCell(text: row.label, isLabel: true),
            _DescriptionCell(text: row.value),
          ],
        ),
    ],
  );
}

class _DescriptionCell extends StatelessWidget {
  const _DescriptionCell({required this.text, this.isLabel = false});

  final String text;
  final bool isLabel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    child: Text(
      text,
      style: TextStyle(
        height: 1.35,
        fontWeight: isLabel ? FontWeight.w700 : null,
      ),
    ),
  );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFEEF6FF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF075CE5)),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
  );
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
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primaryBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textMain,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Dedicated tab for a subject's learning outcomes (CLOs) — split out of
/// the overview so this doesn't turn into one long scrolling page.
/// Dedicated tab for a subject's learning outcomes (CLOs) — split out of
/// the overview so this doesn't turn into one long scrolling page.
class LearningOutcomesPanel extends StatelessWidget {
  const LearningOutcomesPanel({super.key, required this.controller});
  final SubjectDetailController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outcomes = controller.syllabus?.learningOutcomes ?? const [];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x252563EB),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Learning outcomes',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.textMain,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (outcomes.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.15),
                                ),
                              ),
                              child: Text(
                                '${outcomes.length} outcomes',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Course Learning Outcomes (CLOs) defined in the syllabus',
                        style: TextStyle(
                          color: AppColors.textSub,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (outcomes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        size: 36,
                        color: AppColors.textSub,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No learning outcomes available.',
                        style: TextStyle(
                          color: AppColors.textSub,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final outcome in outcomes)
                _LearningOutcomeCard(outcome: outcome),
          ],
        ),
      ),
    );
  }
}

class _LearningOutcomeCard extends StatefulWidget {
  const _LearningOutcomeCard({required this.outcome});
  final LearningOutcome outcome;

  @override
  State<_LearningOutcomeCard> createState() => _LearningOutcomeCardState();
}

class _LearningOutcomeCardState extends State<_LearningOutcomeCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFFAFCFF) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isHovered
                ? AppColors.primary.withOpacity(0.4)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? AppColors.primary.withOpacity(0.08)
                  : const Color(0x05000000),
              blurRadius: _isHovered ? 12 : 4,
              offset: Offset(0, _isHovered ? 4 : 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 4,
                  decoration: BoxDecoration(
                    color: _isHovered
                        ? AppColors.primary
                        : AppColors.primary.withOpacity(0.3),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            widget.outcome.code,
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: SelectableText(
                              widget.outcome.detail,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textMain,
                                height: 1.55,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dedicated tab for the syllabus metadata that isn't already shown as a
/// named field elsewhere (grading scale, workload, tools, approval/admin
/// info, ...).
/// Dedicated tab for the syllabus metadata that isn't already shown as a
/// named field elsewhere (grading scale, workload, tools, approval/admin
/// info, ...).
class OtherSyllabusFieldsPanel extends StatelessWidget {
  const OtherSyllabusFieldsPanel({super.key, required this.controller});
  final SubjectDetailController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syllabus = controller.syllabus;
    final fields = syllabus == null
        ? const <String, String>{}
        : otherSyllabusMetadata(syllabus);
    final grouped = _SyllabusFieldGroups.from(fields);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x252563EB),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.list_alt_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Other syllabus fields',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.textMain,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (fields.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.15),
                                ),
                              ),
                              child: Text(
                                '${fields.length} fields',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Additional course metadata, evaluation rules, and administrative records',
                        style: TextStyle(
                          color: AppColors.textSub,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (grouped.requirements.isNotEmpty)
              _MetadataSection(
                title: 'Course Requirements',
                icon: Icons.assignment_outlined,
                entries: grouped.requirements,
                preferredWeights: const [1.2, 1],
                wideColumnCount: 2,
              ),
            if (grouped.resources.isNotEmpty) ...[
              if (grouped.requirements.isNotEmpty) const SizedBox(height: 24),
              _MetadataSection(
                title: 'Course Resources & Evaluation',
                icon: Icons.assessment_outlined,
                entries: grouped.resources,
                wideColumnCount: 3,
              ),
            ],
            if (grouped.administration.isNotEmpty) ...[
              if (grouped.requirements.isNotEmpty ||
                  grouped.resources.isNotEmpty)
                const SizedBox(height: 24),
              _MetadataSection(
                title: 'Administrative Information',
                icon: Icons.admin_panel_settings_outlined,
                entries: grouped.administration,
                wideColumnCount: 3,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyllabusFieldGroups {
  const _SyllabusFieldGroups({
    required this.requirements,
    required this.resources,
    required this.administration,
  });

  factory _SyllabusFieldGroups.from(Map<String, String> fields) {
    const requirementKeys = {'timeallocation', 'studenttasks'};
    const resourceKeys = {'tools', 'scoringscale', 'minavgmarktopass'};
    const administrationKeys = {
      'decisionnommddyyyy',
      'decisionno',
      'approveddate',
      'isapproved',
      'isscored',
      'isactive',
    };
    final requirements = <MapEntry<String, String>>[];
    final resources = <MapEntry<String, String>>[];
    final administration = <MapEntry<String, String>>[];
    for (final entry in fields.entries) {
      final key = _normalizedMetadataKey(entry.key);
      if (requirementKeys.contains(key)) {
        requirements.add(entry);
      } else if (resourceKeys.contains(key)) {
        resources.add(entry);
      } else if (administrationKeys.contains(key)) {
        administration.add(entry);
      } else {
        // Unknown fields still remain visible; FLM exports evolve over time.
        administration.add(entry);
      }
    }
    return _SyllabusFieldGroups(
      requirements: requirements,
      resources: resources,
      administration: administration,
    );
  }

  final List<MapEntry<String, String>> requirements;
  final List<MapEntry<String, String>> resources;
  final List<MapEntry<String, String>> administration;
}

String _normalizedMetadataKey(String key) =>
    key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

IconData _metadataKeyIcon(String key) {
  final norm = _normalizedMetadataKey(key);
  switch (norm) {
    case 'timeallocation':
      return Icons.schedule_rounded;
    case 'studenttasks':
      return Icons.task_alt_rounded;
    case 'tools':
      return Icons.build_circle_outlined;
    case 'scoringscale':
      return Icons.linear_scale_rounded;
    case 'minavgmarktopass':
      return Icons.fact_check_rounded;
    case 'decisionnommddyyyy':
    case 'decisionno':
      return Icons.gavel_rounded;
    case 'approveddate':
      return Icons.calendar_month_rounded;
    case 'isapproved':
      return Icons.verified_user_rounded;
    case 'isscored':
      return Icons.grade_rounded;
    case 'isactive':
      return Icons.toggle_on_rounded;
    case 'note':
      return Icons.notes_rounded;
    default:
      return Icons.info_outline_rounded;
  }
}

class _MetadataSection extends StatelessWidget {
  const _MetadataSection({
    required this.title,
    required this.icon,
    required this.entries,
    required this.wideColumnCount,
    this.preferredWeights,
  });

  final String title;
  final IconData icon;
  final List<MapEntry<String, String>> entries;
  final int wideColumnCount;
  final List<double>? preferredWeights;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textMain,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _ResponsiveMetadataGrid(
        entries: entries,
        wideColumnCount: wideColumnCount,
        preferredWeights: preferredWeights,
      ),
    ],
  );
}

class _ResponsiveMetadataGrid extends StatelessWidget {
  const _ResponsiveMetadataGrid({
    required this.entries,
    required this.wideColumnCount,
    this.preferredWeights,
  });

  final List<MapEntry<String, String>> entries;
  final int wideColumnCount;
  final List<double>? preferredWeights;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final responsiveColumnCount = width >= 960
          ? wideColumnCount
          : width >= 620
          ? 2
          : 1;
      final columnCount = entries.length < responsiveColumnCount
          ? entries.length
          : responsiveColumnCount;
      const gap = 14.0;
      final canUseWeights =
          columnCount == entries.length &&
          preferredWeights != null &&
          preferredWeights!.length == entries.length;
      if (canUseWeights) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < entries.length; index++) ...[
              if (index > 0) const SizedBox(width: gap),
              Expanded(
                flex: (preferredWeights![index] * 10).round(),
                child: _MetadataCard(entry: entries[index]),
              ),
            ],
          ],
        );
      }

      final cardWidth = (width - gap * (columnCount - 1)) / columnCount;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final entry in entries)
            SizedBox(
              width: cardWidth,
              child: _MetadataCard(entry: entry),
            ),
        ],
      );
    },
  );
}

String _formatKey(String key) {
  final norm = _normalizedMetadataKey(key);
  switch (norm) {
    case 'decisionnommddyyyy':
    case 'decisionno':
      return 'Decision Reference';
    case 'approveddate':
      return 'Approval Date';
    case 'isapproved':
      return 'Approval Status';
    case 'isscored':
      return 'Scoring Status';
    case 'isactive':
      return 'Active Status';
    case 'timeallocation':
      return 'Time Allocation';
    case 'studenttasks':
      return 'Student Tasks & Duties';
    case 'scoringscale':
      return 'Scoring Scale';
    case 'minavgmarktopass':
      return 'Minimum Pass Mark';
    case 'note':
      return 'Notes & Passing Rules';
    default:
      return key
          .replaceAllMapped(
            RegExp(r'(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])'),
            (m) => ' ',
          )
          .replaceAll('_', ' ')
          .trim();
  }
}

class _MetadataCard extends StatefulWidget {
  const _MetadataCard({required this.entry});

  final MapEntry<String, String> entry;

  @override
  State<_MetadataCard> createState() => _MetadataCardState();
}

class _MetadataCardState extends State<_MetadataCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedKey = _normalizedMetadataKey(widget.entry.key);
    final isBoolean = const {
      'isapproved',
      'isscored',
      'isactive',
    }.contains(normalizedKey);
    final isNumeric = RegExp(r'^\d+(\.\d+)?$').hasMatch(widget.entry.value.trim());
    final formattedTitle = _formatKey(widget.entry.key);
    final rawKeyName = widget.entry.key;
    final icon = _metadataKeyIcon(widget.entry.key);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFFAFCFF) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isHovered
                ? AppColors.primary.withOpacity(0.4)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? AppColors.primary.withOpacity(0.08)
                  : const Color(0x05000000),
              blurRadius: _isHovered ? 10 : 4,
              offset: Offset(0, _isHovered ? 3 : 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5.5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBg,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(icon, size: 14, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formattedTitle,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.textMain,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (formattedTitle != rawKeyName)
                        Text(
                          rawKeyName,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                            height: 1.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (isBoolean)
              _BooleanStatusBadge(value: widget.entry.value)
            else if (isNumeric)
              _NumericStatValue(
                value: widget.entry.value,
                keyName: normalizedKey,
              )
            else
              _MetadataTextValue(value: widget.entry.value),
          ],
        ),
      ),
    );
  }
}

class _NumericStatValue extends StatelessWidget {
  const _NumericStatValue({required this.value, required this.keyName});

  final String value;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    final subText = keyName.contains('score') || keyName.contains('mark')
        ? 'Points'
        : 'Scale';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value.trim(),
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primaryBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            subText,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetadataTextValue extends StatelessWidget {
  const _MetadataTextValue({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final blocks = formatCourseDescription(value);
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < blocks.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _CourseDescriptionBlockView(block: blocks[index]),
          ],
        ],
      ),
    );
  }
}

class _BooleanStatusBadge extends StatelessWidget {
  const _BooleanStatusBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final isPositive = {
      'true',
      'yes',
      '1',
    }.contains(value.trim().toLowerCase());
    final foreground = isPositive
        ? const Color(0xFF047857)
        : const Color(0xFF475569);
    final background = isPositive
        ? const Color(0xFFECFDF5)
        : const Color(0xFFF1F5F9);
    final border = isPositive
        ? const Color(0xFFA7F3D0)
        : const Color(0xFFCBD5E1);
    final icon = isPositive
        ? Icons.check_circle_rounded
        : Icons.cancel_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dedicated tab for one of a syllabus's other tables (reference materials,
/// week-by-week session plan, an assessment breakdown, constructive
/// questions, ...) drawn as an actual data grid — header row, zebra-striped
/// body rows, horizontal *and* vertical scroll for wide/tall tables —
/// instead of joined bullet text. All the scrolling (and the scrollbars
/// for it) now lives in [_DataGrid]; see its doc comment for why the two
/// axes are nested the way they are.
class SyllabusTablePanel extends StatelessWidget {
  const SyllabusTablePanel({super.key, required this.section});
  final SyllabusSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCEBFF)),
      ),
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
                      color: theme.colorScheme.primary,
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
            child: _DataGrid(headers: section.headers, rows: section.rows),
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
/// Tall tables (the session plan alone runs 60 rows) need a vertical
/// scrollbar, and wide ones (most syllabus tables have 6+ columns) need a
/// horizontal one. The two scroll views used to be nested with vertical on
/// the *outside* and horizontal on the *inside*, which put the horizontal
/// [Scrollbar] at the bottom of the full scrolled content instead of the
/// bottom of the visible panel — on a 60-row table it sat some 3000px
/// below the fold, effectively undiscoverable. They're nested the other
/// way round here instead: horizontal is the outer scroll view, sized by
/// the [Expanded] this widget sits in, so its `Scrollbar` is always pinned
/// to the bottom of the visible panel regardless of vertical scroll
/// position; vertical scrolling happens inside a fixed-width [SizedBox]
/// (the table's full rendered width) nested inside that.
class _DataGrid extends StatefulWidget {
  const _DataGrid({required this.headers, required this.rows});
  final List<String> headers;
  final List<List<String>> rows;

  @override
  State<_DataGrid> createState() => _DataGridState();
}

class _DataGridState extends State<_DataGrid> {
  final _horizontalController = ScrollController();
  final _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headers = widget.headers;
    final rows = widget.rows;

    if (headers.isEmpty) {
      return Scrollbar(
        controller: _verticalController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _verticalController,
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
        ),
      );
    }

    final specs = [for (final header in headers) _DataColumnSpec.from(header)];
    final columnWidths = [for (final spec in specs) spec.preferredWidth];
    final naturalWidth = columnWidths.fold<double>(0, (sum, w) => sum + w);

    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalPadding =
            32.0; // matches the SingleChildScrollView below
        final available = constraints.maxWidth - horizontalPadding;

        // Keep every column at a useful minimum. Extra room is distributed
        // only to prose columns; compact/status columns never consume a
        // disproportionate share of a wide window.
        final resolvedWidths = List<double>.from(columnWidths);
        var tableWidth = naturalWidth;
        if (available.isFinite && naturalWidth < available) {
          final totalWeight = specs.fold<double>(
            0,
            (sum, spec) => sum + spec.growWeight,
          );
          final extra = available - naturalWidth;
          if (totalWeight > 0) {
            for (var i = 0; i < specs.length; i++) {
              resolvedWidths[i] += extra * specs[i].growWeight / totalWeight;
            }
          }
          tableWidth = available;
        }

        final table = Table(
          border: TableBorder(
            horizontalInside: BorderSide(
              color: theme.colorScheme.outlineVariant,
            ),
            top: BorderSide(color: theme.colorScheme.outlineVariant),
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          columnWidths: {
            for (var i = 0; i < headers.length; i++)
              i: FixedColumnWidth(resolvedWidths[i]),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFEAF4FF)),
              children: [
                for (var index = 0; index < headers.length; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Text(
                      specs[index].label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      textAlign: specs[index].centered
                          ? TextAlign.center
                          : TextAlign.left,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF123E7C),
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
                        textAlign: specs[c].centered
                            ? TextAlign.center
                            : TextAlign.left,
                        softWrap: true,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        );

        return Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          trackVisibility: true,
          interactive: true,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: tableWidth,
              child: Scrollbar(
                controller: _verticalController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _verticalController,
                  child: table,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DataColumnSpec {
  const _DataColumnSpec({
    required this.label,
    required this.preferredWidth,
    required this.growWeight,
    this.centered = false,
  });

  factory _DataColumnSpec.from(String rawHeader) {
    final key = _normalizedMetadataKey(rawHeader);
    final label = _dataGridHeaderLabels[key] ?? _readableHeader(rawHeader);
    final headerWidth = (label.length * 7.5 + 24).clamp(64.0, 220.0);

    if (_compactDataGridColumns.contains(key)) {
      return _DataColumnSpec(
        label: label,
        preferredWidth: headerWidth.clamp(64.0, 110.0),
        growWeight: 0,
        centered: true,
      );
    }
    if (_statusDataGridColumns.contains(key)) {
      return _DataColumnSpec(
        label: label,
        preferredWidth: headerWidth.clamp(92.0, 136.0),
        growWeight: 0,
        centered: true,
      );
    }
    if (_wideDataGridColumns.contains(key)) {
      final base = switch (key) {
        'topic' => 340.0,
        'materialdescription' => 300.0,
        'studentmaterials' => 250.0,
        'studentstasks' => 280.0,
        _ => 260.0,
      };
      return _DataColumnSpec(
        label: label,
        preferredWidth: base < headerWidth ? headerWidth : base,
        growWeight: 2,
      );
    }
    return _DataColumnSpec(
      label: label,
      preferredWidth: headerWidth.clamp(110.0, 180.0),
      growWeight: 0.6,
    );
  }

  final String label;
  final double preferredWidth;
  final double growWeight;
  final bool centered;
}

const _dataGridHeaderLabels = <String, String>{
  'no': 'No.',
  'materialdescription': 'Material Description',
  'publisheddate': 'Published Date',
  'ismainmaterial': 'Main Material',
  'ishardcopy': 'Hardcopy',
  'isonline': 'Online',
  'learningteachingtype': 'Teaching Method',
  'studentmaterials': 'Student Materials',
  'studentstasks': 'Student Tasks',
  'sdownload': 'Download',
  'clo': 'CLO',
  'itu': 'ITU',
  'isbn': 'ISBN',
};

const _compactDataGridColumns = <String>{
  'no',
  'session',
  'part',
  'clo',
  'itu',
  'edition',
};

const _statusDataGridColumns = <String>{
  'ismainmaterial',
  'ishardcopy',
  'isonline',
  'sdownload',
};

const _wideDataGridColumns = <String>{
  'materialdescription',
  'description',
  'details',
  'topic',
  'studentmaterials',
  'studentstasks',
  'name',
};

String _readableHeader(String header) {
  final spaced = header
      .trim()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      );
  if (spaced.isEmpty) return header;
  return spaced
      .split(RegExp(r'\s+'))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}
