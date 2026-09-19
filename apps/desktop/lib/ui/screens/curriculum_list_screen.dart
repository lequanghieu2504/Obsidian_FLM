import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/curriculum.dart';
import '../../models/subject.dart';
import '../../utils/custom_toast.dart';
import '../../utils/html_parser.dart';
import '../../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_card.dart';
import 'subject_scraping_screen.dart';
import 'curriculum_detail_screen.dart';

class CurriculumListScreen extends StatefulWidget {
  final List<Curriculum> curricula;
  final String cohort;

  const CurriculumListScreen({
    super.key,
    required this.curricula,
    required this.cohort,
  });

  @override
  State<CurriculumListScreen> createState() => _CurriculumListScreenState();
}

class _CurriculumListScreenState extends State<CurriculumListScreen> {
  bool _isGridView = true;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    // Filter list
    final filteredList = widget.curricula.where((c) {
      return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
             c.code.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent, // Để lộ nền của DashboardLayout
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Curriculum List',
                      style: TextStyle(
                        fontFamily: 'Segoe UI',
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textMain,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select your major for cohort ${widget.cohort}',
                      style: const TextStyle(
                        fontFamily: 'Segoe UI',
                        fontSize: 16,
                        color: AppColors.textSub,
                      ),
                    ),
                  ],
                ),
                // Thanh công cụ: Tìm kiếm & Đổi View
                Row(
                  children: [
                    Container(
                      width: 250,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search majors...',
                          hintStyle: TextStyle(fontFamily: 'Segoe UI', color: AppColors.textSub.withOpacity(0.5), fontSize: 14),
                          prefixIcon: const Icon(Icons.search, color: AppColors.textSub, size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.grid_view_rounded),
                            color: _isGridView ? AppColors.getGradient(0).colors.first : AppColors.textSub,
                            onPressed: () => setState(() => _isGridView = true),
                            tooltip: 'Grid View',
                          ),
                          Container(width: 1, height: 24, color: Colors.grey.withOpacity(0.2)),
                          IconButton(
                            icon: const Icon(Icons.view_list_rounded),
                            color: !_isGridView ? AppColors.getGradient(0).colors.first : AppColors.textSub,
                            onPressed: () => setState(() => _isGridView = false),
                            tooltip: 'List View',
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
          
          // Danh sách Ngành
          Expanded(
            child: filteredList.isEmpty
                ? const Center(child: Text('No curricula found.', style: TextStyle(fontFamily: 'Segoe UI')))
                : _isGridView 
                    ? _buildGridView(filteredList)
                    : _buildListView(filteredList),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(List<Curriculum> list) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 24, right: 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 1.1,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return GradientCard(
          gradient: AppColors.getGradient(index),
          title: item.name,
          subtitle: item.description,
          badgeText: item.code,
          onTap: () => _handleItemClick(item),
        );
      },
    );
  }

  Widget _buildListView(List<Curriculum> list) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24, right: 16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = list[index];
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: ListTile(
            onTap: () => _handleItemClick(item),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.withOpacity(0.1)),
            ),
            tileColor: Colors.white,
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.getGradient(index),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.school_rounded, color: Colors.white),
              ),
            ),
            title: Text(
              item.name,
              style: const TextStyle(fontFamily: 'Segoe UI', fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textMain),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                item.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Segoe UI', color: AppColors.textSub),
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.getGradient(index).colors.first.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                item.code,
                style: TextStyle(
                  fontFamily: 'Segoe UI',
                  color: AppColors.getGradient(index).colors.first,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleItemClick(Curriculum item) async {
    // Kiem tra xem data mon hoc da ton tai chua
    final file = File('\${Directory.current.path}/data/curriculum_detail_\${item.code}.json');
    if (await file.exists()) {
      try {
        final jsonStr = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        final subjects = jsonList.map((e) => Subject.fromJson(e)).toList();
        
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CurriculumDetailScreen(
              curriculumCode: item.code,
              subjects: subjects,
            ),
          ),
        );
        return; // Dừng lại, không hiện Dialog nữa
      } catch (e) {
        debugPrint('Error loading saved curriculum detail: \$e');
      }
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                )
              ]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.getGradient(0).colors.first.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.code,
                        style: TextStyle(
                          fontFamily: 'Segoe UI',
                          color: AppColors.getGradient(0).colors.first,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textSub),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    )
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  item.name,
                  style: const TextStyle(
                    fontFamily: 'Segoe UI',
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textMain,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Description',
                  style: TextStyle(
                    fontFamily: 'Segoe UI',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontFamily: 'Segoe UI',
                    fontSize: 14,
                    color: AppColors.textSub,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop(); // Đóng dialog bằng dialogContext
                      
                      if (!mounted) return;
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => SubjectScrapingScreen(
                            detailUrl: item.detailUrl,
                            curriculumCode: item.code,
                          ),
                        ),
                      );

                      if (!mounted) return;

                      if (result == 'SUCCESS') {
                        CustomToast.show(context, 'Đã tải xong HTML chi tiết của ${item.code}!');
                        
                        try {
                          // Đọc file HTML
                          final file = File('curriculum_detail_${item.code}.html');
                          final htmlStr = await file.readAsString();
                          
                          // Parse HTML thành danh sách Môn học
                          final subjects = HtmlParser.parseCurriculumDetail(htmlStr);
                          
                          // Lưu vào Local Storage
                          await StorageService().saveCurriculumDetails(item.code, subjects);
                          
                          // Xóa file HTML thừa
                          await file.delete();
                          
                          if (!mounted) return;
                          
                          // Chuyển sang màn hình Roadmap
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => CurriculumDetailScreen(
                                curriculumCode: item.code,
                                subjects: subjects,
                              ),
                            ),
                          );
                        } catch (e) {
                          CustomToast.show(context, 'Lỗi khi xử lý dữ liệu: \$e', isError: true);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.getGradient(0).colors.first,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Select Major & Scrape Subjects', style: TextStyle(fontFamily: 'Segoe UI', fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
