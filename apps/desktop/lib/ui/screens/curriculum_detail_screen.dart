import 'package:flutter/material.dart';
import '../../models/subject.dart';
import '../../app/theme/app_colors.dart';
import '../widgets/stat_card.dart';

class CurriculumDetailScreen extends StatefulWidget {
  final String curriculumCode;
  final List<Subject> subjects;

  const CurriculumDetailScreen({
    super.key,
    required this.curriculumCode,
    required this.subjects,
  });

  @override
  State<CurriculumDetailScreen> createState() => _CurriculumDetailScreenState();
}

class _CurriculumDetailScreenState extends State<CurriculumDetailScreen> {
  late Map<int, List<Subject>> _semesterGroups;

  @override
  void initState() {
    super.initState();
    _semesterGroups = {};
    for (var sub in widget.subjects) {
      if (!_semesterGroups.containsKey(sub.semester)) {
        _semesterGroups[sub.semester] = [];
      }
      _semesterGroups[sub.semester]!.add(sub);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedSemesters = _semesterGroups.keys.toList()..sort();

    // Tính toán một số thống kê cơ bản
    int totalCredits = 0;
    int prereqCount = 0;
    for (var sub in widget.subjects) {
      totalCredits += int.tryParse(sub.credits) ?? 0;
      if (sub.preRequisite.isNotEmpty &&
          sub.preRequisite.toLowerCase() != 'none') {
        prereqCount++;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header / Intro
            const Text(
              'Chương trình đào tạo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.curriculumCode,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: AppColors.textMain,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Dưới đây là thống kê tổng quan và lộ trình chi tiết các học kỳ của bạn.',
              style: TextStyle(
                  fontSize: 16, color: AppColors.textSub, height: 1.5),
            ),
            const SizedBox(height: 32),

            // Thống kê nhanh (Stats)
            Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                    child: StatCard(
                        title: 'Học kỳ',
                        value: '${sortedSemesters.length}',
                        icon: Icons.calendar_month_rounded,
                        subtitle: 'Tổng số học kỳ')),
                const SizedBox(width: 16),
                Expanded(
                    child: StatCard(
                        title: 'Môn học',
                        value: '${widget.subjects.length}',
                        icon: Icons.menu_book_rounded,
                        subtitle: 'Tổng số môn học')),
                const SizedBox(width: 16),
                Expanded(
                    child: StatCard(
                        title: 'Tín chỉ',
                        value: '$totalCredits',
                        icon: Icons.military_tech_rounded,
                        subtitle: 'Tổng số tín chỉ')),
              ],
            ),

            const SizedBox(height: 48),

            const SizedBox(height: 48),

            // Roadmap Header
            Row(
              children: [
                const Icon(Icons.map_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                const Text(
                  'Lộ trình các học kỳ',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 16, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Text('$prereqCount môn có tiên quyết',
                          style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),

            // Roadmap Horizontal Scroll
            SizedBox(
              height: 480, // Chiều cao cố định cho các cột
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: sortedSemesters.length,
                clipBehavior: Clip.none,
                itemBuilder: (context, index) {
                  final semester = sortedSemesters[index];
                  final subjects = _semesterGroups[semester]!;
                  return _buildSemesterColumn(semester, subjects, index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSemesterColumn(int semester, List<Subject> subjects, int index) {
    final title = semester == 0 ? 'OJT / Prep' : 'Học kỳ $semester';
    // Đổi màu một chút cho cột để tạo cảm giác flow
    final isEven = index % 2 == 0;

    return Container(
      width: 320,
      margin: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          // Header cột
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isEven ? AppColors.primaryBg : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border:
                  const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        color: AppColors.textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${subjects.length}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),
          // Danh sách môn
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                return _buildSubjectCard(subjects[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(Subject sub) {
    final hasPrereq =
        sub.preRequisite.isNotEmpty && sub.preRequisite.toLowerCase() != 'none';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  sub.code,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '${sub.credits} TC',
                  style: const TextStyle(
                      color: AppColors.textSub,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            sub.name,
            style: const TextStyle(
                color: AppColors.textMain,
                fontSize: 14,
                fontWeight: FontWeight.w500),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (hasPrereq) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded,
                      size: 14, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tiên quyết: ${sub.preRequisite}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }
}
