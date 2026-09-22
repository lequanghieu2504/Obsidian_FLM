import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class UserSettings {
  static String userName = 'Sinh Viên FPT';
  static String geminiApiKey = '';
  static String geminiModel = 'gemini-3.8-flash';

  static final List<String> validModels = ['gemini-3.1-pro-preview', 'gemini-3.5-flash-lite', 'gemini-3.8-flash'];

  static Future<File> _getSettingsFile() async {
    final currentDir = Directory.current;
    final dataDir = Directory(p.join(currentDir.path, 'data'));
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    return File(p.join(dataDir.path, 'user_settings.json'));
  }

  static Future<void> load() async {
    try {
      final file = await _getSettingsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content);
        if (json['userName'] != null &&
            json['userName'].toString().trim().isNotEmpty) {
          userName = json['userName'];
        }
        if (json['geminiApiKey'] != null) {
          geminiApiKey = json['geminiApiKey'];
        }
        if (json['geminiModel'] != null &&
            json['geminiModel'].toString().trim().isNotEmpty) {
          geminiModel = json['geminiModel'];
        }
      }
    } catch (e) {
      // Ignore errors, use default
    }
  }

  static Future<void> saveUserName(String name) async {
    try {
      final finalName = name.trim().isEmpty ? 'Sinh Viên FPT' : name.trim();
      userName = finalName;
      final file = await _getSettingsFile();
      await file.writeAsString(jsonEncode({
        'userName': finalName,
        'geminiApiKey': geminiApiKey,
        'geminiModel': geminiModel,
      }));
    } catch (e) {
      // Ignore errors
    }
  }

  static Future<void> saveGeminiSettings(String apiKey, String model) async {
    try {
      geminiApiKey = apiKey.trim();
      geminiModel = model.trim().isEmpty ? 'gemini-3.8-flash' : model.trim();
      final file = await _getSettingsFile();
      await file.writeAsString(jsonEncode({
        'userName': userName,
        'geminiApiKey': geminiApiKey,
        'geminiModel': geminiModel,
      }));
    } catch (e) {
      // Ignore errors
    }
  }
}
