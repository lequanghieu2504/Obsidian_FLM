import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

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
      width: 100,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBackground,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)), // slate-200
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
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
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
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primaryLighter,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  userName!.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
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
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: isSelected
            ? BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              )
            : null,
        child: Column(
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected ? Colors.white : AppColors.textSub,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
