import 'package:flutter/foundation.dart';

import '../../../models/subject.dart';
import '../data/asset_subject_repository.dart';

class SubjectCatalogController extends ChangeNotifier {
  SubjectCatalogController({
    required this.curriculumCode,
    required this.repository,
  });

  final String curriculumCode;
  final SubjectCatalogRepository repository;

  List<Subject> _subjects = const [];
  List<Subject> get subjects => _subjects;
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _subjects = await repository.loadSubjects(curriculumCode);
    } catch (_) {
      _subjects = const [];
      error = 'Unable to load subject data.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
