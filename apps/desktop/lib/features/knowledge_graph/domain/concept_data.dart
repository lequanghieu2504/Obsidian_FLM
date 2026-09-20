/// Curated, hierarchical topic data for one subject's concept graph.
///
/// Unlike the earlier `ConceptExtractor` (a flat English keyword dictionary
/// matched against free text at runtime — see `README.md` §0 "Lần 3" for why
/// that was dropped), this data is pre-computed: each of the 84 FLM subjects
/// had its Description + CLO text actually read and organised into topics
/// (e.g. "Mobile App Development") with child subtopics (e.g. "Flutter",
/// "UI/UX") underneath. It ships as a bundled asset
/// (`data/concepts/concepts.json`) and is loaded by `ConceptRepository`
/// rather than computed from `SubjectRecord` at runtime, because genuine
/// reading comprehension of free-form Vietnamese/English syllabus text isn't
/// something a regex/dictionary can do — see the extraction notes above.
library concept_data;

/// One topic found in a subject's Description/CLO text, with its child
/// subtopics (may be empty, e.g. a subject where nothing narrower than the
/// topic itself was mentioned).
class ConceptTopic {
  const ConceptTopic({required this.label, this.subtopics = const []});

  final String label;
  final List<String> subtopics;

  factory ConceptTopic.fromJson(Map<String, dynamic> json) {
    final rawSubtopics = (json['subtopics'] as List?) ?? const [];
    return ConceptTopic(
      label: (json['label'] ?? '').toString(),
      subtopics: rawSubtopics.map((e) => e.toString()).toList(),
    );
  }
}

/// All curated topics for one subject, keyed by `subjectCode` in
/// `ConceptRepository`'s map (so this itself doesn't repeat the code).
class SubjectConcepts {
  const SubjectConcepts({required this.topics});

  final List<ConceptTopic> topics;

  static const empty = SubjectConcepts(topics: []);

  factory SubjectConcepts.fromJson(Map<String, dynamic> json) {
    final rawTopics = (json['topics'] as List?) ?? const [];
    return SubjectConcepts(
      topics: rawTopics
          .whereType<Map<String, dynamic>>()
          .map(ConceptTopic.fromJson)
          .toList(),
    );
  }

  int get subtopicCount => topics.fold(0, (sum, t) => sum + t.subtopics.length);
}
