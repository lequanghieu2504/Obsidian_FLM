import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../models/curriculum_data.dart';
import '../../models/subject.dart';

class ExploreCurriculumDetailScreen extends StatelessWidget {
  final Map<String, dynamic> item;

  const ExploreCurriculumDetailScreen({super.key, required this.item});

  Widget _buildSubject(String code, String name, String semester, int credits) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(code,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 16)),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                        fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildBadge(Icons.calendar_month, semester),
                    const SizedBox(width: 12),
                    _buildBadge(Icons.military_tech, '$credits tín chỉ'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSub),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                color: AppColors.textSub,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textMain),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(item['code'],
            style: const TextStyle(
                color: AppColors.textMain, fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.school_rounded,
                            color: AppColors.primary, size: 40),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['code'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 28,
                                    color: AppColors.primaryDark)),
                            const SizedBox(height: 8),
                            Text('${item['major']} • Khóa ${item['cohort']}',
                                style: const TextStyle(
                                    fontSize: 16, color: AppColors.textSub)),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Tính năng chuyển đổi khung chương trình đang được phát triển!')),
                            );
                          },
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: const Text('Chuyển sang lộ trình này'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                const Text('Danh sách môn học',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: AppColors.textMain)),
                const SizedBox(height: 24),
                ...(() {
                  final curriculumData = item['data'] as CurriculumData;
                  final subjects = List<Subject>.from(curriculumData.subjects);
                  subjects.sort((a, b) => a.semester.compareTo(b.semester));
                  List<Widget> widgets = [];
                  int currentSemester = -1;

                  for (var s in subjects) {
                    if (s.semester != currentSemester) {
                      currentSemester = s.semester;
                      widgets.add(Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Kỳ $currentSemester',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(indent: 16, color: Color(0xFFE2E8F0))),
                          ],
                        ),
                      ));
                    }
                    widgets.add(_buildSubject(
                      s.code,
                      s.name,
                      'Kỳ ${s.semester}',
                      s.credits is String
                          ? int.tryParse(s.credits.toString()) ?? 0
                          : s.credits as int,
                    ));
                  }
                  return widgets;
                })(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
