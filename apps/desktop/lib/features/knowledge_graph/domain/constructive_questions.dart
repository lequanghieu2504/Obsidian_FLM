import 'subject_record.dart';

/// One row of a subject's "Constructive question(s)" table
/// (`SubjectRecord.constructiveQuestionsSection`) — a discussion/reflection
/// prompt FLM ties to a specific session via its own `SessionNo` column, so
/// it can be attached to whichever [SessionPlanEntry] shares that number
/// (see `constructiveQuestionsForSession`) to flesh out *what* a session
/// actually asks/discusses, not just its title.
class ConstructiveQuestion {
  const ConstructiveQuestion({
    required this.sessionNo,
    required this.name,
    required this.details,
  });

  /// The `sessionno` cell — joins against a `SessionPlanEntry.session`
  /// value, e.g. `"1"`.
  final String sessionNo;

  /// Short code FLM gives the question, e.g. `"HCM1.1"`.
  final String name;

  /// The question text itself.
  final String details;
}

/// Parses [SubjectRecord.constructiveQuestionsSection] into structured
/// rows, looked up by header name (not position) like
/// `session_plan.dart`'s own parser. Missing columns just leave that field
/// blank rather than throwing.
List<ConstructiveQuestion> constructiveQuestionsFor(SubjectRecord subject) {
  final section = subject.constructiveQuestionsSection;
  if (section == null) return const [];

  final headers = section.headers.map((h) => h.toLowerCase().trim()).toList();
  int indexOf(String name) => headers.indexOf(name);
  final sessionIdx = indexOf('sessionno');
  final nameIdx = indexOf('name');
  final detailsIdx = indexOf('details');

  String cell(List<String> row, int idx) =>
      (idx >= 0 && idx < row.length) ? row[idx].trim() : '';

  return [
    for (final row in section.rows)
      ConstructiveQuestion(
        sessionNo: cell(row, sessionIdx),
        name: cell(row, nameIdx),
        details: cell(row, detailsIdx),
      ),
  ];
}

/// Every [ConstructiveQuestion] whose [ConstructiveQuestion.sessionNo]
/// matches [session] (a `SessionPlanEntry.session` value, e.g. `"1"`).
List<ConstructiveQuestion> constructiveQuestionsForSession(
  String session,
  List<ConstructiveQuestion> all,
) {
  return [for (final q in all) if (q.sessionNo == session) q];
}
