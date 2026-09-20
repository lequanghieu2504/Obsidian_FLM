import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/concept_data.dart';

/// Loads the curated topic/subtopic data bundled at
/// `data/concepts/concepts.json` — a single JSON object keyed by
/// `subjectCode` (e.g. `"PRM393"`), each value shaped like
/// `SubjectConcepts.fromJson`.
///
/// Declared as a Flutter asset (see `pubspec.yaml`) for the same reason as
/// `SubjectRepository`: identical loading between `flutter run`, a packaged
/// build, and any other Flutter target, regardless of working directory.
class ConceptRepository {
  const ConceptRepository({this.assetPath = 'data/concepts/concepts.json'});

  final String assetPath;

  /// Never throws on a missing/malformed asset — returns an empty map so
  /// the graph feature degrades to "subject node only" instead of crashing
  /// the whole page if the concepts data isn't bundled for some reason.
  Future<Map<String, SubjectConcepts>> loadAll() async {
    late final String raw;
    try {
      raw = await rootBundle.loadString(assetPath);
    } catch (_) {
      return const {};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const {};

    final result = <String, SubjectConcepts>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      result[entry.key] = SubjectConcepts.fromJson(value);
    }
    return result;
  }
}
