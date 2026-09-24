import 'package:flutter/material.dart';
import '../../models/curriculum_data.dart';
import '../../models/subject.dart';
import '../../app/theme/app_colors.dart';

class SemesterTreeWidget extends StatefulWidget {
  final CurriculumData? curriculumData;
  final String? curriculumCode;
  final Function(Subject subject) onSubjectTap;
  final String? selectedSubjectCode;

  const SemesterTreeWidget({
    super.key,
    this.curriculumData,
    this.curriculumCode,
    required this.onSubjectTap,
    this.selectedSubjectCode,
  });

  @override
  State<SemesterTreeWidget> createState() => _SemesterTreeWidgetState();
}

class _SemesterTreeWidgetState extends State<SemesterTreeWidget> {
  bool _isSectionExpanded = false;
  final Set<int> _expandedSemesters = {};

  @override
  Widget build(BuildContext context) {
    final curriculumData = widget.curriculumData;
    if (curriculumData == null || curriculumData.subjects.isEmpty) {
      return const SizedBox.shrink();
    }

    final Map<int, List<Subject>> semesterMap = {};
    for (final subject in curriculumData.subjects) {
      final sem = subject.semester;
      semesterMap.putIfAbsent(sem, () => []).add(subject);
    }

    final sortedSemesters = semesterMap.keys.toList()..sort();
    final curriculumCode = widget.curriculumCode ??
        curriculumData.metadata['curriculumCode']?.toString() ??
        'BIT_SE';

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: TỆP & MÔN HỌC (Clickable row + toggle button)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _isSectionExpanded = !_isSectionExpanded;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isSectionExpanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_right_rounded,
                        size: 20,
                        color: AppColors.textSub,
                      ),
                      onPressed: () {
                        setState(() {
                          _isSectionExpanded = !_isSectionExpanded;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      tooltip: _isSectionExpanded ? 'Thu gọn Tệp & Môn học' : 'Mở rộng Tệp & Môn học',
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.folder_copy_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'TỆP & MÔN HỌC',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMain,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${curriculumData.subjects.length} môn',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isSectionExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            
            // Root Folder: BIT_SE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_special_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      curriculumCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Semester Folders & Subjects
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final sem in sortedSemesters)
                      _buildSemesterFolder(sem, semesterMap[sem] ?? []),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSemesterFolder(int sem, List<Subject> subjects) {
    final isExpanded = _expandedSemesters.contains(sem);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedSemesters.remove(sem);
              } else {
                _expandedSemesters.add(sem);
              }
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 16,
                  color: AppColors.textSub,
                ),
                const SizedBox(width: 4),
                Icon(
                  isExpanded
                      ? Icons.folder_open_rounded
                      : Icons.folder_rounded,
                  size: 16,
                  color: isExpanded ? AppColors.primary : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sem == 0 ? 'Môn bổ trợ / Chưa xếp' : 'Học kỳ $sem',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isExpanded ? FontWeight.bold : FontWeight.w600,
                      color: isExpanded ? AppColors.textMain : AppColors.textSub,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${subjects.length}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSub,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final subject in subjects)
                  _buildSubjectTreeItem(subject),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSubjectTreeItem(Subject subject) {
    final isSelected = widget.selectedSubjectCode == subject.code;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () => widget.onSubjectTap(subject),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryBg : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isSelected
                ? Border.all(color: AppColors.primary.withOpacity(0.3))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 14,
                color: isSelected ? AppColors.primary : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.code,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? AppColors.primaryDark : const Color(0xFF334155),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subject.name.isNotEmpty)
                      Text(
                        subject.name,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
