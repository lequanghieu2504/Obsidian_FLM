import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../subjects/domain/subject_workspace.dart';
import '../application/llm_client.dart';
import 'gemini_request.dart';
import 'gemini_response.dart';

class SecureGeminiKeyStore implements GeminiKeyStore {
  const SecureGeminiKeyStore();
  static const _storage = FlutterSecureStorage();
  static const _key = 'obsidian_flm.gemini.api_key';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String key) => _storage.write(key: _key, value: key);
  @override
  Future<void> delete() => _storage.delete(key: _key);
}

class GeminiLlmClient implements LlmClient {
  GeminiLlmClient({
    required this.keys,
    http.Client? client,
    this.model = const String.fromEnvironment(
      'GEMINI_MODEL',
      defaultValue: 'gemini-3.5-flash-lite',
    ),
    this.timeout = const Duration(seconds: 60),
    this.maxAttempts = 3,
    this.maxHistoryMessages = 20,
  }) : _client = client ?? http.Client(),
       _requestBuilder = GeminiRequestBuilder(
         maxHistoryMessages: maxHistoryMessages,
       );

  final GeminiKeyStore keys;
  final http.Client _client;
  final String model;
  final Duration timeout;

  /// Turns the generic prompt (context + history + attachments) into
  /// Gemini's request JSON. See [GeminiRequestBuilder].
  final GeminiRequestBuilder _requestBuilder;

  /// Turns Gemini's response JSON back into plain reply text. See
  /// [GeminiResponseParser].
  static const _responseParser = GeminiResponseParser();

  /// Total attempts (the first try plus retries) for a request that fails
  /// with a transient error. Gemini's `503` ("model overloaded") is by far
  /// the most common one — nothing is wrong with the request, the service
  /// is just momentarily busy, and a short backoff-and-retry clears it more
  /// often than not instead of surfacing an error the user has to notice
  /// and retry by hand.
  final int maxAttempts;

  /// How many of the most recent [ChatMessage]s to actually send as
  /// conversation history. The controller keeps (and persists) the whole
  /// chat, but resending all of it on every turn makes each request grow
  /// linearly with the conversation's length — a long-running chat can
  /// burn through a free-tier token/request quota in a handful of turns
  /// even though the user only asked a short question. Trimming to the
  /// most recent messages keeps per-request cost roughly constant; set to
  /// a large value (or override per instance) if full history is wanted
  /// for a short-lived chat.
  final int maxHistoryMessages;

  static final Random _jitter = Random();

  /// HTTP statuses worth an automatic retry: `503`/`502`/`504` (the
  /// service or an intermediary is momentarily unavailable) and `429`
  /// (rate/quota limit, which for a single user is usually a short-lived
  /// burst rather than a hard cap). `400`/`401`/`403`/`404` are the
  /// request's own fault and retrying them changes nothing.
  static const _retryableStatusCodes = {429, 500, 502, 503, 504};

