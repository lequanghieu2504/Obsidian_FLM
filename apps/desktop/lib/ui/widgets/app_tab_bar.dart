import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../models/subject.dart';

class AppTabModel {
  final String id;
  final String title;
  final IconData icon;
  final bool isCloseable;
  final Subject? subject;

  AppTabModel({
    required this.id,
    required this.title,
    required this.icon,
    this.isCloseable = true,
    this.subject,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppTabModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class AppTabBar extends StatelessWidget {
  final List<AppTabModel> tabs;
  final int activeIndex;
  final Function(int index) onTabSelected;
  final Function(AppTabModel tab) onTabClosed;
  final VoidCallback onAddTab;
  final VoidCallback? onGoBack;
  final VoidCallback? onGoForward;
  final bool canGoBack;
  final bool canGoForward;

  const AppTabBar({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onTabSelected,
    required this.onTabClosed,
    required this.onAddTab,
    this.onGoBack,
    this.onGoForward,
    this.canGoBack = false,
    this.canGoForward = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: const BoxDecoration(
        color: Color(0xFFE2E8F0),
        border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
      ),
      child: Row(
        children: [
          // Back & Forward Navigation Controls
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            onPressed: canGoBack ? onGoBack : null,
            tooltip: 'Trở về',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            color: canGoBack ? AppColors.textMain : const Color(0xFF94A3B8),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            onPressed: canGoForward ? onGoForward : null,
            tooltip: 'Tiếp tục',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            color: canGoForward ? AppColors.textMain : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 4),

          // Scrollable Browser Tabs List
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    _buildBrowserTab(context, i, tabs[i]),
                ],
              ),
            ),
          ),

          // Add Tab Button (+)
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 18),
            onPressed: onAddTab,
            tooltip: 'Mở Tab mới',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            color: AppColors.textMain,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildBrowserTab(BuildContext context, int index, AppTabModel tab) {
    final isActive = index == activeIndex;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTabSelected(index),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
          margin: const EdgeInsets.only(right: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : const Color(0xFFCBD5E1).withOpacity(0.6),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                    )
                  ]
                : null,
            border: isActive
                ? const Border(
                    top: BorderSide(color: AppColors.primary, width: 2.5),
                    left: BorderSide(color: Color(0xFFCBD5E1)),
                    right: BorderSide(color: Color(0xFFCBD5E1)),
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                tab.icon,
                size: 15,
                color: isActive ? AppColors.primary : const Color(0xFF475569),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tab.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    color: isActive ? const Color(0xFF0F172A) : const Color(0xFF334155),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (tab.isCloseable) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => onTabClosed(tab),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: isActive ? const Color(0xFF64748B) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
