import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../models/subject.dart';

abstract interface class SubjectCatalogRepository {
  Future<List<Subject>> loadSubjects(String curriculumCode);
}

class AssetSubjectRepository implements SubjectCatalogRepository {
  AssetSubjectRepository({AssetBundle? bundle}) : bundle = bundle ?? rootBundle;

  final AssetBundle bundle;

  @override
  Future<List<Subject>> loadSubjects(String curriculumCode) async {
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(curriculumCode)) {
      throw const FormatException('Invalid curriculum code.');
    }

    final source = await bundle.loadString(
      'data/curriculum_detail_$curriculumCode.json',
    );
    final decoded = jsonDecode(source);
    if (decoded is! List<dynamic>) {
      throw const FormatException('Subject data must be a JSON list.');
    }

    return decoded.indexed
        .map((entry) {
          final (index, value) = entry;
          if (value is! Map<String, dynamic>) {
            throw FormatException('Invalid Subject record at index $index.');
          }
          try {
            return Subject.fromJson(value);
          } on FormatException {
            throw FormatException('Invalid Subject record at index $index.');
          }
        })
        .toList(growable: false);
  }
}
