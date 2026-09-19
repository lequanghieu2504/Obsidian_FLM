import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../widgets/app_sidebar.dart';

class DashboardLayout extends StatefulWidget {
  final Widget child;
  final String? userName;

  const DashboardLayout({
    super.key,
    required this.child,
    this.userName,
  });

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isRightPanelOpen = true;
  late TabController _rightPanelTabController;

  @override
  void initState() {
    super.initState();
    _rightPanelTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _rightPanelTabController.dispose();
    super.dispose();
  }

  void _toggleRightPanel() {
    setState(() {
      _isRightPanelOpen = !_isRightPanelOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Left Sidebar
          AppSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            userName: widget.userName,
          ),
          
          // Main Content Area
          Expanded(
            child: Stack(
              children: [
                Column(
                  children: [
                    // Top App Bar
                    Container(
                      height: 80,
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Dashboard',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textSub),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                onPressed: _toggleRightPanel,
                                icon: Icon(
                                  _isRightPanelOpen ? Icons.close_fullscreen_rounded : Icons.open_in_new_rounded,
                                  color: AppColors.primary,
                                ),
                                tooltip: 'Toggle Sidebar',
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                    
                    // Main Scrollable Content
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(left: 32, right: 32, bottom: 32),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.03),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Right Panel (Collapsible)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: _isRightPanelOpen ? 340 : 0,
            decoration: const BoxDecoration(
              color: AppColors.rightPanelBackground,
              border: Border(left: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
            ),
            child: ClipRect(
              child: _isRightPanelOpen
                  ? Column(
                      children: [
                        const SizedBox(height: 24),
                        // Tabs
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.sidebarBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TabBar(
                              controller: _rightPanelTabController,
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              indicator: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              labelColor: AppColors.primary,
                              unselectedLabelColor: AppColors.textSub,
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              tabs: const [
                                Tab(text: 'Trợ lý học vụ'),
                                Tab(text: 'Calendar'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: TabBarView(
                            controller: _rightPanelTabController,
                            children: [
                              _buildChatbotTab(),
                              _buildCalendarTab(),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChatbotTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              children: [
                _buildChatBubble('Chào bạn! Mình trả lời dựa trên khung chương trình K19 SE. Bạn cần hỏi gì?', isBot: true),
                const SizedBox(height: 16),
                _buildChatBubble('Môn PRJ301 cần học môn gì trước?', isBot: false),
                const SizedBox(height: 16),
                _buildChatBubble('PRJ301 (Java Web) yêu cầu học trước PRO192 (Lập trình hướng đối tượng Java) và DBI202 (Cơ sở dữ liệu).', isBot: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Chat input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primaryLighter),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Hỏi trợ lý...',
                      hintStyle: TextStyle(color: AppColors.textSub, fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                  onPressed: () {},
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, {required bool isBot}) {
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isBot ? AppColors.surface : AppColors.primary,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: isBot ? const Radius.circular(4) : null,
            bottomRight: !isBot ? const Radius.circular(4) : null,
          ),
          boxShadow: isBot
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isBot ? AppColors.textMain : AppColors.textInverse,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarTab() {
    return const Center(
      child: Text(
        'Calendar / Contacts coming soon...',
        style: TextStyle(color: AppColors.textSub),
      ),
    );
  }
}
