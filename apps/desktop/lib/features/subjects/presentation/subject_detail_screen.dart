import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../models/subject.dart';
import '../../assistant/infrastructure/gemini_llm_client.dart';
import '../../assistant/infrastructure/local_chat_attachment_processor.dart';
import '../../knowledge_graph/presentation/subject_knowledge_graph_tab.dart';
import '../application/subject_detail_controller.dart';
import '../data/local_subject_workspace_repository.dart';
import '../domain/subject_workspace.dart';
import 'subject_chat_panel.dart';
import 'subject_resources_panel.dart';

typedef SubjectControllerFactory =
    Future<SubjectDetailController> Function(SubjectWorkspace workspace);

Future<SubjectDetailController> createSubjectController(
  SubjectWorkspace workspace,
) async {
  final support = await getApplicationSupportDirectory();
  const keys = SecureGeminiKeyStore();
  return SubjectDetailController(
    workspace: workspace,
    repository: LocalSubjectWorkspaceRepository(
      Directory(p.join(support.path, 'user_data')),
    ),
    llm: GeminiLlmClient(keys: keys),
    keys: keys,
    attachmentProcessor: const LocalChatAttachmentProcessor(),
  );
}

class SubjectDetailScreen extends StatefulWidget {
  const SubjectDetailScreen({
    super.key,
    required this.curriculumCode,
    required this.subject,
    this.controllerFactory = createSubjectController,
  });
  final String curriculumCode;
  final Subject subject;
  final SubjectControllerFactory controllerFactory;

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  SubjectDetailController? _controller;
  bool _failed = false;
  int _generation = 0;
  final _chatKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(SubjectDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.curriculumCode != widget.curriculumCode ||
        oldWidget.subject != widget.subject) {
      _controller?.dispose();
      _controller = null;
      _initialize();
    }
  }

  Future<void> _initialize() async {
    final generation = ++_generation;
    setState(() => _failed = false);
    try {
      final controller = await widget.controllerFactory(
        SubjectWorkspace(
          curriculumCode: widget.curriculumCode,
          subject: widget.subject,
        ),
      );
      if (!mounted || generation != _generation) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.load();
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _generation++;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.subject.code} · Subject Detail')),
      body: SafeArea(
        child: _failed
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Cannot open local user storage. Check folder permissions.',
                    ),
                    TextButton(
                      onPressed: _initialize,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : controller == null
            ? const Center(child: CircularProgressIndicator())
            : ListenableBuilder(
                listenable: controller,
                builder: (context, _) => LayoutBuilder(
                  builder: (context, constraints) {
                    final information = SubjectResourcesPanel(
                      controller: controller,
                    );
                    final chat = SubjectChatPanel(
                      key: _chatKey,
                      controller: controller,
                    );
                    final knowledgeGraph = SubjectKnowledgeGraphTab(
                      subjectCode: widget.subject.code,
                    );
                    if (constraints.maxWidth >= 960) {
                      return DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            const TabBar(
                              tabs: [
                                Tab(text: 'Detail'),
                                Tab(text: 'Knowledge Graph'),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(flex: 3, child: information),
                                        const SizedBox(width: 24),
                                        Expanded(flex: 2, child: chat),
                                      ],
                                    ),
                                  ),
                                  knowledgeGraph,
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(text: 'Subject & resources'),
                              Tab(text: 'Gemini Assistant'),
                              Tab(text: 'Knowledge Graph'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: information,
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: chat,
                                ),
                                knowledgeGraph,
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
