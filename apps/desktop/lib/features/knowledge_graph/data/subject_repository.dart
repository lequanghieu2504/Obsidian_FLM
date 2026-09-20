import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/subject_record.dart';

/// Loads every `data/subject/<id>.json` FLM export bundled with the app.
///
/// The files are declared as Flutter assets (see `pubspec.yaml`) rather than
/// read from the filesystem with `dart:io`. That keeps loading identical
/// between `flutter run`, a packaged Windows/macOS/Linux build, and any
/// other target Flutter supports, instead of depending on the working
/// directory a binary happens to be launched from.
class SubjectRepository {
  const SubjectRepository({this.assetDirectory = 'data/subject/'});

  final String assetDirectory;

  Future<List<SubjectRecord>> loadAll() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assetPaths = manifest
        .listAssets()
        .where((path) => path.startsWith(assetDirectory))
        .where((path) => path.endsWith('.json'))
        .toList()
      ..sort();

    final subjects = <SubjectRecord>[];
    for (final path in assetPaths) {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) continue;

      final fileName = path.split('/').last;
      final fallbackId = fileName.substring(0, fileName.length - '.json'.length);

      subjects.add(SubjectRecord.fromJson(decoded, fallbackId: fallbackId));
    }
    return subjects;
  }
}
