import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../screens/home_screen.dart';
import '../../utils/user_settings.dart';
import '../../models/curriculum_data.dart';
import '../../models/subject.dart';
import 'semester_tree_widget.dart';

class AppSidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final String? curriculumCode;
  final bool isOpen;
  final VoidCallback onToggle;
  final CurriculumData? curriculumData;
  final Function(Subject subject)? onSubjectSelected;
  final String? selectedSubjectCode;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.curriculumCode,
    required this.isOpen,
    required this.onToggle,
    this.curriculumData,
    this.onSubjectSelected,
    this.selectedSubjectCode,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  void _showSettingsDialog() {
    final TextEditingController nameController =
        TextEditingController(text: UserSettings.userName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Cài đặt thông tin',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tên của bạn:',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMain)),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'VD: Minh Anh',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Khóa & Ngành (Đọc từ dữ liệu):',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMain)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    widget.curriculumCode ?? 'Không có dữ liệu',
                    style: const TextStyle(
                        color: AppColors.textSub, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  const Text('Hủy', style: TextStyle(color: AppColors.textSub)),
            ),
            ElevatedButton(
              onPressed: () async {
                await UserSettings.saveUserName(nameController.text);
                setState(() {});
                if (context.mounted) Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Lưu thay đổi'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: widget.isOpen ? 260 : 80,
      color: AppColors.sidebarBackground,
      child: Column(
        children: [
          // Brand Logo & Toggle
          Padding(
            padding: const EdgeInsets.only(
                top: 32.0, bottom: 24.0, left: 16, right: 16),
            child: Row(
              mainAxisAlignment: widget.isOpen
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: Colors.white, size: 20),
                ),
                if (widget.isOpen) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Lộ Trình',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Toggle Button (Dễ nhìn hơn)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: InkWell(
              onTap: widget.onToggle,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Icon(
                  widget.isOpen
                      ? Icons.keyboard_double_arrow_left_rounded
                      : Icons.keyboard_double_arrow_right_rounded,
                  color: AppColors.textSub,
                  size: 20,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Navigation
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildNavItem(0, Icons.grid_view_rounded, 'Tổng quan'),
                    _buildNavItem(1, Icons.menu_book_rounded, 'Môn học'),
                    _buildNavItem(3, Icons.search_rounded, 'Khám phá'),
                    _buildNavItem(4, Icons.assessment_rounded, 'Bảng điểm'),
                    if (widget.isOpen && widget.curriculumData != null) ...[
                      const SizedBox(height: 12),
                      SemesterTreeWidget(
                        curriculumData: widget.curriculumData,
                        curriculumCode: widget.curriculumCode,
                        selectedSubjectCode: widget.selectedSubjectCode,
                        onSubjectTap: (subject) {
                          widget.onSubjectSelected?.call(subject);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // User Profile & Logout
          Container(
            padding: EdgeInsets.all(widget.isOpen ? 12 : 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: _showSettingsDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: widget.isOpen
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.settings_rounded,
                            color: AppColors.primary, size: 24),
                        if (widget.isOpen) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  UserSettings.userName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textMain),
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  softWrap: false,
                                ),
                                Text(
                                  widget.curriculumCode ?? 'Chưa rõ',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.textSub),
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  softWrap: false,
                                ),
                              ],
                            ),
                          )
                        ]
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) =>
                            const HomeScreen(forceShowUpload: true),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.textSub,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: widget.isOpen
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.swap_horiz_rounded, size: 16),
                            SizedBox(width: 8),
                            Text('Đổi khóa / ngành'),
                          ],
                        )
                      : const Icon(Icons.swap_horiz_rounded, size: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String title,
      {String? badge}) {
    final isSelected = widget.selectedIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onItemSelected(index),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
                horizontal: widget.isOpen ? 16 : 0, vertical: 12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: widget.isOpen
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  scale: isSelected ? 1.1 : 1.0,
                  child: Icon(
                    icon,
                    color: isSelected ? AppColors.primary : AppColors.textSub,
                    size: 20,
                  ),
                ),
                if (widget.isOpen) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color:
                            isSelected ? AppColors.textMain : AppColors.textSub,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                    ),
                  ),
                  if (badge != null)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryBg
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSub,
                        ),
                      ),
                    )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
