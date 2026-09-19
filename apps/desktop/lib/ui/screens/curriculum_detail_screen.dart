import 'package:flutter/material.dart';
import '../../models/subject.dart';
import '../theme/app_colors.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FD),
      appBar: AppBar(
        title: Text(
          'Roadmap: ${widget.curriculumCode}',
          style: const TextStyle(fontFamily: 'Segoe UI', fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: Colors.white,
            width: double.infinity,
            child: Row(
              children: [
                const Icon(Icons.map_rounded, color: Color(0xFF10B981), size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lộ trình học tập',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'),
                    ),
                    Text(
                      '${widget.subjects.length} Môn học • ${sortedSemesters.length} Học kỳ',
                      style: const TextStyle(color: Colors.grey, fontFamily: 'Segoe UI'),
                    )
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(24),
              itemCount: sortedSemesters.length,
              itemBuilder: (context, index) {
                final semester = sortedSemesters[index];
                final subjects = _semesterGroups[semester]!;
                
                return _buildSemesterColumn(semester, subjects);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterColumn(int semester, List<Subject> subjects) {
    final title = semester == 0 ? 'OJT / Prep' : 'Semester $semester';
    
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          // Header cột
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI'),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
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
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF10B981), fontFamily: 'Segoe UI'),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${sub.credits} cr',
                  style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            sub.name,
            style: TextStyle(color: Colors.grey.shade800, fontSize: 14, fontFamily: 'Segoe UI'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (sub.preRequisite.isNotEmpty && sub.preRequisite.toLowerCase() != 'none') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Prerequisite: ${sub.preRequisite}',
                      style: const TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w600),
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
