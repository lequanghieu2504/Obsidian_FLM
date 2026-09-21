import 'package:flutter/material.dart';
import '../features/subjects/presentation/subject_catalog_screen.dart';

import '../features/knowledge_graph/presentation/knowledge_graph_page.dart';

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
        home: const _HomeMenu(),
      );
}

/// Landing screen for the merged subject-browser + knowledge-graph app.
///
/// The two features don't share navigation yet, so this just lets the user
/// jump into either one instead of one silently replacing the other's entry
/// point. Replace with real shared navigation once that's designed.
class _HomeMenu extends StatelessWidget {
  const _HomeMenu();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Obsidian FLM')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SubjectCatalogScreen(
                      curriculumCode: 'BIT_SE_K19B',
                    ),
                  ),
                ),
                child: const Text('Subject Catalog'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const KnowledgeGraphPage(),
                  ),
                ),
                child: const Text('Knowledge Graph'),
              ),
            ],
          ),
        ),
      );
}
