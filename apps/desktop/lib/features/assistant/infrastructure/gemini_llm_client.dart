import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../subjects/domain/subject_workspace.dart';
import '../application/llm_client.dart';

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
      defaultValue: 'gemini-3.6-flash',
    ),
    this.timeout = const Duration(seconds: 60),
  }) : _client = client ?? http.Client();

  final GeminiKeyStore keys;
  final http.Client _client;
  final String model;
  final Duration timeout;

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
      final response = await _client
          .post(
            Uri.https(
              'generativelanguage.googleapis.com',
              '/v1beta/models/$model:generateContent',
            ),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': key.trim(),
            },
            body: jsonEncode({
              'systemInstruction': {
                'parts': [
                  {'text': context},
                ],
              },
              'contents': messages.indexed
                  .map(
                    (entry) => {
                      ...(() {
                        final (index, m) = entry;
                        final isCurrentMessage = index == messages.length - 1;
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
                                          'data': base64Encode(
                                            attachment.bytes!,
                                          ),
                                        },
                                      },
                              ),
                          ],
                        };
                      })(),
                    },
                  )
                  .toList(),
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw WorkspaceFailure(switch (response.statusCode) {
          400 || 401 || 403 =>
            'Gemini rejected the request. Check your API key and API access, then retry.',
          404 =>
            'The configured Gemini model is unavailable. Update GEMINI_MODEL and retry.',
          429 =>
            'Gemini quota or rate limit reached. Wait or check your quota, then retry.',
          _ =>
            'Gemini is unavailable (HTTP ${response.statusCode}). Please retry later.',
        });
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = body['candidates'] as List<dynamic>? ?? [];
      if (candidates.isEmpty) {
        throw const WorkspaceFailure(
          'Gemini returned no answer. Try rephrasing your question.',
        );
      }
      final candidate = candidates.first as Map<String, dynamic>;
      final content = candidate['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>? ?? [];
      final text = parts
          .whereType<Map<String, dynamic>>()
          .where((part) => part['thought'] != true)
          .map((part) => part['text'] as String? ?? '')
          .join('\n')
          .trim();
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

  @override
  void close() => _client.close();
}
