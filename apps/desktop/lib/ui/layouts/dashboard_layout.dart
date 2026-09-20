import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../widgets/app_sidebar.dart';
import '../../models/subject.dart';
import '../screens/curriculum_detail_screen.dart';
import '../screens/subjects_screen.dart';

class DashboardLayout extends StatefulWidget {
  final String curriculumCode;
  final List<Subject> subjects;
  final String? userName;

  const DashboardLayout({
    super.key,
    required this.curriculumCode,
    required this.subjects,
    this.userName,
  });

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  int _selectedIndex = 0;
  bool _isChatOpen = true;
  bool _isSidebarOpen = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // 1. Sidebar (Trái)
          AppSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            userName: widget.userName,
            isOpen: _isSidebarOpen,
            onToggle: () {
              setState(() => _isSidebarOpen = !_isSidebarOpen);
            },
          ),
          
          // 2. Main Content (Giữa)
          Expanded(
            child: Column(
              children: [
                // Topbar
                Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border(bottom: BorderSide(color: const Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _selectedIndex == 0 ? 'Tổng quan' : 'Quản lý môn học',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMain,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text('Dữ liệu mẫu', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _isChatOpen = !_isChatOpen);
                        },
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                        label: const Text('Trợ lý'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isChatOpen ? AppColors.primary : AppColors.surface,
                          foregroundColor: _isChatOpen ? Colors.white : AppColors.textMain,
                          elevation: 0,
                          side: BorderSide(color: _isChatOpen ? AppColors.primary : const Color(0xFFE2E8F0)),
                        ),
                      )
                    ],
                  ),
                ),
                // Nơi chứa màn hình thực tế (CurriculumDetailScreen, SubjectsScreen)
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      CurriculumDetailScreen(
                        curriculumCode: widget.curriculumCode,
                        subjects: widget.subjects,
                      ),
                      SubjectsScreen(
                        curriculumCode: widget.curriculumCode,
                        subjects: widget.subjects,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 3. Chatbot Panel (Phải)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: _isChatOpen ? 360 : 0,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: ClipRect(
              child: OverflowBox(
                minWidth: 360,
                maxWidth: 360,
                child: Column(
                  children: [
                    // Chat Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.smart_toy_rounded, color: AppColors.primary),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Trợ lý học vụ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textMain)),
                                Text('Dựa trên khung chương trình của bạn', style: TextStyle(fontSize: 12, color: AppColors.textSub)),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    // Chat Body (Mô phỏng)
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          _buildChatBubble('Chào bạn! Mình trả lời dựa trên khung chương trình ngành Kỹ thuật phần mềm. Bạn có thể hỏi về môn tiên quyết, số tín chỉ còn lại...', isBot: true),
                          const SizedBox(height: 16),
                          _buildChatBubble('Kỳ tới mình nên đăng ký những môn nào?', isBot: false),
                          const SizedBox(height: 16),
                          _buildChatBubble('Kỳ tới bạn nên ưu tiên đăng ký PRJ301 và SWR302 vì đây là các môn tiên quyết quan trọng cho SWP391 ở học kỳ 5.', isBot: true),
                        ],
                      ),
                    ),
                    // Chat Input
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildSuggestionChip('Kỳ tới nên học gì?'),
                              const SizedBox(width: 8),
                              _buildSuggestionChip('Còn bao nhiêu tín chỉ?'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Hỏi về môn học...',
                                      hintStyle: TextStyle(color: AppColors.textSub, fontSize: 14),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, {required bool isBot}) {
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isBot ? AppColors.background : AppColors.primary,
          borderRadius: BorderRadius.circular(16).copyWith(
            topLeft: isBot ? const Radius.circular(4) : const Radius.circular(16),
            bottomRight: !isBot ? const Radius.circular(4) : const Radius.circular(16),
          ),
          border: isBot ? Border.all(color: const Color(0xFFE2E8F0)) : null,
        ),
        child: Text(
          text,
          style: TextStyle(color: isBot ? AppColors.textMain : Colors.white, height: 1.5),
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSub, fontWeight: FontWeight.w500)),
    );
  }
}
