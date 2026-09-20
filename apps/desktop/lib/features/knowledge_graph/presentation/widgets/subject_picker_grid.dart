import 'package:flutter/material.dart';

import '../../domain/subject_record.dart';

/// The screen shown before any subject is picked: every subject as a tappable
/// card, filtered live by the toolbar's search box. Picking a card is what
/// switches [KnowledgeGraphPage] into graph mode, focused on that subject —
/// the full 700+-node graph is never the first thing the user sees.
class SubjectPickerGrid extends StatelessWidget {
  const SubjectPickerGrid({
    super.key,
    required this.subjects,
    required this.query,
    required this.onSelect,
  });

  final List<SubjectRecord> subjects;
  final String query;
  final ValueChanged<String> onSelect;

  bool _matches(SubjectRecord s) {
    if (query.isEmpty) return true;
    return s.subjectCode.toLowerCase().contains(query) ||
        s.syllabusName.toLowerCase().contains(query) ||
        s.courseNameEnglish.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = subjects.where(_matches).toList()
      ..sort((a, b) => a.subjectCode.compareTo(b.subjectCode));

    if (filtered.isEmpty) {
      return const Center(
        child: Text('Không tìm thấy môn học phù hợp với từ khoá tìm kiếm.'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 92,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final subject = filtered[index];
        return _SubjectCard(
          subject: subject,
          onTap: () => onSelect(subject.subjectCode),
        );
      },
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject, required this.onTap});

  final SubjectRecord subject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name =
        subject.syllabusName.isNotEmpty ? subject.syllabusName : subject.courseNameEnglish;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subject.subjectCode,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (subject.credits.isNotEmpty && subject.credits != '0')
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${subject.credits} tc',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
              if (name.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  name,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
