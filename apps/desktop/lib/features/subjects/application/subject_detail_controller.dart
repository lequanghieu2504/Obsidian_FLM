import 'package:flutter/foundation.dart';

import '../../assistant/application/llm_client.dart';
import '../../knowledge_graph/data/subject_repository.dart';
import '../../knowledge_graph/domain/subject_record.dart';
import '../domain/subject_workspace.dart';

class SubjectDetailController extends ChangeNotifier {
  SubjectDetailController({
    required this.workspace,
    required this.repository,
    required this.llm,
    required this.keys,
    this.attachmentProcessor,
    this.syllabusRepository = const SubjectRepository(),
  });

  final SubjectWorkspace workspace;
  final SubjectWorkspaceRepository repository;
  final LlmClient llm;
  final GeminiKeyStore keys;
  final ChatAttachmentProcessor? attachmentProcessor;

  /// Loads this subject's full FLM syllabus record from `data/subject/`
  /// (the knowledge-graph feature's own repository, reused here so the
  /// detail screen and the Gemini prompt both show/send the richer data
  /// instead of just the curriculum's Code/Name/Semester/Credits).
  final SubjectRepository syllabusRepository;
  SubjectRecord? syllabus;
  bool syllabusLoading = true;
  String? syllabusError;
  List<UserResource> _resources = [];
  List<ChatMessage> _messages = [];
  List<UserResource> get resources => List.unmodifiable(_resources);
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool resourcesLoading = true;
  bool chatLoading = true;
  bool resourceBusy = false;
  bool sending = false;
  bool keyBusy = false;
  bool hasKey = false;
  bool resourcesReady = false;
  bool chatReady = false;
  bool _disposed = false;
  String? resourceError;
  String? chatError;
  String? keyError;
  String draft = '';
  final Set<String> _selectedResourceIds = {};
  Set<String> get selectedResourceIds => Set.unmodifiable(_selectedResourceIds);
  List<UserResource> get selectedResources => _resources
      .where((resource) => _selectedResourceIds.contains(resource.id))
      .toList(growable: false);
  UserResource? resourceById(String id) =>
      _resources.where((resource) => resource.id == id).firstOrNull;
  ChatMessage? _unsavedAnswer;
  List<ChatAttachment>? _preparedAttachments;
  bool get canRetry =>
      chatReady &&
      !sending &&
      _messages.isNotEmpty &&
      _messages.last.role == ChatRole.user;
  bool get canSend => chatReady && hasKey && !sending && !keyBusy && !canRetry;

  void setResourceSelected(String resourceId, bool selected) {
    if (selected) {
      _selectedResourceIds.add(resourceId);
    } else {
      _selectedResourceIds.remove(resourceId);
    }
    _changed();
  }

  void removeSelectedResource(String resourceId) {
    if (_selectedResourceIds.remove(resourceId)) _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    await Future.wait([loadResources(), loadChat(), loadKey(), loadSyllabus()]);
  }

  Future<void> loadSyllabus() async {
    syllabusLoading = true;
    syllabusError = null;
    _changed();
    try {
      syllabus = await syllabusRepository.loadByCode(workspace.subjectCode);
    } catch (_) {
      syllabus = null;
      syllabusError = 'Cannot load the full syllabus for this subject.';
    } finally {
      syllabusLoading = false;
      _changed();
    }
  }

  Future<void> loadResources() async {
    if (resourceBusy) return;
    resourcesLoading = true;
    resourceError = null;
    _changed();
    try {
      _resources = await repository.loadResources(workspace);
      resourcesReady = true;
    } catch (_) {
      resourcesReady = false;
      resourceError =
          'Cannot load local resources. Check storage access and retry. Existing data has been preserved.';
    } finally {
      resourcesLoading = false;
      _changed();
    }
  }

  Future<void> loadChat() async {
    if (sending) return;
    chatLoading = true;
    chatError = null;
    _changed();
    try {
      _messages = await repository.loadChat(workspace);
      chatReady = true;
      if (canRetry) {
        chatError = 'The last message has no saved answer. Retry to continue.';
      }
    } catch (_) {
      chatReady = false;
      chatError =
          'Cannot load this conversation. Check storage access and retry. Existing data has been preserved.';
    } finally {
      chatLoading = false;
      _changed();
    }
  }

  Future<void> loadKey() async {
    try {
      hasKey = (await keys.read())?.trim().isNotEmpty ?? false;
      keyError = null;
    } catch (_) {
      hasKey = false;
      keyError =
          'Secure key storage is unavailable. Check your system credential store.';
    }
    _changed();
  }

  Future<bool> saveKey(String key) async {
    if (keyBusy || sending || key.trim().isEmpty) return false;
    keyBusy = true;
    keyError = null;
    _changed();
    try {
      await keys.write(key.trim());
      hasKey = true;
      return true;
    } catch (_) {
      keyError =
          'Could not save the key securely. Check your system credential store and retry.';
      return false;
    } finally {
      keyBusy = false;
      _changed();
    }
  }

