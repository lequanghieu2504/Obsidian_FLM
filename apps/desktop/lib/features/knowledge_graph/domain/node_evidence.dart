import 'subject_record.dart';
import 'text_match.dart';

/// One sentence from a subject's Description or a CLO's detail that
/// mentions a knowledge-graph node's label — the closest thing the raw FLM
/// export has to a "definition" for a curated topic/subtopic (there is no
/// dedicated per-concept definition field anywhere in `data/subject/`;
/// this is the actual syllabus prose that talks about it, trimmed to just
/// the sentence(s) that do).
class NodeContextSnippet {
  const NodeContextSnippet({required this.source, required this.sentence});

  /// Where the sentence came from: `"Mô tả"` for the syllabus description,
  /// or a CLO code (`"CLO3"`) for a learning outcome.
  final String source;

  final String sentence;
}

/// Every sentence, across [subject]'s Description and every CLO's detail,
/// that mentions [label]. Splits on sentence-ending punctuation rather than
/// returning the whole field, so a long Description doesn't drown out the
/// one or two sentences that actually name the concept.
List<NodeContextSnippet> nodeContextSnippetsFor(
  SubjectRecord subject,
  String label,
) {
  final sources = <String, String>{
    if (subject.description.isNotEmpty) 'Mô tả': subject.description,
    for (final lo in subject.learningOutcomes)
      if (lo.detail.isNotEmpty) lo.code: lo.detail,
  };

  final snippets = <NodeContextSnippet>[];
  for (final entry in sources.entries) {
    for (final sentence in _splitSentences(entry.value)) {
      if (mentionsWord(sentence, label)) {
        snippets.add(
          NodeContextSnippet(source: entry.key, sentence: sentence),
        );
      }
    }
  }
  return snippets;
}

/// De-duplicates a merged list of [NodeContextSnippet]s (e.g. a topic
/// node's own snippets plus each of its subtopics') by source + sentence,
/// keeping first-seen order — the same sentence can otherwise show up once
/// per subtopic whose label it happens to also mention.
List<NodeContextSnippet> dedupeContextSnippets(
  Iterable<NodeContextSnippet> snippets,
) {
  final seen = <String>{};
  final result = <NodeContextSnippet>[];
  for (final s in snippets) {
    final key = '${s.source}::${s.sentence}';
    if (seen.add(key)) result.add(s);
  }
  return result;
}

List<String> _splitSentences(String text) {
  return text
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// One row, from some syllabus table other than Session plan / Constructive
/// question(s) (those already get their own structured parsing — see
/// `session_plan.dart`/`constructive_questions.dart`), that mentions a
/// node's label somewhere in its cells — e.g. a Reference materials row
/// naming a matching textbook chapter, or an assessment row whose
/// "knowledge and skill" column names the concept.
class OtherSectionMention {
  const OtherSectionMention({
    required this.sectionHeading,
    required this.fields,
  });

  /// The [SyllabusSection.heading] this row came from (e.g.
  /// `"Reference materials"`, `"4 assessment(s)"`).
  final String sectionHeading;

  /// header -> cell, for every non-empty cell in the matched row — kept
  /// generic (no hardcoded shape) since this deliberately covers whatever
  /// tables a given subject's file happens to have beyond the two this
  /// feature already understands structurally.
  final Map<String, String> fields;
}

/// Every row, in every one of [subject]'s syllabus sections *except*
/// Session plan and Constructive question(s), whose cells mention [label].
/// This is the "search literally everything else in the file" fallback —
/// a node might be discussed anywhere (an assessment's grading guide, a
/// textbook title, ...), not only in the two tables this feature otherwise
/// understands structurally.
List<OtherSectionMention> otherSectionMentionsFor(
  SubjectRecord subject,
  String label,
) {
  final skip = {
    subject.sessionPlanSection?.heading,
    subject.constructiveQuestionsSection?.heading,
  };

  final mentions = <OtherSectionMention>[];
  for (final section in subject.sections) {
    if (skip.contains(section.heading)) continue;
    for (final row in section.rows) {
      final matchesRow = row.any((cell) => mentionsWord(cell, label));
      if (!matchesRow) continue;

      final fields = <String, String>{};
      for (var i = 0; i < row.length && i < section.headers.length; i++) {
        final value = row[i].trim();
        if (value.isNotEmpty) fields[section.headers[i]] = value;
      }
      if (fields.isNotEmpty) {
        mentions.add(
          OtherSectionMention(
            sectionHeading: section.heading,
            fields: fields,
          ),
        );
      }
    }
  }
  return mentions;
}
