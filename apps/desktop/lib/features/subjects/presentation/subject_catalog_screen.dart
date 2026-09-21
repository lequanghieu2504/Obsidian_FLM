import 'package:flutter/material.dart';

import '../application/subject_catalog_controller.dart';
import '../data/asset_subject_repository.dart';
import 'subject_list_screen.dart';

class SubjectCatalogScreen extends StatefulWidget {
  const SubjectCatalogScreen({
    super.key,
    required this.curriculumCode,
    this.repository,
  });

  final String curriculumCode;
  final SubjectCatalogRepository? repository;

  @override
  State<SubjectCatalogScreen> createState() => _SubjectCatalogScreenState();
}

class _SubjectCatalogScreenState extends State<SubjectCatalogScreen> {
  late final SubjectCatalogController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SubjectCatalogController(
      curriculumCode: widget.curriculumCode,
      repository: widget.repository ?? AssetSubjectRepository(),
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      if (_controller.loading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (_controller.error != null) {
        return Scaffold(
          appBar: AppBar(title: Text(widget.curriculumCode)),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(liveRegion: true, child: Text(_controller.error!)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _controller.load,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }
      return SubjectListScreen(
        curriculumCode: widget.curriculumCode,
        subjects: _controller.subjects,
      );
    },
  );
}
