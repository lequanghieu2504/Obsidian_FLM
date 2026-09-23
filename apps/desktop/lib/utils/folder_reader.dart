import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:obsidian_flm_desktop/models/curriculum_data.dart';
import 'package:obsidian_flm_desktop/models/subject.dart';

class FolderReader {
  static Future<Directory> _getCacheDirectory() async {
    // Lưu vào thư mục 'data/cached_curriculums' ở thư mục gốc của project/app
    final cachedDataDir = Directory(p.join(Directory.current.path, 'data', 'cached_curriculums'));
    if (!await cachedDataDir.exists()) {
      await cachedDataDir.create(recursive: true);
    }
    return cachedDataDir;
  }

  /// Allows the user to select a folder, caches it, and parses it.
  static Future<CurriculumData?> importAndParseFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory == null) {
      return null;
    }

    final sourceDir = Directory(selectedDirectory);
    if (!await sourceDir.exists()) {
      throw Exception('Selected directory does not exist.');
    }

    // Check if it's a valid curriculum folder
    final curriculumFile = File(p.join(selectedDirectory, 'curriculum.json'));
    if (!await curriculumFile.exists()) {
      throw Exception('Invalid folder: curriculum.json not found.');
    }

    // Cache the folder
    final cachedDataDir = await _getCacheDirectory();

    // Create a specific folder for this curriculum based on its name or timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final targetDirPath = p.join(cachedDataDir.path, 'curriculum_$timestamp');

    await _copyDirectory(sourceDir, Directory(targetDirPath));

    // Parse from the cached folder
    return await parseFolder(targetDirPath);
  }

  /// Parses an already existing (cached) folder
  static Future<CurriculumData> parseFolder(String folderPath) async {
    final curriculumFile = File(p.join(folderPath, 'curriculum.json'));
    final basedDataPath = p.join(Directory.current.path, 'data', 'based_data');
    final combosFile = File(p.join(basedDataPath, 'combos.json'));
    final comboDetailsDir = Directory(p.join(basedDataPath, 'combo-details'));
    final syllabiDir = Directory(p.join(folderPath, 'syllabi'));
    final selectedComboFile = File(p.join(folderPath, 'selected_combo.json'));

    String? selectedComboId;
    if (await selectedComboFile.exists()) {
      try {
        final content = await selectedComboFile.readAsString();
        selectedComboId = jsonDecode(content)['comboId'];
      } catch (_) {}
    }

    if (!await curriculumFile.exists()) {
      throw Exception('curriculum.json not found in $folderPath');
    }

    // Parse Curriculum
    final curriculumContent = await curriculumFile.readAsString();
    final curriculumJson = jsonDecode(curriculumContent);

    final metadata = curriculumJson['metadata'] ?? {};
    final plosJson = curriculumJson['plos'] as List<dynamic>? ?? [];
    final subjectsJson = curriculumJson['subjects'] as List<dynamic>? ?? [];

    final plos = plosJson.map((e) => Plo.fromJson(e)).toList();
    final subjects = subjectsJson.map((e) {
      return Subject.fromJson(e);
    }).toList();

    // Parse Combos
    List<Combo> combos = [];
    if (await combosFile.exists()) {
      final combosContent = await combosFile.readAsString();
      final combosJsonList = jsonDecode(combosContent) as List<dynamic>? ?? [];

      for (var comboJson in combosJsonList) {
        String id = comboJson['id'].toString();
        List<Subject> comboSubjects = [];

        // Load details for this combo
        final detailFile = File(p.join(comboDetailsDir.path, '$id.json'));
        if (await detailFile.exists()) {
          final detailContent = await detailFile.readAsString();
          final detailJson = jsonDecode(detailContent);
          final subsJson = detailJson['subjects'] as List<dynamic>? ?? [];
          comboSubjects = subsJson.map((e) => Subject.fromJson(e)).toList();
        }

        combos.add(Combo.fromJson(comboJson, subjects: comboSubjects));
      }
    }

    // --- TÍCH HỢP VÀ LỌC MÔN HỌC CHUYÊN NGÀNH HẸP (COMBOS) ---
    Set<String> allComboSubjectCodes = {};
    for (var combo in combos) {
      if (combo.subjects != null) {
        allComboSubjectCodes.addAll(combo.subjects!.map((s) => s.code));
      }
    }

    Set<String> selectedComboSubjectCodes = {};
    Set<int> selectedComboSemesters = {};
    for (var combo in combos) {
      if (selectedComboId == null || combo.id == selectedComboId) {
        if (combo.subjects != null) {
          for (var s in combo.subjects!) {
            selectedComboSubjectCodes.add(s.code);
            selectedComboSemesters.add(s.semester);
          }
        }
      }
    }

    // 1. Xóa các môn Combo KHÔNG thuộc Combo đã chọn (trường hợp curriculum.json chứa sẵn tất cả combo)
    if (selectedComboId != null) {
      subjects.removeWhere((sub) =>
          allComboSubjectCodes.contains(sub.code) &&
          !selectedComboSubjectCodes.contains(sub.code));
    }

    // 2. Thêm các môn của Combo đã chọn vào danh sách môn chính (nếu bị thiếu)
    final existingSubjectCodes = subjects.map((s) => s.code).toSet();
    for (var combo in combos) {
      if (selectedComboId == null || combo.id == selectedComboId) {
        if (combo.subjects != null) {
          for (var s in combo.subjects!) {
            if (!existingSubjectCodes.contains(s.code)) {
              subjects.add(s);
              existingSubjectCodes.add(s.code);
            }
          }
        }
      }
    }

    // 3. Xóa các môn giữ chỗ (placeholder, ví dụ: SE_COM*1) ở những học kỳ của Combo đã chọn
    if (selectedComboSemesters.isNotEmpty) {
      subjects.removeWhere((sub) =>
          (sub.code.contains('_COM') || sub.code.contains('*')) &&
          selectedComboSemesters.contains(sub.semester));
    }

    // 4. Lọc danh sách Combos chỉ giữ lại Combo đã chọn
    final List<Combo> allCombos = List.from(combos);
    if (selectedComboId != null) {
      combos.removeWhere((combo) => combo.id != selectedComboId);
    }

    // Parse Syllabi
    Map<String, dynamic> syllabi = {};
    if (await syllabiDir.exists()) {
      await for (var entity in syllabiDir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = await entity.readAsString();
            final json = jsonDecode(content);
            if (json['metadata'] != null &&
                json['metadata']['Subject Code'] != null) {
              String subjectCode = json['metadata']['Subject Code'];
              syllabi[subjectCode] = json;
            }
          } catch (e) {
            // print('Error reading syllabus file ${entity.path}: $e');
          }
        }
      }
    }

    // Enrich subjects with syllabus prerequisites
    for (int i = 0; i < subjects.length; i++) {
      var sub = subjects[i];
      if (syllabi.containsKey(sub.code)) {
        final syllabus = syllabi[sub.code];
        if (syllabus['metadata'] != null &&
            syllabus['metadata']['Pre-Requisite'] != null) {
          final String sPrereq =
              syllabus['metadata']['Pre-Requisite'].toString().trim();
          if (sPrereq.isNotEmpty &&
              sPrereq.toLowerCase() != 'none' &&
              sPrereq != '-') {
            subjects[i] = Subject(
              semester: sub.semester,
              code: sub.code,
              name: sub.name,
              credits: sub.credits,
              preRequisite: sPrereq,
              isPlaceholder: sub.isPlaceholder,
            );
          }
        }
      }
    }

    return CurriculumData(
      metadata: metadata,
      plos: plos,
      subjects: subjects,
      combos: combos,
      allCombos: allCombos,
      syllabi: syllabi,
    );
  }

  /// Gets the most recently cached curriculum, or null if none
  static Future<CurriculumData?> getCachedCurriculum() async {
    final cachedDataDir = await _getCacheDirectory();

    final entities = await cachedDataDir.list().toList();
    if (entities.isEmpty) return null;

    // Sort to get the most recent one (alphabetical sort on timestamp)
    entities.sort((a, b) => b.path.compareTo(a.path));
    final latestDir = entities.first;

    if (latestDir is Directory) {
      try {
        return await parseFolder(latestDir.path);
      } catch (e) {
        // print('Failed to parse cached curriculum: $e');
        return null;
      }
    }
    return null;
  }

  static Future<void> saveSelectedCombo(String comboId) async {
    final cachedDataDir = await _getCacheDirectory();

    final entities = await cachedDataDir.list().toList();
    if (entities.isEmpty) return;

    entities.sort((a, b) => b.path.compareTo(a.path));
    final latestDir = entities.first;

    if (latestDir is Directory) {
      final file = File(p.join(latestDir.path, 'selected_combo.json'));
      await file.writeAsString(jsonEncode({'comboId': comboId}));
    }
  }

  static Future<void> _copyDirectory(
      Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (var entity in source.list(recursive: false)) {
      if (entity is Directory) {
        var newDirectory = Directory(
            p.join(destination.absolute.path, p.basename(entity.path)));
        await newDirectory.create();
        await _copyDirectory(entity.absolute, newDirectory);
      } else if (entity is File) {
        await entity.copy(p.join(destination.path, p.basename(entity.path)));
      }
    }
  }
}
