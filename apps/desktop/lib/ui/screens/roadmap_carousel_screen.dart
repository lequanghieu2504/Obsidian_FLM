import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/subject.dart';
import '../../app/theme/app_colors.dart';

class RoadmapCarouselScreen extends StatefulWidget {
  final Map<int, List<Subject>> semesterGroups;
  final List<int> sortedSemesters;
  final Map<String, dynamic> syllabi;

  const RoadmapCarouselScreen({
    super.key,
    required this.semesterGroups,
    required this.sortedSemesters,
    required this.syllabi,
  });

  @override
  State<RoadmapCarouselScreen> createState() => _RoadmapCarouselScreenState();
}

class _RoadmapCarouselScreenState extends State<RoadmapCarouselScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.sortedSemesters.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  String _getSubjectDescription(String subjectCode) {
    if (widget.syllabi.containsKey(subjectCode)) {
      final metadata = widget.syllabi[subjectCode]['metadata'];
      if (metadata != null) {
        // Try multiple possible keys for description
        if (metadata['Description'] != null) return metadata['Description'].toString();
        if (metadata['Subject Description'] != null) return metadata['Subject Description'].toString();
      }
      if (widget.syllabi[subjectCode]['description'] != null) {
        return widget.syllabi[subjectCode]['description'].toString();
      }
    }
    return 'Chưa có thông tin mô tả chi tiết cho môn học này.';
  }

  Widget _buildSubjectCard(Subject subject) {
    final description = _getSubjectDescription(subject.code);
    final reqs = subject.preRequisite.isNotEmpty && subject.preRequisite.toLowerCase() != 'none' 
                 && subject.preRequisite != '-' ? subject.preRequisite : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  subject.code,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 20),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.military_tech_rounded, size: 18, color: AppColors.textSub),
                    const SizedBox(width: 8),
                    Text('${subject.credits} TC', style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            subject.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
          if (reqs != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link_rounded, size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Text('Tiên quyết: $reqs', style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Divider(color: Color(0xFFE2E8F0)),
          ),
          const Text(
            'Mô tả môn học',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
          const SizedBox(height: 12),
          _buildDescriptionTable(description),
        ],
      ),
    );
  }

  Widget _buildDescriptionTable(String description) {
    // Tìm kiếm các ký tự đánh dấu danh sách phổ biến
    final hasBullets = description.contains('•');
    final hasHyphenBullets = description.contains(' - ');
    final hasAsterisks = description.contains(' * ') || description.startsWith('* ');

    if (!hasBullets && !hasHyphenBullets && !hasAsterisks) {
      return Text(description, style: const TextStyle(fontSize: 15, color: AppColors.textSub, height: 1.6));
    }

    final splitPattern = RegExp(r'(?:•| - | \* |^\* )', multiLine: true);
    final parts = description.split(splitPattern);
    
    final intro = parts.isNotEmpty ? parts[0].trim() : '';
    final bullets = parts.length > 1 ? parts.sublist(1) : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (intro.isNotEmpty) ...[
          Text(intro, style: const TextStyle(fontSize: 15, color: AppColors.textMain, fontWeight: FontWeight.bold, height: 1.6)),
          const SizedBox(height: 16),
        ],
        if (bullets.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Table(
                border: const TableBorder(
                  horizontalInside: BorderSide(color: Color(0xFFE2E8F0)),
                  verticalInside: BorderSide(color: Color(0xFFE2E8F0)),
                ),
                columnWidths: const {
                  0: FixedColumnWidth(60),
                  1: FlexColumnWidth(),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05)),
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text('STT', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark), textAlign: TextAlign.center),
                      ),
                      Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text('Nội dung', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                      ),
                    ],
                  ),
                  ...bullets.asMap().entries.where((e) => e.value.trim().isNotEmpty).map((entry) {
                    int idx = entry.key;
                    String content = entry.value.trim();
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text('${idx + 1}', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSub, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(content, style: const TextStyle(color: AppColors.textSub, height: 1.5, fontSize: 14)),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Blurred background
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
            ),
          ),
          
          // Content
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      Text(
                        'Chi tiết lộ trình (${_currentIndex + 1}/${widget.sortedSemesters.length})',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48), // Balance for close button
                    ],
                  ),
                ),
                
                // PageView
                Expanded(
                  child: Row(
                    children: [
                      // Left Arrow
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 40),
                          onPressed: _currentIndex > 0 ? _goToPrevious : null,
                          disabledColor: Colors.white24,
                        ),
                      ),
                      
                      // Carousel
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentIndex = index;
                            });
                          },
                          itemCount: widget.sortedSemesters.length,
                          itemBuilder: (context, index) {
                            final semester = widget.sortedSemesters[index];
                            final subjects = widget.semesterGroups[semester]!;
                            final title = semester == 0 ? 'OJT / Prep' : 'Học kỳ $semester';
                            
                            return Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 800),
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 32),
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 40,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: subjects.length,
                                        padding: const EdgeInsets.only(bottom: 64),
                                        itemBuilder: (context, subIndex) {
                                          return _buildSubjectCard(subjects[subIndex]);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      
                      // Right Arrow
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 40),
                          onPressed: _currentIndex < widget.sortedSemesters.length - 1 ? _goToNext : null,
                          disabledColor: Colors.white24,
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
    );
  }
}
