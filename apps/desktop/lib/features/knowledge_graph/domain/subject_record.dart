/// Canonical, framework-independent representation of one FLM subject
/// syllabus, parsed out of the raw `data/subject/<id>.json` transport files.
///
/// The raw files are FLM's own export shape (a `metadata` map plus a list of
/// free-form `sections`/`rows`). Earlier versions of this class only kept a
/// handful of named fields (name/credits/description/...) and silently
/// dropped everything else in the file — grading rubric fields
/// (`Scoring Scale`, `MinAvgMarkToPass`, `Is Scored`), `Tools`,
/// `StudentTasks`, `Time Allocation`, the materials table, the week-by-week
/// session plan, etc. That meant both the UI and the Gemini prompt built
/// from a subject were missing information the source file actually has
/// (e.g. "how is this subject graded" often lives in `Scoring Scale`/
/// `MinAvgMarkToPass` or a dedicated assessment table, not just prose in
/// `Description`). [metadata] and [sections] now keep the *entire* file
/// (minus the one section that's a pure duplicate of [metadata]), so
/// nothing from `data/subject/` is lost.
class LearningOutcome {
  const LearningOutcome({required this.code, required this.detail});

  /// e.g. `CLO1`.
  final String code;

  /// The full outcome description.
  final String detail;
}

/// One arbitrary table from the syllabus file — reference materials,
/// week-by-week session plan, assessment breakdown, or whatever else a
/// given subject's file happens to have — kept generically since the set
/// of tables (and their columns) isn't fixed across subjects.
class SyllabusSection {
  const SyllabusSection({
    required this.heading,
    required this.headers,
    required this.rows,
  });

  final String heading;
  final List<String> headers;
  final List<List<String>> rows;
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
    this.metadata = const {},
    this.sections = const [],
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

  /// Every `metadata` key from the raw file, verbatim (e.g. `Scoring Scale`,
  /// `MinAvgMarkToPass`, `Is Scored`, `Time Allocation`, `Tools`,
  /// `StudentTasks`, `Note`, `DecisionNo MM/dd/yyyy`, `IsApproved`,
  /// `IsActive`, `ApprovedDate`, ...) — including the handful already
  /// pulled out into named fields above, so callers that want "give me
  /// literally everything" don't have to know which keys those were.
  final Map<String, String> metadata;

  /// Every other table in the file (materials/references, the week-by-week
  /// session plan, an assessment breakdown, ...) — whatever a given
  /// subject's file happens to have beyond the metadata block and the
  /// learning-outcomes table (already parsed into [learningOutcomes]).
  final List<SyllabusSection> sections;

  /// The label shown on a subject's graph node.
  String get displayLabel => subjectCode.isNotEmpty ? subjectCode : syllabusId;

  /// A regex that matches any section heading produced for the "learning
  /// outcomes" table, e.g. `"5 LO(s)"`, `"12 LO(s)"`.
  static final RegExp _learningOutcomeHeading = RegExp(r'LO\(s\)\s*$');

  /// The one section heading that's a pure duplicate of [metadata] (same
  /// key/value pairs, just as a table) — kept out of [sections] so nothing
  /// is shown/sent twice.
  static const _syllabusDetailsHeading = 'Syllabus Details';

  /// FLM's raw export gives most tables a meaningful heading (e.g.
  /// `"6 Constructive question(s)"`, `"5 assessment(s)"`) but leaves the
  /// reference-materials table and the week-by-week session-plan table
  /// named generically — literally `"Table 2"`, `"Table 3"` or `"Table 4"`
  /// depending on which optional sections a given subject's file happens to
  /// have. Those two are recognized by their column shape (stable across
  /// subjects, unlike the numbering) and given a real name; any other
  /// generic-looking heading falls back to something better than "Table N".
  static final RegExp _genericTableHeading = RegExp(
    r'^Table\s*\d+$',
    caseSensitive: false,
  );

  static String _resolveHeading(String heading, List<String> headers) {
    if (!_genericTableHeading.hasMatch(heading.trim())) return heading;
    final normalizedHeaders = headers.map((h) => h.toLowerCase()).toSet();
    if (normalizedHeaders.contains('materialdescription')) {
      return 'Reference materials';
    }
    if (normalizedHeaders.contains('learningteachingtype')) {
      return 'Session plan';
    }
    return 'Additional information';
  }

  factory SubjectRecord.fromJson(
    Map<String, dynamic> json, {
    required String fallbackId,
  }) {
    final metadataRaw = _asStringMap(json['metadata']);
    String field(String key) => (metadataRaw[key] ?? '').toString().trim();
    final metadata = {
      for (final entry in metadataRaw.entries)
        entry.key: entry.value.toString().trim(),
    };

    final sectionsJson = (json['sections'] as List?) ?? const [];
    final learningOutcomes = <LearningOutcome>[];
    final sections = <SyllabusSection>[];
    for (final section in sectionsJson) {
      if (section is! Map) continue;
      final heading = (section['heading'] ?? '').toString();
      final headers = ((section['headers'] as List?) ?? const [])
          .map((header) => header.toString())
          .toList(growable: false);
      final rawRows = (section['rows'] as List?) ?? const [];
      final rows = <List<String>>[
        for (final row in rawRows)
          if (row is List)
            row.map((cell) => cell.toString()).toList(growable: false),
      ];

      if (_learningOutcomeHeading.hasMatch(heading)) {
        for (final row in rows) {
          if (row.length < 3) continue;
          final code = row[1].trim();
          final detail = row[2].trim();
          if (code.isEmpty) continue;
          learningOutcomes.add(LearningOutcome(code: code, detail: detail));
        }
        continue;
      }
      if (heading == _syllabusDetailsHeading) continue;

      sections.add(
        SyllabusSection(
          heading: _resolveHeading(heading, headers),
          headers: headers,
          rows: rows,
        ),
      );
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
      metadata: metadata,
      sections: sections,
    );
  }

  static Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is Map) {
      return value.map((key, v) => MapEntry(key.toString(), v));
    }
    return const {};
  }
}
