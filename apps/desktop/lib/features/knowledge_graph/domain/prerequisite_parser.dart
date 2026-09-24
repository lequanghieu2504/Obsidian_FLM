/// Extracts subject-code references out of FLM's free-text `Pre-Requisite`
/// field, e.g. `"PRO192, SAP311"` -> `[PRO192, SAP311]`, or
/// `"SWE102 or SWE201c or SWE202c"` -> `[SWE102, SWE201c, SWE202c]`.
///
/// FLM subject codes follow a consistent shape across the whole dataset:
/// 2-4 uppercase letters, exactly 3 digits, then an optional single
/// lowercase/uppercase campus-or-curriculum-variant letter (`PRO192`,
/// `PRO192c`, `DSR301m`). Free-text-only prerequisites such as
/// "Familiarity with C programming" simply yield no matches, which is the
/// correct outcome: no official edge should be drawn for a requirement FLM
/// never expressed as a subject code.
abstract class PrerequisiteParser {
  static final RegExp _subjectCodePattern =
      RegExp(r'\b[A-Z]{2,4}\d{3}[a-zA-Z]?\b');

  /// Returns the distinct subject codes referenced in [prerequisiteText],
  /// sorted, excluding [ownCode] (guards against a subject accidentally
  /// citing itself and creating a self-loop).
  static List<String> extractCodes(
    String prerequisiteText, {
    required String ownCode,
  }) {
    final matches = _subjectCodePattern
        .allMatches(prerequisiteText)
        .map((m) => m.group(0)!)
        .toSet()
      ..remove(ownCode);
    final result = matches.toList()..sort();
    return result;
  }
}
