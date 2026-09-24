import 'dart:io';

import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

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
    const textMimeTypes = <String, String>{
      '.txt': 'text/plain',
      '.md': 'text/markdown',
      '.markdown': 'text/markdown',
      '.csv': 'text/csv',
      '.json': 'application/json',
      '.yaml': 'application/yaml',
      '.yml': 'application/yaml',
      '.log': 'text/plain',
    };
    final textMimeType = textMimeTypes[extension];
    if (textMimeType != null) {
      try {
        return ChatAttachment(
          resourceId: resource.id,
          fileName: resource.originalFileName,
          mimeType: textMimeType,
          text: await file.readAsString(),
        );
      } catch (_) {
        throw WorkspaceFailure(
          '${resource.originalFileName} could not be read as text.',
        );
      }
    }
    if (extension == '.xlsx') {
      try {
        final workbook = SpreadsheetDecoder.decodeBytes(
          await file.readAsBytes(),
          update: false,
        );
        final text = StringBuffer();
        for (final entry in workbook.tables.entries) {
          text.writeln('Sheet: ${entry.key}');
          for (final row in entry.value.rows) {
            text.writeln(
              row.map((cell) => cell?.toString() ?? '').join('\t').trimRight(),
            );
          }
          text.writeln();
        }
        return ChatAttachment(
          resourceId: resource.id,
          fileName: resource.originalFileName,
          mimeType: 'text/tab-separated-values',
          text: text.toString().trim(),
        );
      } catch (_) {
        throw WorkspaceFailure(
          '${resource.originalFileName} could not be read as a spreadsheet.',
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