  Future<void> removeKey() async {
    if (keyBusy || sending) return;
    keyBusy = true;
    keyError = null;
    _changed();
    try {
      await keys.delete();
      hasKey = false;
    } catch (_) {
      keyError =
          'Could not remove the key. Check your system credential store and retry.';
    } finally {
      keyBusy = false;
      _changed();
    }
  }

  Future<List<UserResource>> importFiles(List<String> paths) async {
    if (resourceBusy || !resourcesReady) return const [];
    resourceBusy = true;
    resourceError = null;
    _changed();
    var failed = 0;
    final imported = <UserResource>[];
    try {
      for (final path in paths) {
        try {
          final resource = await repository.importResource(workspace, path);
          _resources = [..._resources, resource];
          imported.add(resource);
          _changed();
        } catch (_) {
          failed++;
        }
      }
      if (failed > 0) {
        resourceError =
            '$failed file(s) could not be imported. Check file access and free disk space, then try again.';
      }
    } finally {
      resourceBusy = false;
      _changed();
    }
    return imported;
  }

  void reportResourceError(String message) {
    resourceError = message;
    _changed();
  }

  Future<void> deleteResource(UserResource resource) async {
    if (resourceBusy || !resourcesReady) return;
    resourceBusy = true;
    resourceError = null;
    _changed();
    try {
      await repository.deleteResource(workspace, resource);
      _resources = _resources.where((r) => r.id != resource.id).toList();
      _selectedResourceIds.remove(resource.id);
    } catch (_) {
      resourceError =
          'Could not finish deleting the local copy. Reload resources and retry.';
    } finally {
      resourceBusy = false;
      _changed();
    }
  }

  /// Returns true once the user message is durable, so the composer can clear.
  Future<bool> send(String content) async {
    if (!canSend || content.trim().isEmpty) return false;
    sending = true;
    chatError = null;
    _changed();
    final resourceIds = _selectedResourceIds.toList(growable: false);
    try {
      _preparedAttachments = await _prepareAttachments(resourceIds);
    } on WorkspaceFailure catch (failure) {
      chatError = failure.message;
      sending = false;
      _changed();
      return false;
    } catch (_) {
      chatError =
          'A selected resource could not be prepared. Check that its local copy still exists.';
      sending = false;
      _changed();
      return false;
    }
    final next = [
      ..._messages,
      ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        role: ChatRole.user,
        content: content.trim(),
        timestamp: DateTime.now().toUtc(),
        resourceIds: resourceIds,
        resourceFileNames: {
          for (final resource in selectedResources)
            resource.id: resource.originalFileName,
        },
      ),
    ];
    try {
      await repository.saveChat(workspace, next);
      _messages = next;
      _selectedResourceIds.clear();
      _changed();
    } catch (_) {
      chatError =
          'Your message could not be saved. Check storage access and send again.';
      _preparedAttachments = null;
      sending = false;
      _changed();
      return false;
    }
    await _answer();
    return true;
  }

  Future<void> retry() async {
    if (!canRetry || !hasKey || keyBusy) return;
    sending = true;
    chatError = null;
    _changed();
    await _answer();
  }

  Future<void> _answer() async {
    try {
      final resourceIds = _messages.last.role == ChatRole.user
          ? _messages.last.resourceIds
          : const <String>[];
      final attachments =
          _preparedAttachments ?? await _prepareAttachments(resourceIds);
      _preparedAttachments = null;
      _unsavedAnswer ??= ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        role: ChatRole.assistant,
        content: await llm.send(
          context: const SubjectPromptBuilder().build(
            workspace,
            syllabus: syllabus,
          ),
          messages: messages,
          attachments: attachments,
        ),
        timestamp: DateTime.now().toUtc(),
      );
      final next = [..._messages, _unsavedAnswer!];
      await repository.saveChat(workspace, next);
      _messages = next;
      _unsavedAnswer = null;
    } on WorkspaceFailure catch (failure) {
      chatError = failure.message;
    } catch (_) {
      chatError = _unsavedAnswer != null
          ? 'The answer could not be saved. Retry to save it without requesting Gemini again.'
          : 'The request failed. Check your connection and retry.';
    } finally {
      sending = false;
      _changed();
    }
  }

  Future<List<ChatAttachment>> _prepareAttachments(
    List<String> resourceIds,
  ) async {
    if (resourceIds.isEmpty) return const [];
    final processor = attachmentProcessor;
    if (processor == null) {
      throw const WorkspaceFailure(
        'File attachments are unavailable in this application build.',
      );
    }
    final attachments = <ChatAttachment>[];
    for (final id in resourceIds) {
      final resource = _resources.where((item) => item.id == id).firstOrNull;
      if (resource == null) {
        throw const WorkspaceFailure(
          'A selected resource is unavailable. Remove it and try again.',
        );
      }
      final path = await repository.resourcePath(workspace, resource);
      attachments.add(await processor.process(resource, path));
    }
    return attachments;
  }

  Future<void> clearChat() async {
    if (sending || !chatReady) return;
    sending = true;
    _changed();
    try {
      await repository.saveChat(workspace, []);
      _messages = [];
      _unsavedAnswer = null;
      chatError = null;
    } catch (_) {
      chatError =
          'Could not clear the conversation. Check storage access and try again.';
    } finally {
      sending = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    llm.close();
    super.dispose();
  }
}
