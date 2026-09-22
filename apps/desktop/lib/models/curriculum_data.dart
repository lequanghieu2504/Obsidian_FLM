import 'package:obsidian_flm_desktop/models/subject.dart';

class Plo {
  final String code;
  final String description;

  Plo({required this.code, required this.description});

  factory Plo.fromJson(Map<String, dynamic> json) => Plo(
    code: json['code'] ?? '',
    description: json['description'] ?? '',
  );
}

class Combo {
  final String id;
  final String code;
  final String name;
  final String href;
  final List<Subject>? subjects; // Will be hydrated from combo-details

  Combo({
    required this.id,
    required this.code,
    required this.name,
    required this.href,
    this.subjects,
  });

  factory Combo.fromJson(Map<String, dynamic> json, {List<Subject>? subjects}) => Combo(
    id: json['id'] ?? '',
    code: json['code'] ?? '',
    name: json['name'] ?? '',
    href: json['href'] ?? '',
    subjects: subjects,
  );
}

class CurriculumData {
  final Map<String, dynamic> metadata;
  final List<Plo> plos;
  final List<Subject> subjects;
  final List<Combo> combos;
  final List<Combo> allCombos;
  final Map<String, dynamic> syllabi; // subjectCode -> syllabus Json

  CurriculumData({
    required this.metadata,
    required this.plos,
    required this.subjects,
    required this.combos,
    required this.allCombos,
    required this.syllabi,
  });
}
