/// Shared best-effort keyword match used across this feature's "which part
/// of the raw JSON mentions this node's label" lookups (`session_plan.dart`,
/// `node_evidence.dart`) — the same kind `ConceptExtractor` uses for
/// description/CLO text, factored out here so every lookup treats a label
/// the same way instead of each keeping its own private copy.
///
/// Word-boundary on whichever end(s) of [needle] start/end with a word
/// character, so a symbol-heavy label (`"C#"`, `".NET"`) still matches
/// correctly, and a short one (`"UI"`) doesn't match inside a longer word
/// it's merely a substring of.
bool mentionsWord(String haystack, String needle) {
  final trimmed = needle.trim();
  if (trimmed.isEmpty) return false;
  final startsWithWordChar = RegExp(r'^\w').hasMatch(trimmed);
  final endsWithWordChar = RegExp(r'\w$').hasMatch(trimmed);
  final pattern =
      '${startsWithWordChar ? r'\b' : ''}${RegExp.escape(trimmed)}${endsWithWordChar ? r'\b' : ''}';
  return RegExp(pattern, caseSensitive: false).hasMatch(haystack);
}
