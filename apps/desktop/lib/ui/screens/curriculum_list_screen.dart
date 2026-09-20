import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/curriculum.dart';
import '../../models/subject.dart';
import '../../app/theme/app_colors.dart';
import '../layouts/dashboard_layout.dart';
import 'curriculum_detail_screen.dart';
import 'curriculum_preview_screen.dart';

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
  String _searchQuery = '';
  String? _selectedCode;
  bool _isListView = false;

  List<Curriculum> get filteredList {
    if (_searchQuery.isEmpty) return widget.curricula;
    final q = _searchQuery.toLowerCase();
    return widget.curricula.where((c) {
      return c.code.toLowerCase().contains(q) ||
          c.name.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q);
    }).toList();
  }

  void _handleItemClick(Curriculum item) async {
    setState(() => _selectedCode = item.code);

    final file = File(
        '${Directory.current.path}/data/curriculum_detail_${item.code}.json');
    bool isCached = await file.exists();

    if (!mounted) return;

    // Luôn luôn vào màn hình Preview, để user xác nhận
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CurriculumPreviewScreen(curriculum: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Container(
          constraints:
              const BoxConstraints(maxWidth: 1000), // Responsive Max Width
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Setup 2
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.looks_two_rounded,
                            color: AppColors.primaryLight, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Thiết lập lần đầu, bước 2 trên 2',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color:
                                AppColors.primaryLight.withValues(alpha: 0.8),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Bạn học chuyên ngành nào?',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textMain,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textSub,
                            height: 1.5,
                            fontFamily: 'Segoe UI'),
                        children: [
                          const TextSpan(
                              text:
                                  'Chọn ngành để xem khung chương trình khóa '),
                          TextSpan(
                              text: widget.cohort,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMain)),
                          const TextSpan(
                              text:
                                  '. Bạn có thể đổi lại sau trong mục Đổi khóa hoặc ngành.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Search Bar & View Toggle
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          decoration: const InputDecoration(
                            hintText:
                                'Tìm chuyên ngành (VD: Kỹ thuật phần mềm)',
                            hintStyle: TextStyle(
                                color: AppColors.textSub, fontSize: 15),
                            prefixIcon: Icon(Icons.search_rounded,
                                color: AppColors.textSub),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.grid_view_rounded,
                                color: !_isListView
                                    ? AppColors.primary
                                    : AppColors.textSub),
                            onPressed: () =>
                                setState(() => _isListView = false),
                            tooltip: 'Lưới',
                          ),
                          IconButton(
                            icon: Icon(Icons.view_list_rounded,
                                color: _isListView
                                    ? AppColors.primary
                                    : AppColors.textSub),
                            onPressed: () => setState(() => _isListView = true),
                            tooltip: 'Danh sách',
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),

              // Grid / List View
              Expanded(
                child: filteredList.isEmpty
                    ? const Center(
                        child: Text('Không tìm thấy chuyên ngành nào.',
                            style: TextStyle(color: AppColors.textSub)),
                      )
                    : (_isListView ? _buildListView() : _buildGridView()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 60),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        mainAxisExtent: 180, // Đủ cao để hiển thị tự do và không bị overflow
      ),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        return _buildCardItem(filteredList[index]);
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 40),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildCardItem(filteredList[index]),
        );
      },
    );
  }

  Widget _buildCardItem(Curriculum item) {
    final isSelected = _selectedCode == item.code;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleItemClick(item),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryBg : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppColors.primary : AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.code,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isSelected ? Colors.white : AppColors.textMain,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.primary, size: 20)
                ],
              ),
              const SizedBox(height: 16),
              Text(
                item.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color:
                      isSelected ? AppColors.primaryDark : AppColors.textMain,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                item.description.isNotEmpty
                    ? item.description
                    : 'FPT University',
                style: const TextStyle(fontSize: 13, color: AppColors.textSub),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
