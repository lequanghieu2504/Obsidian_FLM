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
      other is AppTabModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

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
  final VoidCallback? onToggleAssistant;
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
    this.onToggleAssistant,
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
          const SizedBox(width: 6),

          // Always Visible [ 💬 Trợ lý ] Button on Top-Right Corner
          if (onToggleAssistant != null) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggleAssistant,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 15,
                        color: Color(0xFF334155),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Trợ lý',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildBrowserTab(BuildContext context, int index, AppTabModel tab) {
    final isActive = index == activeIndex;
    final textStyle = TextStyle(
      fontSize: 12,
      fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
      color: isActive ? const Color(0xFF0F172A) : const Color(0xFF334155),
      inherit: false,
    );
    final iconColor = isActive ? AppColors.primary : const Color(0xFF475569);

    return GestureDetector(
      onTap: () => onTabSelected(index),
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 180,
          height: 36,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : const Color(0xFFCBD5E1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, -1),
                    ),
                  ]
                : null,
            // A rounded BoxDecoration cannot paint borders with different
            // colors. Keep this border uniform and draw the blue active
            // indicator as a separate child below.
            border: isActive
                ? Border.all(color: const Color(0xFFCBD5E1))
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SizedBox(
                height: 2.5,
                width: double.infinity,
                child: ColoredBox(
                  color: isActive ? AppColors.primary : Colors.transparent,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 3.5, 10, 5),
                  child: DefaultTextStyle(
                    style: textStyle,
                    child: IconTheme(
                      data: IconThemeData(color: iconColor, size: 15),
                      child: Row(
                        children: [
                          Icon(tab.icon, size: 15, color: iconColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              tab.title,
                              style: textStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (tab.isCloseable) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => onTabClosed(tab),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: isActive
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
