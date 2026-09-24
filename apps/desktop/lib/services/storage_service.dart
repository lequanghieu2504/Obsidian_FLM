import 'dart:convert';
import 'dart:io';
import '../models/curriculum.dart';
import '../models/subject.dart';

class StorageService {
  // Vì là Portable App nên ta lưu ở thư mục hiện tại của file chạy
  final String _baseDir = '${Directory.current.path}/data';

  StorageService() {
    // Đảm bảo thư mục data tồn tại
    final dir = Directory(_baseDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }



  Future<void> saveCurriculumList(String cohort, List<Curriculum> list) async {
    final file = File('$_baseDir/list_curriculum_$cohort.json');
    final jsonList = list.map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  Future<void> saveCurriculumDetails(String majorCode, List<Subject> subjects) async {
    final file = File('$_baseDir/curriculum_detail_$majorCode.json');
    final jsonList = subjects.map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }
}
