import 'dart:convert';

import '../../subjects/domain/subject_workspace.dart';
import '../application/llm_client.dart';

/// Builds the JSON body for Gemini's `generateContent` endpoint out of the
/// generic [LlmClient.send] inputs (a system prompt, chat history and any
/// attachments). Kept separate from [GeminiLlmClient] so this shape — how a
/// prompt turns into Gemini's `systemInstruction`/`contents` wire format —
/// can be read, tested and changed without touching the HTTP/retry plumbing
/// around it, and so the request-building step is reusable on its own.
class GeminiRequestBuilder {
  const GeminiRequestBuilder({this.maxHistoryMessages = 20});

  /// How many of the most recent [ChatMessage]s to actually include. The
  /// controller keeps (and persists) the whole chat, but resending all of it
  /// on every turn makes each request grow linearly with the conversation's
  /// length — a long-running chat can burn through a free-tier token/request
  /// quota in a handful of turns even though the user only asked a short
  /// question. Trimming to the most recent messages keeps per-request cost
  /// roughly constant; set to a large value if full history is wanted for a
  /// short-lived chat.
  final int maxHistoryMessages;

  /// Returns the request body, ready for `jsonEncode`. Attachments are only
  /// ever attached to the last (current) message — earlier turns are sent
  /// as plain text history.
  Map<String, dynamic> build({
    required String context,
    required List<ChatMessage> messages,
    List<ChatAttachment> attachments = const [],
  }) {
    // Only the tail of the conversation is sent to Gemini (see
    // [maxHistoryMessages]) — the full history stays with the caller/UI,
    // this is just what goes over the wire.
    final sentMessages = messages.length > maxHistoryMessages
        ? messages.sublist(messages.length - maxHistoryMessages)
        : messages;
    return {
      'systemInstruction': {
        'parts': [
          {'text': context},
        ],
      },
      'contents': sentMessages.indexed
          .map(
            (entry) => {
              ...(() {
                final (index, m) = entry;
                final isCurrentMessage = index == sentMessages.length - 1;
                return {
                  'role': m.role == ChatRole.user ? 'user' : 'model',
                  'parts': [
                    {'text': m.content},
                    if (isCurrentMessage)
                      ...attachments.map(
                        (attachment) => attachment.text != null
                            ? {
                                'text':
                                    'Attached file ${attachment.fileName}:\n${attachment.text}',
                              }
                            : {
                                'inlineData': {
                                  'mimeType': attachment.mimeType,
                                  'data': base64Encode(attachment.bytes!),
                                },
                              },
                      ),
                  ],
                };
              })(),
            },
          )
          .toList(),
    };
  }
}
