import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../widgets/app_sidebar.dart';
import '../../models/curriculum_data.dart';
import '../screens/curriculum_detail_screen.dart';
import '../screens/subjects_screen.dart';
import '../screens/explore_curriculums_screen.dart';
import '../screens/transcript_screen.dart';
import '../widgets/chat_box.dart';
import '../widgets/pane_resize_handle.dart';

class DashboardLayout extends StatefulWidget {
  final CurriculumData curriculumData;
  final String? userName;

  const DashboardLayout({
    super.key,
    required this.curriculumData,
    this.userName,
  });

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  final GlobalKey _chatBoxKey = GlobalKey();
  int _selectedIndex = 0;
  int _lastMainIndex = 0; // Lưu vết màn hình chính trước khi mở chat
  bool _isChatOverlay = true;
  bool _isSidebarOpen = true;

  // Width of the AI drawer; the user can drag its left edge to resize it.
  static const double _minChatWidth = 320;
  double _chatWidth = 380;
  bool _resizingChat = false;

  double _maxChatWidth(BuildContext context) =>
      (MediaQuery.sizeOf(context).width * 0.7).clamp(_minChatWidth, double.infinity);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // 1. Sidebar (Trái)
          AppSidebar(
            // Keep the current screen highlighted while the AI panel is open.
            selectedIndex: _lastMainIndex,
            onItemSelected: (index) {
              setState(() {
                if (index == 2) {
                  _selectedIndex = 2;
                } else {
                  _selectedIndex = index;
                  _lastMainIndex = index;
                }
              });
            },
            curriculumCode:
                widget.curriculumData.metadata['curriculumCode']?.toString(),
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
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    border: Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _selectedIndex == 2 && !_isChatOverlay
                            ? 'Trợ lý học vụ'
                            : _lastMainIndex == 0
                                ? 'Tổng quan'
                                : _lastMainIndex == 1
                                    ? 'Quản lý môn học'
                                    : _lastMainIndex == 3
                                        ? 'Khám phá chuyên ngành'
                                        : 'Quản lý điểm',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMain,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            if (_selectedIndex == 2) {
                              _selectedIndex = _lastMainIndex;
                            } else {
                              _selectedIndex = 2;
                              _isChatOverlay = true; // Default to overlay when using topbar button
                            }
                          });
                        },
                        icon: const Icon(Icons.chat_bubble_outline_rounded,
                            size: 18),
                        label: const Text('Trợ lý'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedIndex == 2
                              ? AppColors.primary
                              : AppColors.surface,
                          foregroundColor:
                              _selectedIndex == 2 ? Colors.white : AppColors.textMain,
                          elevation: 0,
                          side: BorderSide(
                              color: _selectedIndex == 2
                                  ? AppColors.primary
                                  : const Color(0xFFE2E8F0)),
                        ),
                      )
                    ],
                  ),
                ),
                // Nơi chứa màn hình thực tế (CurriculumDetailScreen, SubjectsScreen)
                Expanded(
                  child: _selectedIndex == 2 && !_isChatOverlay 
                    // Fullscreen Chat Mode
                    ? ChatBox(
                        key: _chatBoxKey,
                        curriculumData: widget.curriculumData,
                        isOverlay: false,
                        onToggleMode: () {
                          setState(() => _isChatOverlay = true);
                        },
                        onClose: () {
                          setState(() => _selectedIndex = _lastMainIndex);
                        },
                      )
                    // Normal Main Screen
                    : IndexedStack(
                        index: _lastMainIndex,
                        children: [
                          CurriculumDetailScreen(
                            curriculumData: widget.curriculumData,
                          ),
                          // Subject list from feature/curriculum-and-transcript;
                          // tapping a subject opens the detail page from
                          // lib/features/subjects (SubjectDetailScreen).
                          SubjectsScreen(
                            curriculumData: widget.curriculumData,
                          ),
                          const SizedBox.shrink(), // Index 2 is Chat
                          const ExploreCurriculumsScreen(),
                          const TranscriptScreen(),
                        ],
                      ),
                ),
              ],
            ),
          ),

          // 3. Chatbot Panel (Overlay Drawer)
          if (_selectedIndex == 2 && _isChatOverlay)
            PaneResizeHandle(
              onDragStart: () => setState(() => _resizingChat = true),
              onDragEnd: () => setState(() => _resizingChat = false),
              // Handle sits on the drawer's left edge: dragging left widens it.
              onDrag: (dx) => setState(() {
                _chatWidth = (_chatWidth - dx)
                    .clamp(_minChatWidth, _maxChatWidth(context));
              }),
            ),
          AnimatedContainer(
            duration: _resizingChat
                ? Duration.zero
                : const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: (_selectedIndex == 2 && _isChatOverlay)
                ? _chatWidth.clamp(_minChatWidth, _maxChatWidth(context))
                : 0,
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: ClipRect(
              child: (_selectedIndex == 2 && _isChatOverlay) 
                ? ChatBox(
                    key: _chatBoxKey,
                    curriculumData: widget.curriculumData,
                    isOverlay: true,
                    onToggleMode: () {
                      setState(() => _isChatOverlay = false);
                    },
                    onClose: () {
                      setState(() => _selectedIndex = _lastMainIndex);
                    },
                  )
                : const SizedBox.shrink(),
            ),
          )
        ],
      ),
    );
  }
}
