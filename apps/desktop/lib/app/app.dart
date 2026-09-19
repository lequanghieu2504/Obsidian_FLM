import 'package:flutter/material.dart';
import '../ui/screens/home_screen.dart';

class ObsidianFlmApp extends StatelessWidget {
  const ObsidianFlmApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
        title: 'Obsidian FLM',
        home: HomeScreen(),
      );
}
