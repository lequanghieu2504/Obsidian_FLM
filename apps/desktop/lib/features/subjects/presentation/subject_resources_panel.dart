import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/subject_detail_controller.dart';
import '../domain/subject_display.dart';
import '../domain/subject_workspace.dart';

class SubjectResourcesPanel extends StatelessWidget {
  const SubjectResourcesPanel({super.key, required this.controller});
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
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    subject.code,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    displayName.primary,
                    style: theme.textTheme.headlineSmall,
                  ),
                  if (displayName.secondary case final secondary?) ...[
                    const SizedBox(height: 6),
                    SelectableText(
                      secondary,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Subject information',
                    style: theme.textTheme.titleLarge,
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
                  const SizedBox(height: 24),
                  _SyllabusSection(controller: controller),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      Text(
                        'Your resources (${controller.resources.length})',
                        style: theme.textTheme.titleLarge,
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
                  const Text(
                    'Resources stay on this device unless you explicitly attach them to a Gemini message.',
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
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.folder_open_outlined, size: 40),
                          SizedBox(height: 12),
                          Text('Keep your study files together'),
                          SizedBox(height: 8),
                          Text(
                            'Add notes, slides, spreadsheets, images, or any other file. A local copy will be kept for this Subject.',
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
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          SelectableText(value, style: theme.textTheme.bodyLarge),
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
      return Text(
        controller.syllabusError ??
            'No detailed syllabus found in data/subject/ for this subject.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Syllabus', style: theme.textTheme.titleLarge),
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
        if (syllabus.learningOutcomes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Learning outcomes', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          ...syllabus.learningOutcomes.map(
            (outcome) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SelectableText.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${outcome.code}: ',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
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
          ),
        ],
      ],
    );
  }
}
