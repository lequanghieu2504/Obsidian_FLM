import 'package:flutter/material.dart';
import '../features/subjects/presentation/subject_catalog_screen.dart';

class ObsidianFlmApp extends StatelessWidget {
  const ObsidianFlmApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Obsidian FLM',
        theme: ThemeData(
          colorScheme:
              ColorScheme.fromSeed(seedColor: const Color(0xFF4355B9)),
          useMaterial3: true,
        ),
        home: const SubjectCatalogScreen(curriculumCode: 'BIT_SE_K19B'),
      );
}
