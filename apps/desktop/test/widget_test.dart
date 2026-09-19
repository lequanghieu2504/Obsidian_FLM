// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:obsidian_flm_desktop/app/app.dart';

void main() {
  testWidgets('Smoke test for HomeScreen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ObsidianFlmApp());

    // Verify that our app shows the 'Đăng nhập' button.
    expect(find.text('Đăng nhập'), findsOneWidget);
  });
}
