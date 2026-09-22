/// Extracts the assistant's reply text out of a decoded Gemini
/// `generateContent` response body. Kept separate from [GeminiLlmClient] so
/// this shape — candidates, content, parts, filtering out `thought` parts —
/// can be read, tested and changed without touching the HTTP/retry plumbing
/// around it, and so response parsing is reusable on its own.
class GeminiResponseParser {
  const GeminiResponseParser();

  /// Returns the joined reply text, trimmed. Returns an empty string when
  /// Gemini sent no candidates, no parts, or only thought/blank parts — the
  /// caller decides what an empty result means (currently: a failure).
  String extractText(Map<String, dynamic> decoded) {
    final candidates = decoded['candidates'] as List<dynamic>? ?? [];
    if (candidates.isEmpty) return '';
    final candidate = candidates.first as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? [];
    return parts
        .whereType<Map<String, dynamic>>()
        .where((part) => part['thought'] != true)
        .map((part) => part['text'] as String? ?? '')
        .join('\n')
        .trim();
  }
}
