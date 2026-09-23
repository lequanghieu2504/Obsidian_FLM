import 'package:flutter/widgets.dart';
import '../utils/user_settings.dart';
import 'app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the shared Gemini key/model once, before any chat is built.
  await UserSettings.ensureLoaded();
  runApp(const ObsidianFlmApp());
}
