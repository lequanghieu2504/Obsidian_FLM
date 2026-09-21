import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../assistant/presentation/simple_markdown.dart';
import '../application/subject_detail_controller.dart';
import '../domain/subject_workspace.dart';

class SubjectChatPanel extends StatefulWidget {
  const SubjectChatPanel({super.key, required this.controller});
  final SubjectDetailController controller;
  @override
  State<SubjectChatPanel> createState() => _SubjectChatPanelState();
}

class _SubjectChatPanelState extends State<SubjectChatPanel>
    with AutomaticKeepAliveClientMixin {
  final _text = TextEditingController();
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    _text.text = widget.controller.draft;
    _text.addListener(_saveDraft);
  }

  void _saveDraft() => widget.controller.draft = _text.text;

  @override
  void didUpdateWidget(SubjectChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _text.text = widget.controller.draft;
    }
  }

  @override
  bool get wantKeepAlive => true;
  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final draft = _text.text;
    if (draft.trim().isEmpty) return;
    // Reset the composer as soon as the question is sent, rather than
    // waiting on the (possibly slow) Gemini round-trip — the user should
    // see the input box clear right after asking.
    _text.clear();
    final accepted = await widget.controller.send(draft);
    if (!mounted) return;
    if (!accepted) {
      // Sending was rejected (e.g. a selected attachment failed to
      // prepare) — restore what the user typed instead of losing it.
      _text.text = draft;
      _text.selection = TextSelection.collapsed(offset: draft.length);
    }
    _focus.requestFocus();
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear this conversation?'),
        content: Text(
          'Delete chat history for ${widget.controller.workspace.curriculumCode} / ${widget.controller.workspace.subjectCode}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear conversation'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.clearChat();
  }

  Future<void> _pickAttachments() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AttachmentPicker(controller: widget.controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = widget.controller;
    final theme = Theme.of(context);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text('Gemini Assistant', style: theme.textTheme.titleLarge),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: controller.hasKey
                          ? 'Manage Gemini key'
                          : 'Add Gemini key',
                      onPressed: controller.sending || controller.keyBusy
                          ? null
                          : () => showDialog<void>(
                              context: context,
                              builder: (_) =>
                                  _GeminiKeyDialog(controller: controller),
                            ),
                      icon: const Icon(Icons.key_outlined),
                    ),
                    IconButton(
                      tooltip: 'Clear conversation',
                      onPressed:
                          controller.sending ||
                              !controller.chatReady ||
                              controller.messages.isEmpty
                          ? null
                          : _clear,
                      icon: const Icon(Icons.delete_sweep_outlined),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Subject context and messages are sent to Gemini when you ask. Resources stay local unless you explicitly attach them.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const Divider(),
          Expanded(
            child: controller.chatLoading
                ? const Center(child: CircularProgressIndicator())
                : controller.messages.isEmpty
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 36),
                        const SizedBox(height: 16),
                        Text(
                          'Ask about ${controller.workspace.subjectCode}',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Explore a concept, ask for a study explanation, or work through a question.',
                        ),
                        if (!controller.hasKey) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Add your own Gemini API key using the key button above.',
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: controller.messages.length,
                    itemBuilder: (context, index) {
                      final message = controller
                          .messages[controller.messages.length - 1 - index];
                      final isUser = message.role == ChatRole.user;
                      final bubbleColor = isUser
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest;
                      final onBubbleColor = isUser
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isUser
                                      ? Icons.person_outline
                                      : Icons.auto_awesome_outlined,
                                  size: 16,
                                  color: onBubbleColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isUser ? 'You' : 'Gemini',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: onBubbleColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SimpleMarkdown(
                              data: message.content,
                              baseStyle: theme.textTheme.bodyLarge?.copyWith(
                                color: onBubbleColor,
                                height: 1.5,
                              ),
                            ),
                            if (message.resourceIds.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: message.resourceIds.map((id) {
                                  final resource = controller.resourceById(id);
                                  return Chip(
                                    avatar: const Icon(
                                      Icons.attach_file,
                                      size: 16,
                                    ),
                                    label: Text(
                                      resource == null
                                          ? '${message.resourceFileNames[id] ?? 'Attachment'} · unavailable'
                                          : resource.originalFileName,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // Error and composer area scrolls within a height cap on short windows.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .20,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (controller.keyError != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          controller.keyError!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    if (controller.chatError != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          controller.chatError!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: controller.sending
                              ? null
                              : !controller.chatReady
                              ? controller.loadChat
                              : controller.canRetry && controller.hasKey
                              ? controller.retry
                              : null,
                          child: Text(
                            controller.chatReady
                                ? 'Retry answer'
                                : 'Reload conversation',
                          ),
                        ),
                      ),
                    ],
                    if (controller.sending) ...[
                      const LinearProgressIndicator(
                        semanticsLabel: 'Waiting for Gemini',
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: const Text('Waiting for Gemini…'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (controller.selectedResources.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: controller.selectedResources
                            .map(
                              (resource) => InputChip(
                                label: Text(resource.originalFileName),
                                onDeleted: controller.sending
                                    ? null
                                    : () => controller.removeSelectedResource(
                                        resource.id,
                                      ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          '${controller.selectedResources.length} file${controller.selectedResources.length == 1 ? '' : 's'} will be sent with this message.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Shortcuts(
                      shortcuts: const {
                        SingleActivator(
                          LogicalKeyboardKey.enter,
                          control: true,
                        ): ActivateIntent(),
                      },
                      child: Actions(
                        actions: {
                          ActivateIntent: CallbackAction<ActivateIntent>(
                            onInvoke: (_) {
                              if (controller.canSend &&
                                  _text.text.trim().isNotEmpty) {
                                _send();
                              }
                              return null;
                            },
                          ),
                        },
                        child: TextField(
                          controller: _text,
                          focusNode: _focus,
                          readOnly: controller.sending,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 16000,
                          decoration: const InputDecoration(
                            labelText: 'Ask a question',
                            helperText: 'Ctrl+Enter to send',
                            border: OutlineInputBorder(),
                            counterText: '',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed:
                              controller.sending ||
                                  !controller.resourcesReady ||
                                  controller.resources.isEmpty
                              ? null
                              : _pickAttachments,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Attach resource'),
                        ),
                        SizedBox(
                          width: 140,
                          child: ValueListenableBuilder(
                            valueListenable: _text,
                            builder: (context, value, _) => FilledButton.icon(
                              onPressed:
                                  controller.canSend &&
                                      value.text.trim().isNotEmpty
                                  ? _send
                                  : null,
                              icon: const Icon(Icons.send_outlined),
                              label: const Text('Send'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentPicker extends StatefulWidget {
  const _AttachmentPicker({required this.controller});
  final SubjectDetailController controller;
  @override
  State<_AttachmentPicker> createState() => _AttachmentPickerState();
}

class _AttachmentPickerState extends State<_AttachmentPicker> {
  late final Set<String> selected = Set.of(
    widget.controller.selectedResourceIds,
  );

  String _size(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      'Attach resources from ${widget.controller.workspace.subjectCode}',
    ),
    content: SizedBox(
      width: 520,
      height: 360,
      child: ListView.builder(
        itemCount: widget.controller.resources.length,
        itemBuilder: (context, index) {
          final resource = widget.controller.resources[index];
          return CheckboxListTile(
            value: selected.contains(resource.id),
            onChanged: (value) => setState(() {
              if (value ?? false) {
                selected.add(resource.id);
              } else {
                selected.remove(resource.id);
              }
            }),
            title: Text(
              resource.originalFileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${resource.extension.isEmpty ? 'File' : resource.extension.substring(1).toUpperCase()} · ${_size(resource.size)}',
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          for (final resource in widget.controller.resources) {
            widget.controller.setResourceSelected(
              resource.id,
              selected.contains(resource.id),
            );
          }
          Navigator.pop(context);
        },
        child: Text('Attach ${selected.length} files'),
      ),
    ],
  );
}

class _GeminiKeyDialog extends StatefulWidget {
  const _GeminiKeyDialog({required this.controller});
  final SubjectDetailController controller;
  @override
  State<_GeminiKeyDialog> createState() => _GeminiKeyDialogState();
}

class _GeminiKeyDialogState extends State<_GeminiKeyDialog> {
  final _key = TextEditingController();
  @override
  void dispose() {
    _key.clear();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => AlertDialog(
      title: const Text('Your Gemini API key'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Stored in your system credential store. Your existing key is never displayed.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _key,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                autofocus: true,
                readOnly: widget.controller.keyBusy,
                decoration: const InputDecoration(
                  labelText: 'Gemini API key',
                  border: OutlineInputBorder(),
                ),
              ),
              if (widget.controller.keyError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      widget.controller.keyError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.controller.hasKey)
          TextButton(
            onPressed: widget.controller.keyBusy
                ? null
                : () async {
                    await widget.controller.removeKey();
                    if (context.mounted && !widget.controller.hasKey) {
                      Navigator.pop(context);
                    }
                  },
            child: const Text('Remove key'),
          ),
        TextButton(
          onPressed: widget.controller.keyBusy
              ? null
              : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder(
          valueListenable: _key,
          builder: (context, value, _) => FilledButton(
            onPressed: widget.controller.keyBusy || value.text.trim().isEmpty
                ? null
                : () async {
                    final saved = await widget.controller.saveKey(_key.text);
                    if (context.mounted && saved) Navigator.pop(context);
                  },
            child: Text(widget.controller.keyBusy ? 'Saving…' : 'Save key'),
          ),
        ),
      ],
    ),
  );
}
