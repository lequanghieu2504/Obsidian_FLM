import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    // Sắp xếp các kỳ học tăng dần
    final sortedSemesters = _semesterGroups.keys.toList()..sort();
    
    // Calculate total credits
    int totalCredits = 0;
    for (var sub in widget.subjects) {
      totalCredits += int.tryParse(sub.credits) ?? 0;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Banner
            _buildBanner().animate().fade(duration: 500.ms).slideY(begin: 0.2, end: 0),
            
            const SizedBox(height: 32),
            
            // 2. Stat Cards
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Tổng Tín Chỉ', 
                    value: totalCredits.toString(), 
                    icon: Icons.star_rounded, 
                    subtitle: 'Yêu cầu tốt nghiệp'
                  ).animate().fade(delay: 100.ms).scale(begin: const Offset(0.9, 0.9))
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: StatCard(
                    title: 'Tổng Số Môn', 
                    value: widget.subjects.length.toString(), 
                    icon: Icons.book_rounded, 
                    subtitle: 'Trong chương trình', 
                    iconColor: AppColors.primaryLight
                  ).animate().fade(delay: 200.ms).scale(begin: const Offset(0.9, 0.9))
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: StatCard(
                    title: 'Số Học Kỳ', 
                    value: sortedSemesters.length.toString(), 
                    icon: Icons.calendar_month_rounded, 
                    subtitle: 'Không tính OJT/Prep', 
                    iconColor: AppColors.primary
                  ).animate().fade(delay: 300.ms).scale(begin: const Offset(0.9, 0.9))
                ),
              ],
            ),
            
            const SizedBox(height: 48),
            const Text(
              'Lộ Trình Học Tập',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 24),

            // 3. Roadmap (Horizontal List of Semesters)
            SizedBox(
              height: 500, // Fixed height for horizontal scrolling area
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: sortedSemesters.length,
                itemBuilder: (context, index) {
                  final semester = sortedSemesters[index];
                  final subjects = _semesterGroups[semester]!;
                  
                  return _buildSemesterColumn(semester, subjects)
                      .animate()
                      .fade(delay: (400 + (index * 100)).ms)
                      .slideX(begin: 0.1);
                },
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ]
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Curriculum • ${widget.curriculumCode}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Chi tiết lộ trình học tập',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
                ),
                const SizedBox(height: 12),
                Text(
                  'Dưới đây là chi tiết toàn bộ ${widget.subjects.length} môn học trong chương trình ${widget.curriculumCode}.',
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.map_rounded, size: 80, color: Colors.white),
          )
        ],
      ),
    );
  }

  Widget _buildSemesterColumn(int semester, List<Subject> subjects) {
    final title = semester == 0 ? 'OJT / Prep' : 'Semester $semester';
    
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 24, bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          // Header cột
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${subjects.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),
          // Danh sách môn
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                final sub = subjects[index];
                return _buildSubjectCard(sub);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(Subject sub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryDark),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${sub.credits} cr',
                  style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            sub.name,
            style: const TextStyle(color: AppColors.textMain, fontSize: 13),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (sub.preRequisite.isNotEmpty && sub.preRequisite.toLowerCase() != 'none') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 14, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Prerequisite: ${sub.preRequisite}',
                      style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600),
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
