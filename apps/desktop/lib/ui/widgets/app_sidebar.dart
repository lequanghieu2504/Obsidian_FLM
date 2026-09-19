import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final String? userName;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBackground,
        // Viền nhạt tạo cảm giác nổi
        border: Border(right: BorderSide(color: Color(0xFFE0E0E0), width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Logo placeholder
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.getGradient(0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.menu_book, color: Colors.white),
          ),
          const SizedBox(height: 48),
          
          // Menu Items
          _buildMenuItem(0, Icons.dashboard_rounded, 'Dashboard'),
          _buildMenuItem(1, Icons.calendar_month_rounded, 'Calendar'),
          _buildMenuItem(2, Icons.book_rounded, 'Subjects'),
          
          const Spacer(),
          
          // User Avatar
          if (userName != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.getGradient(2).colors.first,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  userName!.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              userName!.split(' ').last,
              style: const TextStyle(fontSize: 12, color: AppColors.textMain, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 32),
          ]
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index, IconData icon, String label) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onItemSelected(index),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? AppColors.getGradient(0).colors.first : AppColors.textSub.withOpacity(0.5),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.getGradient(0).colors.first : AppColors.textSub.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
