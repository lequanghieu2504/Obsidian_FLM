import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../domain/subject_workspace.dart';

/// Owns only durable user data. Never reads or writes Curriculum source storage.
class LocalSubjectWorkspaceRepository implements SubjectWorkspaceRepository {
  LocalSubjectWorkspaceRepository(this.root);
  final Directory root;
  static final Map<String, Future<void>> _locks = {};
  static const _uuid = Uuid();

  // Encoding every byte avoids separators, reserved Windows names and case-only
  // collisions on Windows. The original identities remain in metadata.
  String _segment(String value) {
    if (value.trim().isEmpty) {
      throw const FormatException('Empty workspace identity');
    }
    return 'id-${utf8.encode(value).map((v) => v.toRadixString(16).padLeft(2, '0')).join()}';
  }

  Future<T> _locked<T>(Future<T> Function() operation) async {
    final key = p.normalize(p.absolute(root.path)).toLowerCase();
    final previous = _locks[key] ?? Future<void>.value();
    final done = Completer<void>();
    _locks[key] = done.future;
    await previous;
    try {
      return await operation();
    } finally {
      done.complete();
      if (identical(_locks[key], done.future)) _locks.remove(key);
    }
  }

  Future<Directory> _directory(SubjectWorkspace workspace) async {
    await root.create(recursive: true);
    var directory = Directory(await root.resolveSymbolicLinks());
    for (final segment in [
      'curricula',
      _segment(workspace.curriculumCode),
      'subjects',
      _segment(workspace.subjectCode),
    ]) {
      directory = Directory(p.join(directory.path, segment));
      final type = await FileSystemEntity.type(
        directory.path,
        followLinks: false,
      );
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.directory) {
        throw const FileSystemException('Unsafe workspace directory');
      }
      await directory.create();
    }
    return directory;
  }

  Future<File> _safeFile(Directory directory, String name) async {
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        name.contains('/') ||
        name.contains(r'\') ||
        name.contains(':') ||
        p.basename(name) != name) {
      throw const FormatException('Unsafe stored filename');
    }
    final file = File(p.join(directory.path, name));
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.file) {
      throw const FileSystemException('Unsafe stored file');
    }
    return file;
  }

  Future<Directory> _resourcesDirectory(Directory directory) async {
    final resources = Directory(p.join(directory.path, 'resources'));
    final type = await FileSystemEntity.type(
      resources.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.directory) {
      throw const FileSystemException('Unsafe resource directory');
    }
    await resources.create();
    return resources;
  }

  Future<List<dynamic>> _read(Directory directory, String name) async {
    final file = await _safeFile(directory, name);
    if (!await file.exists()) return [];
    return jsonDecode(await file.readAsString()) as List<dynamic>;
  }

  Future<void> _write(
    Directory directory,
    String name,
    List<dynamic> data,
  ) async {
    final target = await _safeFile(directory, name);
    final temporary = await _safeFile(directory, '${_uuid.v4()}.tmp');
    try {
      await temporary.writeAsString(jsonEncode(data), flush: true);
      await temporary.rename(target.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<List<UserResource>> _loadResources(
    SubjectWorkspace workspace,
    Directory directory,
  ) async {
    final rows = await _read(directory, 'resources.json');
    final resources = rows
        .map((row) => UserResource.fromJson(row as Map<String, dynamic>))
        .toList();
    final files = await _resourcesDirectory(directory);
    for (final resource in resources) {
      _checkScope(workspace, resource);
      final file = await _safeFile(files, resource.storedFileName);
      final staged = await _safeFile(
        files,
        '${resource.storedFileName}.deleting',
      );
      // If the app stopped before committing metadata removal, restore the copy.
      if (!await file.exists() && await staged.exists()) {
        await staged.rename(file.path);
      }
    }
    final retained = resources
        .map((r) => '${r.storedFileName}.deleting')
        .toSet();
    await for (final entity in files.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (entity is File &&
          name.endsWith('.deleting') &&
          !retained.contains(name)) {
        await (await _safeFile(files, name)).delete();
      }
    }
    return resources;
  }

  void _checkScope(SubjectWorkspace workspace, UserResource resource) {
    if (resource.curriculumCode != workspace.curriculumCode ||
        resource.subjectCode != workspace.subjectCode) {
      throw const FormatException('Resource belongs to another workspace');
    }
  }

  @override
  Future<List<UserResource>> loadResources(SubjectWorkspace workspace) =>
      _locked(() async {
        return _loadResources(workspace, await _directory(workspace));
      });

  @override
  Future<UserResource> importResource(
    SubjectWorkspace workspace,
    String sourcePath,
  ) => _locked(() async {
    final directory = await _directory(workspace);
    final resources = await _loadResources(workspace, directory);
    final files = await _resourcesDirectory(directory);
    final source = File(sourcePath);
    final id = _uuid.v4();
    final extension = p.extension(sourcePath).toLowerCase();
    final safeExtension = RegExp(r'^\.[a-z0-9]{1,20}$').hasMatch(extension)
        ? extension
        : '';
    final target = await _safeFile(files, '$id$safeExtension');
    final partial = await _safeFile(files, '$id.part');
    try {
      await source.openRead().pipe(partial.openWrite());
      await partial.rename(target.path);
      final resource = UserResource(
        id: id,
        curriculumCode: workspace.curriculumCode,
        subjectCode: workspace.subjectCode,
        originalFileName: p.basename(sourcePath),
        storedFileName: p.basename(target.path),
        extension: extension,
        size: await target.length(),
        importedAt: DateTime.now().toUtc(),
      );
      await _write(
        directory,
        'resources.json',
        [...resources, resource].map((r) => r.toJson()).toList(),
      );
      return resource;
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      if (await target.exists()) await target.delete();
      rethrow;
    }
  });

  @override
  Future<void> deleteResource(
    SubjectWorkspace workspace,
    UserResource resource,
  ) => _locked(() async {
    _checkScope(workspace, resource);
    final directory = await _directory(workspace);
    final resources = await _loadResources(workspace, directory);
    final matches = resources.where((r) => r.id == resource.id);
    if (matches.isEmpty) return;
    // Trust persisted metadata, never a caller-provided path.
    final stored = matches.single;
    final files = await _resourcesDirectory(directory);
    final file = await _safeFile(files, stored.storedFileName);
    final staged = await _safeFile(files, '${stored.storedFileName}.deleting');
    if (await file.exists()) await file.rename(staged.path);
    try {
      await _write(
        directory,
        'resources.json',
        resources
            .where((r) => r.id != stored.id)
            .map((r) => r.toJson())
            .toList(),
      );
    } catch (_) {
      if (await staged.exists()) await staged.rename(file.path);
      rethrow;
    }
    if (await staged.exists()) await staged.delete();
  });

  @override
  Future<String> resourcePath(
    SubjectWorkspace workspace,
    UserResource resource,
  ) => _locked(() async {
    _checkScope(workspace, resource);
    final directory = await _directory(workspace);
    final resources = await _loadResources(workspace, directory);
    final stored = resources.singleWhere((r) => r.id == resource.id);
    final file = await _safeFile(
      await _resourcesDirectory(directory),
      stored.storedFileName,
    );
    if (!await file.exists()) {
      throw const WorkspaceFailure(
        'The local copy is missing. Import the file again.',
      );
    }
    return file.path;
  });

  @override
  Future<List<ChatMessage>> loadChat(SubjectWorkspace workspace) =>
      _locked(() async {
        final rows = await _read(
          await _directory(workspace),
          'chat_history.json',
        );
        return rows
            .map((row) => ChatMessage.fromJson(row as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<void> saveChat(
    SubjectWorkspace workspace,
    List<ChatMessage> messages,
  ) => _locked(() async {
    await _write(
      await _directory(workspace),
      'chat_history.json',
      messages.map((m) => m.toJson()).toList(),
    );
  });
}
