import 'subject_record.dart';
import 'text_match.dart';

/// One row of a subject's week-by-week "Session plan" table
/// (`SubjectRecord.sessionPlanSection`), parsed by column name rather than
/// position so it stays correct even if a given subject's raw export orders
/// the columns differently. Keeps every column the raw table has (not just
/// the couple this feature started with) — a person looking at a matched
/// session wants everything FLM recorded for it, not a partial summary.
class SessionPlanEntry {
  const SessionPlanEntry({
    required this.session,
    required this.topic,
    required this.learningTeachingType,
    required this.learningOutcomes,
    required this.itu,
    required this.materials,
    required this.downloadLink,
    required this.studentTasks,
    required this.urls,
  });

  /// The raw `session` cell, e.g. `"1"`, `"16"` — kept as text since it's
  /// only ever displayed, never sorted/compared numerically here (callers
  /// that need to sort do so with `int.tryParse` themselves).
  final String session;

  /// What's taught that session, e.g. `"Flutter Overview & Environment
  /// Setup"` — the closest thing this table has to "what is this session
  /// about".
  final String topic;

  /// e.g. `"Offline"`, `"Online"`.
  final String learningTeachingType;

  /// The `lo`/CLO column, verbatim (e.g. `"CLO1, CLO6"`).
  final String learningOutcomes;

  /// The `itu` column — FLM's own activity classification for the session
  /// (seen values include `"I"`, `"T"`, `"U"`, `"ITU"` and combinations
  /// like `"T,U"`); kept verbatim since FLM doesn't document what each
  /// letter stands for anywhere in the export itself.
  final String itu;

  /// The `studentmaterials` column — usually a module reference plus name
  /// (e.g. `"M5 – Navigation & State Management. Reference: ..."`), which
  /// often names a curated topic/subtopic more literally than any single
  /// session's own [topic] title does (see [matchingSessionPlanEntries]).
  final String materials;

  /// The `sdownload` column — a download reference for that session's
  /// materials (often blank).
  final String downloadLink;

  /// The `studentstasks` column — what students are actually expected to
  /// do that session (before/during/after class), separate from [topic]
  /// (what's taught) and [materials] (what to read).
  final String studentTasks;

  /// The `urls` column — any link(s) FLM attached directly to the session
  /// row (separate from links embedded in [materials]'s free text).
  final String urls;

  /// Text this row is searched in for a topic/subtopic label match.
  String get searchableText => '$topic $materials';
}

/// Parses [SubjectRecord.sessionPlanSection] into structured rows. Missing
/// columns (some subjects' Session plan tables have been seen without every
/// column) just leave that field blank rather than throwing.
List<SessionPlanEntry> sessionPlanEntriesFor(SubjectRecord subject) {
  final section = subject.sessionPlanSection;
  if (section == null) return const [];

  final headers = section.headers.map((h) => h.toLowerCase().trim()).toList();
  int indexOf(String name) => headers.indexOf(name);
  final sessionIdx = indexOf('session');
  final topicIdx = indexOf('topic');
  final typeIdx = indexOf('learningteachingtype');
  final loIdx = indexOf('lo');
  final ituIdx = indexOf('itu');
  final materialsIdx = indexOf('studentmaterials');
  final downloadIdx = indexOf('sdownload');
  final tasksIdx = indexOf('studentstasks');
  final urlsIdx = indexOf('urls');

  String cell(List<String> row, int idx) =>
      (idx >= 0 && idx < row.length) ? row[idx].trim() : '';

  return [
    for (final row in section.rows)
      SessionPlanEntry(
        session: cell(row, sessionIdx),
        topic: cell(row, topicIdx),
        learningTeachingType: cell(row, typeIdx),
        learningOutcomes: cell(row, loIdx),
        itu: cell(row, ituIdx),
        materials: cell(row, materialsIdx),
        downloadLink: cell(row, downloadIdx),
        studentTasks: cell(row, tasksIdx),
        urls: cell(row, urlsIdx),
      ),
  ];
}

/// Finds every [SessionPlanEntry] whose [SessionPlanEntry.searchableText]
/// mentions [label] — the same kind of best-effort keyword match
/// `ConceptExtractor` uses for description/CLO text (see that file's own
/// caveat about false positives/negatives), applied here to the session
/// plan instead so a knowledge-graph topic/subtopic node can point back at
/// *which* session(s) actually cover it.
///
/// Tries the whole label first (word-boundary on ends that start/end with a
/// word character, so a label like `"C#"` still matches correctly); if that
/// finds nothing and the label is actually several words/concepts glued
/// together (`"UI/UX"`, `"Widgets & Plugins"`), falls back to matching any
/// individual part at least 2 characters long — curated topic labels are
/// sometimes broader than any single session's title
/// (`"Mobile App Development"` never appears verbatim in a session row, but
/// the sessions for its subtopics — Flutter, Dart, ... — do turn up).
List<SessionPlanEntry> matchingSessionPlanEntries(
  String label,
  List<SessionPlanEntry> entries,
) {
  final whole =
      entries.where((e) => mentionsWord(e.searchableText, label)).toList();
  if (whole.isNotEmpty) return whole;

  final parts = label
      .split(RegExp(r'[\s/&,]+'))
      .map((p) => p.trim())
      .where((p) => p.length >= 2)
      .toList();
  if (parts.isEmpty) return const [];

  return [
    for (final e in entries)
      if (parts.any((p) => mentionsWord(e.searchableText, p))) e,
  ];
}

/// Merges several match lists (e.g. a topic node's own match plus each of
/// its subtopics') into one, de-duplicated by session number + topic text
/// and keeping first-seen order.
List<SessionPlanEntry> dedupeSessionPlanEntries(
  Iterable<SessionPlanEntry> entries,
) {
  final seen = <String>{};
  final result = <SessionPlanEntry>[];
  for (final e in entries) {
    final key = '${e.session}::${e.topic}';
    if (seen.add(key)) result.add(e);
  }
  return result;
}
