/// Canonical, framework-independent representation of one FLM subject
/// syllabus, parsed out of the raw `data/subject/<id>.json` transport files.
///
/// The raw files are FLM's own export shape (a `metadata` map plus a list of
/// free-form `sections`/`rows`). This class extracts only the fields the
/// knowledge graph feature needs; it intentionally does not try to model the
/// full FLM syllabus (materials, sessions, assessments, ...).
class LearningOutcome {
  const LearningOutcome({required this.code, required this.detail});

  /// e.g. `CLO1`.
  final String code;

  /// The full outcome description.
  final String detail;
}

class SubjectRecord {
  const SubjectRecord({
    required this.syllabusId,
    required this.subjectCode,
    required this.syllabusName,
    required this.courseNameEnglish,
    required this.degreeLevel,
    required this.credits,
    required this.learningTeachingMethod,
    required this.prerequisiteRaw,
    required this.description,
    required this.learningOutcomes,
  });

  final String syllabusId;

  /// Stable-ish business key, e.g. `PRM393`, `PRO192c`. Used as the node id
  /// in the knowledge graph because `Syllabus ID` is an opaque database key
  /// while the subject code is what prerequisite text actually references.
  final String subjectCode;

  final String syllabusName;
  final String courseNameEnglish;
  final String degreeLevel;
  final String credits;
  final String learningTeachingMethod;

  /// Free-text prerequisite description exactly as FLM stores it, e.g.
  /// `"PRO192, SAP311"` or `"Familiarity with C programming"`. Kept verbatim
  /// (never overwritten) so the UI can always show the source-of-truth
  /// wording next to whatever edges were machine-extracted from it.
  final String prerequisiteRaw;

  final String description;
  final List<LearningOutcome> learningOutcomes;

  /// The label shown on a subject's graph node.
  String get displayLabel => subjectCode.isNotEmpty ? subjectCode : syllabusId;

  /// A regex that matches any section heading produced for the "learning
  /// outcomes" table, e.g. `"5 LO(s)"`, `"12 LO(s)"`.
  static final RegExp _learningOutcomeHeading = RegExp(r'LO\(s\)\s*$');

  factory SubjectRecord.fromJson(
    Map<String, dynamic> json, {
    required String fallbackId,
  }) {
    final metadata = _asStringMap(json['metadata']);
    String field(String key) => (metadata[key] ?? '').toString().trim();

    final sections = (json['sections'] as List?) ?? const [];
    final learningOutcomes = <LearningOutcome>[];
    for (final section in sections) {
      if (section is! Map) continue;
      final heading = (section['heading'] ?? '').toString();
      if (!_learningOutcomeHeading.hasMatch(heading)) continue;

      final rows = (section['rows'] as List?) ?? const [];
      for (final row in rows) {
        if (row is! List || row.length < 3) continue;
        final code = row[1].toString().trim();
        final detail = row[2].toString().trim();
        if (code.isEmpty) continue;
        learningOutcomes.add(LearningOutcome(code: code, detail: detail));
      }
    }

    final syllabusId = field('Syllabus ID').isNotEmpty
        ? field('Syllabus ID')
        : (json['id']?.toString() ?? fallbackId);
    final subjectCode =
        field('Subject Code').isNotEmpty ? field('Subject Code') : syllabusId;

    return SubjectRecord(
      syllabusId: syllabusId,
      subjectCode: subjectCode,
      syllabusName: field('Syllabus Name'),
      courseNameEnglish: field('Course Name English'),
      degreeLevel: field('Degree Level'),
      credits: field('NoCredit'),
      learningTeachingMethod: field('Learning-Teaching Method'),
      prerequisiteRaw: field('Pre-Requisite'),
      description: field('Description'),
      learningOutcomes: learningOutcomes,
    );
  }

  static Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is Map) {
      return value.map((key, v) => MapEntry(key.toString(), v));
    }
    return const {};
  }
}
