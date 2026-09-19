import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
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

class _DashboardLayoutState extends State<DashboardLayout> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sidebarBackground, // Nền cho toàn app
      body: Row(
        children: [
          // Cột 1: Sidebar
          AppSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            userName: widget.userName,
          ),
          
          // Cột 2: Main Content (Trắng tinh, bo tròn)
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16), // Thêm horizontal margin
              padding: const EdgeInsets.all(32), // Thêm padding cho nội dung bên trong
              decoration: BoxDecoration(
                color: AppColors.mainContentBackground,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: widget.child,
            ),
          ),
          
          // Cột 3: Right Panel (Mờ nhạt, Activity / To-do)
          Container(
            width: 320,
            color: AppColors.rightPanelBackground,
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 24),
                _buildActivityItem(Icons.sync_rounded, 'Synchronized', 'K19B Curriculum loaded'),
                _buildActivityItem(Icons.login_rounded, 'Logged in', 'Via Google Account'),
                
                const SizedBox(height: 48),
                const Text(
                  "To Do's",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 24),
                _buildTodoItem('Choose a major to scrape', true),
                _buildTodoItem('Wait for background scraper', false),
                _buildTodoItem('View Curriculum Details', false),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActivityItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.getGradient(0).colors.first.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.getGradient(0).colors.first, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTodoItem(String text, bool isDone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isDone ? Colors.green : AppColors.textSub.withOpacity(0.5),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDone ? AppColors.textSub : AppColors.textMain,
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
