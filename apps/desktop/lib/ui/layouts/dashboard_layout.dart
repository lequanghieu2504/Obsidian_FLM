import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/app_tab_bar.dart';
import '../../models/curriculum_data.dart';
import '../../models/subject.dart';
import '../screens/curriculum_detail_screen.dart';
import '../screens/subjects_screen.dart';
import '../screens/explore_curriculums_screen.dart';
import '../screens/transcript_screen.dart';
import '../../features/subjects/presentation/subject_detail_screen.dart';
import '../../features/knowledge_graph/presentation/subject_knowledge_graph_tab.dart';
import '../widgets/chat_box.dart';
import '../widgets/pane_resize_handle.dart';
import '../widgets/min_width_guard.dart';

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
  int _lastMainIndex = 0;
  bool _isChatOverlay = true;
  bool _isSidebarOpen = true;

  // Browser Tabs state
  late List<AppTabModel> _tabs;
  int _activeTabIndex = 0;
  String? _selectedSubjectCode;

  // History stack for back/forward navigation
  final List<int> _tabHistory = [];
  int _historyPointer = -1;

  static const double _minChatWidth = 320;
  double _chatWidth = 380;
  bool _resizingChat = false;

  static const double _minMainWidth = 760;

  @override
  void initState() {
    super.initState();
    final curriculumCode =
        widget.curriculumData.metadata['curriculumCode']?.toString() ??
            'BIT_SE';

    _tabs = [
      AppTabModel(
        id: 'overview',
        title: 'Khung chương trình & Môn học',
        icon: Icons.grid_view_rounded,
        isCloseable: false,
      ),
      AppTabModel(
        id: 'graph',
        title: 'Đồ thị tri thức (Graph view)',
        icon: Icons.hub_rounded,
        isCloseable: true,
      ),
    ];
    _tabHistory.add(0);
    _historyPointer = 0;
  }

  void _addToHistory(int index) {
    if (_historyPointer >= 0 &&
        _historyPointer < _tabHistory.length &&
        _tabHistory[_historyPointer] == index) {
      return;
    }
    if (_historyPointer < _tabHistory.length - 1) {
      _tabHistory.removeRange(_historyPointer + 1, _tabHistory.length);
    }
    _tabHistory.add(index);
    _historyPointer = _tabHistory.length - 1;
  }

  void _navigateBack() {
    if (_historyPointer > 0) {
      setState(() {
        _historyPointer--;
        _activeTabIndex = _tabHistory[_historyPointer].clamp(0, _tabs.length - 1);
        _selectedSubjectCode = _tabs[_activeTabIndex].subject?.code;
      });
    }
  }

  void _navigateForward() {
    if (_historyPointer < _tabHistory.length - 1) {
      setState(() {
        _historyPointer++;
        _activeTabIndex = _tabHistory[_historyPointer].clamp(0, _tabs.length - 1);
        _selectedSubjectCode = _tabs[_activeTabIndex].subject?.code;
      });
    }
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    setState(() {
      _activeTabIndex = index;
      _selectedSubjectCode = _tabs[index].subject?.code;
      _addToHistory(index);
    });
  }

  void _openSubjectTab(Subject subject) {
    final tabId = 'subject_${subject.code}';
    final existingIndex = _tabs.indexWhere((t) => t.id == tabId);

    if (existingIndex != -1) {
      _selectTab(existingIndex);
    } else {
      final newTab = AppTabModel(
        id: tabId,
        title: '${subject.code} - ${subject.name}',
        icon: Icons.article_rounded,
        isCloseable: true,
        subject: subject,
      );
      setState(() {
        _tabs.add(newTab);
        _activeTabIndex = _tabs.length - 1;
        _selectedSubjectCode = subject.code;
        _addToHistory(_activeTabIndex);
      });
    }
  }

  void _closeTab(AppTabModel tab) {
    final index = _tabs.indexOf(tab);
    if (index == -1 || !tab.isCloseable) return;

    setState(() {
      _tabs.removeAt(index);
      if (_activeTabIndex >= _tabs.length) {
        _activeTabIndex = _tabs.length - 1;
      }
      _selectedSubjectCode = _tabs[_activeTabIndex].subject?.code;
      _addToHistory(_activeTabIndex);
    });
  }

  void _showAddTabDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final curriculumCode =
            widget.curriculumData.metadata['curriculumCode']?.toString() ??
                'BIT_SE';
        String search = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredSubjects = widget.curriculumData.subjects.where((s) {
              final query = search.toLowerCase();
              return s.code.toLowerCase().contains(query) ||
                  s.name.toLowerCase().contains(query);
            }).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Mở Tab mới',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
              ),
              content: SizedBox(
                width: 440,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Tìm môn học (VD: CSD201, PRJ301)...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (val) => setDialogState(() => search = val),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.hub_rounded, size: 16),
                            label: const Text('Đồ thị tri thức'),
                            onPressed: () {
                              Navigator.pop(context);
                              _openCustomTab(
                                'graph',
                                'Đồ thị tri thức (Graph view)',
                                Icons.hub_rounded,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            avatar: const Icon(Icons.assessment_rounded, size: 16),
                            label: const Text('Bảng điểm'),
                            onPressed: () {
                              Navigator.pop(context);
                              _openCustomTab(
                                'transcript',
                                'Quản lý điểm',
                                Icons.assessment_rounded,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            avatar: const Icon(Icons.search_rounded, size: 16),
                            label: const Text('Khám phá'),
                            onPressed: () {
                              Navigator.pop(context);
                              _openCustomTab(
                                'explore',
                                'Khám phá chuyên ngành',
                                Icons.search_rounded,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 20),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filteredSubjects.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final subject = filteredSubjects[index];
                          return ListTile(
                            leading: const Icon(Icons.description_outlined, color: AppColors.primary),
                            title: Text(
                              '${subject.code} - ${subject.name}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            subtitle: Text('Học kỳ ${subject.semester} · ${subject.credits} TC'),
                            onTap: () {
                              Navigator.pop(context);
                              _openSubjectTab(subject);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openCustomTab(String id, String title, IconData icon) {
    final existingIndex = _tabs.indexWhere((t) => t.id == id);
    if (existingIndex != -1) {
      _selectTab(existingIndex);
    } else {
      final newTab = AppTabModel(
        id: id,
        title: title,
        icon: icon,
        isCloseable: true,
      );
      setState(() {
        _tabs.add(newTab);
        _activeTabIndex = _tabs.length - 1;
        _selectedSubjectCode = null;
        _addToHistory(_activeTabIndex);
      });
    }
  }

  double _maxChatWidth(BuildContext context) {
    final sidebar = _isSidebarOpen ? 260.0 : 80.0;
    final max = MediaQuery.sizeOf(context).width - sidebar - 12 - _minMainWidth;
    return max < _minChatWidth ? _minChatWidth : max;
  }

  Widget _buildActiveTabContent() {
    if (_activeTabIndex < 0 || _activeTabIndex >= _tabs.length) {
      return CurriculumDetailScreen(curriculumData: widget.curriculumData);
    }

    final activeTab = _tabs[_activeTabIndex];
    final curriculumCode =
        widget.curriculumData.metadata['curriculumCode']?.toString() ??
            'BIT_SE';

    if (activeTab.subject != null) {
      return SubjectDetailScreen(
        key: ValueKey('subject-tab-${activeTab.subject!.code}'),
        curriculumCode: curriculumCode,
        subject: activeTab.subject!,
      );
    }

    switch (activeTab.id) {
      case 'graph':
        // Primary subject code for Knowledge Graph Tab
        final firstSubjectCode = widget.curriculumData.subjects.isNotEmpty
            ? widget.curriculumData.subjects.first.code
            : 'CSD201';
        return SubjectKnowledgeGraphTab(
          key: ValueKey('graph-tab-$firstSubjectCode'),
          subjectCode: firstSubjectCode,
        );
      case 'explore':
        return const ExploreCurriculumsScreen();
      case 'transcript':
        return const TranscriptScreen();
      case 'subjects_screen':
        return SubjectsScreen(
          curriculumData: widget.curriculumData,
          onOpenSubjectTab: _openSubjectTab,
        );
      case 'overview':
      default:
        return CurriculumDetailScreen(
          curriculumData: widget.curriculumData,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // 1. Sidebar (Trái) - Tích hợp Cây môn học chia theo Học kỳ
          AppSidebar(
            selectedIndex: _lastMainIndex,
            curriculumData: widget.curriculumData,
            curriculumCode:
                widget.curriculumData.metadata['curriculumCode']?.toString(),
            isOpen: _isSidebarOpen,
            selectedSubjectCode: _selectedSubjectCode,
            onSubjectSelected: _openSubjectTab,
            onToggle: () {
              setState(() => _isSidebarOpen = !_isSidebarOpen);
            },
            onItemSelected: (index) {
              setState(() {
                if (index == 2) {
                  _selectedIndex = 2;
                } else if (index == 0) {
                  _selectedIndex = 0;
                  _lastMainIndex = 0;
                  _selectTab(0); // Switch to Overview tab
                } else if (index == 1) {
                  _selectedIndex = 1;
                  _lastMainIndex = 1;
                  _openCustomTab('subjects_screen', 'Quản lý môn học', Icons.menu_book_rounded);
                } else if (index == 3) {
                  _selectedIndex = 3;
                  _lastMainIndex = 3;
                  _openCustomTab('explore', 'Khám phá chuyên ngành', Icons.search_rounded);
                } else if (index == 4) {
                  _selectedIndex = 4;
                  _lastMainIndex = 4;
                  _openCustomTab('transcript', 'Quản lý điểm', Icons.assessment_rounded);
                }
              });
            },
          ),

          // 2. Main Content (Giữa) - Tích hợp Thanh Tab kiểu Trình duyệt ở trên cùng
          Expanded(
            child: MinWidthGuard(
              minWidth: _minMainWidth,
              child: Column(
                children: [
                  // Topbar Browser Tabs
                  AppTabBar(
                    tabs: _tabs,
                    activeIndex: _activeTabIndex,
                    canGoBack: _historyPointer > 0,
                    canGoForward: _historyPointer < _tabHistory.length - 1,
                    onGoBack: _navigateBack,
                    onGoForward: _navigateForward,
                    onTabSelected: _selectTab,
                    onTabClosed: _closeTab,
                    onAddTab: _showAddTabDialog,
                  ),

                  // Active Tab Content Viewport
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final slide = Tween<Offset>(
                          begin: const Offset(0.015, 0),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: slide,
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<String>(
                          _selectedIndex == 2 && !_isChatOverlay
                              ? 'fullscreen-chat'
                              : 'tab-${_activeTabIndex < _tabs.length ? _tabs[_activeTabIndex].id : _activeTabIndex}',
                        ),
                        child: _selectedIndex == 2 && !_isChatOverlay
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
                            : _buildActiveTabContent(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Chatbot Panel (Overlay Drawer)
          if (_selectedIndex == 2 && _isChatOverlay)
            PaneResizeHandle(
              onDragStart: () => setState(() => _resizingChat = true),
              onDragEnd: () => setState(() => _resizingChat = false),
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
                  ? OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: _chatWidth.clamp(_minChatWidth, _maxChatWidth(context)),
                      maxWidth: _chatWidth.clamp(_minChatWidth, _maxChatWidth(context)),
                      child: ChatBox(
                        key: _chatBoxKey,
                        curriculumData: widget.curriculumData,
                        isOverlay: true,
                        onToggleMode: () {
                          setState(() => _isChatOverlay = false);
                        },
                        onClose: () {
                          setState(() => _selectedIndex = _lastMainIndex);
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          )
        ],
      ),
    );
  }
}
