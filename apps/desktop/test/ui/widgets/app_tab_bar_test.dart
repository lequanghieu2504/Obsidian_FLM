import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_flm_desktop/ui/widgets/app_tab_bar.dart';

void main() {
  testWidgets('active browser tab keeps its label and icon visible', (
    tester,
  ) async {
    const activeTitle = 'Môn học đang mở';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTabBar(
            tabs: [
              AppTabModel(
                id: 'overview',
                title: 'Khung chương trình',
                icon: Icons.grid_view_rounded,
                isCloseable: false,
              ),
              AppTabModel(
                id: 'subject',
                title: activeTitle,
                icon: Icons.article_rounded,
              ),
            ],
            activeIndex: 1,
            onTabSelected: (_) {},
            onTabClosed: (_) {},
            onAddTab: () {},
          ),
        ),
      ),
    );

    final activeLabel = tester.widget<Text>(find.text(activeTitle));
    expect(activeLabel.style?.color, const Color(0xFF0F172A));
    expect(find.byIcon(Icons.article_rounded), findsOneWidget);
    expect(tester.getSize(find.text(activeTitle)).height, greaterThan(0));
  });
}
