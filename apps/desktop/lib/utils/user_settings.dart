import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

/// App-wide user settings — the ONE place the Gemini API key and model live.
///
/// Both AI surfaces read from here:
///  * "Trợ lý học vụ" (lib/services/chat_service.dart + ui/widgets/chat_box.dart)
///  * the per-subject assistant (lib/features/assistant/infrastructure/
///    gemini_llm_client.dart, via [SecureGeminiKeyStore]).
///
/// Storage:
///  * API key  -> OS credential store (Windows Credential Manager / Keychain /
///    libsecret) through flutter_secure_storage. It is never written to any
///    file inside the project folder, so it can't end up in git.
///  * name / model -> data/user_settings.json (non-secret, git-ignored).
///
/// The user enters the key once; it is reloaded on every app start until they
/// change or remove it.
class UserSettings {
  static const defaultUserName = 'Sinh Viên FPT';
  static const defaultModel = 'gemini-3.8-flash';

  static const List<String> validModels = [
    'gemini-3.8-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.1-pro-preview',
  ];

  static const Map<String, String> modelLabels = {
    'gemini-3.8-flash': 'Gemini 3.8 Flash',
    'gemini-3.5-flash-lite': 'Gemini 3.5 Flash-Lite',
    'gemini-3.1-pro-preview': 'Gemini Pro (Bản cũ)',
  };

  /// Same secure-storage entry the subject assistant used before the merge,
  /// so a key saved there earlier keeps working.
  static const apiKeyStorageKey = 'obsidian_flm.gemini.api_key';
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  static String userName = defaultUserName;
  static String geminiApiKey = '';
  static String geminiModel = defaultModel;

  /// Bumped whenever the key or model changes, so every open chat can react.
  static final ValueNotifier<int> aiSettingsRevision = ValueNotifier(0);

  static bool get hasApiKey => geminiApiKey.trim().isNotEmpty;

  static Future<void>? _loading;

  /// Loads once per app run (safe to call from several places).
  static Future<void> ensureLoaded() => _loading ??= load();

  static Future<File> _getSettingsFile() async {
    final dataDir = Directory(p.join(Directory.current.path, 'data'));
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    return File(p.join(dataDir.path, 'user_settings.json'));
  }

  static Future<void> load() async {
    String legacyKey = '';
    try {
      final file = await _getSettingsFile();
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        final name = json['userName']?.toString().trim() ?? '';
        if (name.isNotEmpty) userName = name;
        final model = json['geminiModel']?.toString().trim() ?? '';
        if (validModels.contains(model)) geminiModel = model;
        // Older builds stored the key in plain text in this file.
        legacyKey = json['geminiApiKey']?.toString().trim() ?? '';
      }
    } catch (_) {
      // Ignore errors, use defaults.
    }

    try {
      geminiApiKey = (await _secure.read(key: apiKeyStorageKey))?.trim() ?? '';
    } catch (_) {
      geminiApiKey = '';
    }

    if (legacyKey.isNotEmpty) {
      // Move the plain-text key into the credential store and scrub the file.
      if (geminiApiKey.isEmpty) {
        try {
          await _secure.write(key: apiKeyStorageKey, value: legacyKey);
          geminiApiKey = legacyKey;
        } catch (_) {
          geminiApiKey = legacyKey;
        }
      }
      await _writeFile();
    }
    aiSettingsRevision.value++;
  }

  static Future<void> _writeFile() async {
    try {
      final file = await _getSettingsFile();
      await file.writeAsString(jsonEncode({
        'userName': userName,
        'geminiModel': geminiModel,
      }));
    } catch (_) {
      // Ignore errors.
    }
  }

  static Future<void> saveUserName(String name) async {
    userName = name.trim().isEmpty ? defaultUserName : name.trim();
    await _writeFile();
  }

  /// Saves the API key (to the OS credential store) and the model.
  /// Throws if the credential store is unavailable.
  static Future<void> saveGeminiSettings(String apiKey, String model) async {
    final key = apiKey.trim();
    if (key.isNotEmpty && key != geminiApiKey) {
      await _secure.write(key: apiKeyStorageKey, value: key);
      geminiApiKey = key;
    }
    geminiModel = validModels.contains(model.trim()) ? model.trim() : defaultModel;
    await _writeFile();
    aiSettingsRevision.value++;
  }

  static Future<void> clearApiKey() async {
    await _secure.delete(key: apiKeyStorageKey);
    geminiApiKey = '';
    aiSettingsRevision.value++;
  }
}
