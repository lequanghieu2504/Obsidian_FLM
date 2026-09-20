import 'package:flutter/material.dart';

import '../features/knowledge_graph/presentation/knowledge_graph_page.dart';

class ObsidianFlmApp extends StatelessWidget {
  const ObsidianFlmApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Obsidian FLM',
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        ),
        home: const KnowledgeGraphPage(),
      );
}
