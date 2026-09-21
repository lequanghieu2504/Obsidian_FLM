import 'dart:io';

import '../../subjects/domain/subject_workspace.dart';
import '../application/llm_client.dart';

class LocalChatAttachmentProcessor implements ChatAttachmentProcessor {
  const LocalChatAttachmentProcessor({this.maxBytes = 20 * 1024 * 1024});

  final int maxBytes;

  @override
  Future<ChatAttachment> process(
    UserResource resource,
    String appOwnedPath,
  ) async {
    final file = File(appOwnedPath);
    if (!await file.exists()) {
      throw WorkspaceFailure('${resource.originalFileName} is unavailable.');
    }
    if (await file.length() > maxBytes) {
      throw WorkspaceFailure(
        '${resource.originalFileName} is too large to attach (20 MB maximum).',
      );
    }
    final extension = resource.extension.toLowerCase();
    if (extension == '.txt' || extension == '.csv') {
      try {
        return ChatAttachment(
          resourceId: resource.id,
          fileName: resource.originalFileName,
          mimeType: extension == '.csv' ? 'text/csv' : 'text/plain',
          text: await file.readAsString(),
        );
      } catch (_) {
        throw WorkspaceFailure(
          '${resource.originalFileName} could not be read as text.',
        );
      }
    }
    final mimeType = switch (extension) {
      '.pdf' => 'application/pdf',
      '.png' => 'image/png',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.webp' => 'image/webp',
      _ => null,
    };
    if (mimeType == null) {
      throw WorkspaceFailure(
        '${resource.originalFileName} is stored locally but is not supported as a Gemini attachment.',
      );
    }
    return ChatAttachment(
      resourceId: resource.id,
      fileName: resource.originalFileName,
      mimeType: mimeType,
      bytes: await file.readAsBytes(),
    );
  }
}
