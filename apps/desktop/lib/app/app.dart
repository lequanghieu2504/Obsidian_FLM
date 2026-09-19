import 'package:flutter/material.dart';
import '../ui/screens/home_screen.dart';
import 'theme/app_theme.dart';

class ObsidianFlmApp extends StatelessWidget {
  const ObsidianFlmApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Obsidian FLM',
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
      );
}