  @override
  Future<String> send({
    required String context,
    required List<ChatMessage> messages,
    List<ChatAttachment> attachments = const [],
  }) async {
    try {
      final key = await keys.read();
      if (key == null || key.trim().isEmpty) {
        throw const WorkspaceFailure(
          'Add your Gemini API key to send a message.',
        );
      }
      if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(model)) {
        throw const WorkspaceFailure(
          'The configured Gemini model name is invalid.',
        );
      }

      final uri = Uri.https(
        'generativelanguage.googleapis.com',
        '/v1beta/models/$model:generateContent',
      );
      final headers = {
        'Content-Type': 'application/json',
        'x-goog-api-key': key.trim(),
      };
      final body = jsonEncode(
        _requestBuilder.build(
          context: context,
          messages: messages,
          attachments: attachments,
        ),
      );

      final response = await _postWithRetry(uri, headers, body);
      if (response.statusCode != 200) {
        throw WorkspaceFailure(switch (response.statusCode) {
          400 || 401 || 403 =>
            'Gemini rejected the request. Check your API key and API access, then retry.',
          404 =>
            'The configured Gemini model is unavailable. Update GEMINI_MODEL and retry.',
          429 =>
            'Gemini quota or rate limit reached (retried automatically). '
            'If this keeps happening, your API key has likely hit its '
            'daily free-tier request/token cap for this model — that '
            'resets at midnight Pacific time, not after a short wait. '
            'Check aistudio.google.com/rate-limit for your actual limits, '
            'or switch GEMINI_MODEL / enable billing for higher quota.',
          503 =>
            "Gemini's servers are temporarily overloaded (retried automatically). Please try again in a moment.",
          _ =>
            'Gemini is unavailable (HTTP ${response.statusCode}, retried automatically). Please retry later.',
        });
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final text = _responseParser.extractText(decoded);
      if (text.isEmpty) {
        throw const WorkspaceFailure(
          'Gemini returned no text. Try rephrasing your question.',
        );
      }
      return text;
    } on WorkspaceFailure {
      rethrow;
    } on TimeoutException {
      throw const WorkspaceFailure(
        'Gemini timed out. Check your connection and retry.',
      );
    } on SocketException {
      throw const WorkspaceFailure(
        'Cannot reach Gemini. Check your connection and retry.',
      );
    } on http.ClientException {
      throw const WorkspaceFailure(
        'Cannot reach Gemini. Check your connection and retry.',
      );
    } catch (_) {
      // Never surface response bodies, transport exceptions or credentials.
      throw const WorkspaceFailure(
        'Unable to read Gemini settings or its response. Check your key and retry.',
      );
    }
  }

  /// POSTs [body], retrying up to [maxAttempts] times (with exponential
  /// backoff + jitter) while the response's status is one of
  /// [_retryableStatusCodes]. A non-retryable status, a 200, or the last
  /// attempt returns/propagates immediately — the caller sees the same
  /// [http.Response] (or transport exception) it always did, just after
  /// this class already tried to ride out a transient failure.
  Future<http.Response> _postWithRetry(
    Uri uri,
    Map<String, String> headers,
    Object body,
  ) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final isLastAttempt = attempt == maxAttempts;
      http.Response? response;
      try {
        response = await _client
            .post(uri, headers: headers, body: body)
            .timeout(timeout);
        if (isLastAttempt || !_retryableStatusCodes.contains(response.statusCode)) {
          return response;
        }
      } on TimeoutException {
        if (isLastAttempt) rethrow;
      } on SocketException {
        if (isLastAttempt) rethrow;
      }
      // Gemini (like most APIs) sometimes tells us exactly how long to
      // wait via `Retry-After` on 429/503 — that is far more accurate
      // than guessing, and in particular a long value here is a strong
      // signal this is a hard daily quota rather than a momentary burst,
      // where our own short backoff would just waste an attempt.
      final retryAfter = _retryAfterDuration(response);
      if (retryAfter != null && retryAfter > const Duration(seconds: 5)) {
        throw const WorkspaceFailure(
          'Gemini quota exhausted for now (server asked to wait longer than '
          'this app retries automatically). Please try again later.',
        );
      }
      final backoffMs = retryAfter?.inMilliseconds ??
          // Exponential backoff (400ms, 800ms, 1600ms, ...) plus up to
          // 200ms of jitter so several concurrent retries don't all land
          // on the server at the exact same moment.
          400 * pow(2, attempt - 1).toInt();
      await Future.delayed(
        Duration(milliseconds: backoffMs + _jitter.nextInt(200)),
      );
    }
    // Unreachable: the loop above always returns or rethrows on the last
    // attempt. Only here to satisfy the analyzer's return-type check.
    throw const WorkspaceFailure('Gemini is unavailable. Please retry later.');
  }

  /// Parses the `Retry-After` header (seconds, per RFC 9110) off a
  /// response, if present and valid. Returns null when absent/unparseable
  /// so the caller falls back to its own backoff schedule.
  Duration? _retryAfterDuration(http.Response? response) {
    final raw = response?.headers['retry-after'];
    if (raw == null) return null;
    final seconds = int.tryParse(raw.trim());
    if (seconds == null || seconds < 0) return null;
    return Duration(seconds: seconds);
  }

  @override
  void close() => _client.close();
}
