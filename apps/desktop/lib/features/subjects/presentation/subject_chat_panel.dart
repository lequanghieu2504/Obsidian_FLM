import 'package:flutter/material.dart';

import '../../../ui/widgets/assistant_chat_layout.dart';
import '../../../ui/widgets/ai_settings_form.dart';
import '../../../utils/user_settings.dart';
import '../application/subject_detail_controller.dart';
import '../domain/subject_workspace.dart';

class SubjectChatPanel extends StatefulWidget {
  const SubjectChatPanel({
    super.key,
    required this.controller,
    this.onCollapse,
  });
  final SubjectDetailController controller;

  /// Shown as a "Minimize" button in the header when set. The panel itself
  /// doesn't track a collapsed state — the parent (which owns the layout
  /// the panel sits in, e.g. [SubjectDetailScreen]'s resizable split) does,
  /// so collapsing can actually give the freed-up space back to the pane
  /// next to it instead of just shrinking this widget in place.
  final VoidCallback? onCollapse;
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
    // Enter sends, Shift+Enter new line (same helper as Trợ lý học vụ).
    _focus.onKeyEvent = AssistantComposer.enterToSend(
      canSendNow: () =>
          widget.controller.canSend && _text.text.trim().isNotEmpty,
      onSend: _send,
    );
    // The Gemini key/model are shared with "Trợ lý học vụ": refresh when
    // they change anywhere in the app.
    UserSettings.aiSettingsRevision.addListener(_onAiSettingsChanged);
  }

  void _onAiSettingsChanged() => widget.controller.loadKey();

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
    UserSettings.aiSettingsRevision.removeListener(_onAiSettingsChanged);
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
        title: const Text('Xóa lịch sử chat?'),
        content: Text(
          'Xóa toàn bộ lịch sử chat của ${widget.controller.workspace.curriculumCode} / ${widget.controller.workspace.subjectCode}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa lịch sử'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.clearChat();
  }

  Future<void> _openAiSettings() async {
    await showAiSettingsDialog(context);
    await widget.controller.loadKey();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = widget.controller;
    final theme = Theme.of(context);
    final errorStyle = TextStyle(color: theme.colorScheme.error);

    final Widget body;
    if (controller.chatLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (controller.messages.isEmpty) {
      body = AssistantEmptyState(
        title: 'Hỏi về ${controller.workspace.subjectCode}',
        description:
            'Hỏi một khái niệm, nhờ giải thích bài học hoặc cùng giải bài '
            'tập. Thông tin môn học và tin nhắn được gửi cho Gemini khi bạn '
            'hỏi; tài liệu chỉ được gửi khi bạn đính kèm.',
        children: [
          if (!controller.hasKey)
            const Text(
              'Chưa có Gemini API Key. Hãy mở Trợ lý học vụ (nút "Trợ lý" '
              'trên thanh trên cùng) và nhập key một lần — chat trong từng '
              'môn sẽ dùng chung key đó.',
            ),
        ],
      );
    } else {
      body = ListView.builder(
        reverse: true,
        padding: const EdgeInsets.all(16),
        itemCount: controller.messages.length,
        itemBuilder: (context, index) {
          final message =
              controller.messages[controller.messages.length - 1 - index];
          return AssistantMessageCard(
            isUser: message.role == ChatRole.user,
            text: message.content,
            footer: message.resourceIds.isEmpty
                ? null
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: message.resourceIds.map((id) {
                      final resource = controller.resourceById(id);
                      return Chip(
                        avatar: const Icon(Icons.attach_file, size: 16),
                        label: Text(
                          resource == null
                              ? '${message.resourceFileNames[id] ?? 'Tệp đính kèm'} · không còn'
                              : resource.originalFileName,
                        ),
                      );
                    }).toList(),
                  ),
          );
        },
      );
    }

    return AssistantChatLayout(
      framed: true,
      title: 'Trợ lý môn học',
      subtitle:
          '${controller.workspace.subjectCode} · BYOK · ${UserSettings.modelLabels[UserSettings.geminiModel] ?? UserSettings.geminiModel}',
      actions: [
        AssistantHeaderAction(
          icon: Icons.key_outlined,
          tooltip: 'Cấu hình API Key & model',
          onPressed: controller.sending ? null : _openAiSettings,
        ),
        AssistantHeaderAction(
          icon: Icons.delete_sweep_outlined,
          tooltip: 'Xóa lịch sử chat',
          onPressed:
              controller.sending ||
                  !controller.chatReady ||
                  controller.messages.isEmpty
              ? null
              : _clear,
        ),
        if (widget.onCollapse != null)
          AssistantHeaderAction(
            icon: Icons.close_fullscreen_rounded,
            tooltip: 'Thu nhỏ trợ lý',
            onPressed: widget.onCollapse,
          ),
      ],
      body: body,
      composer: AssistantComposer(
        controller: _text,
        focusNode: _focus,
        label: 'Hỏi về môn ${controller.workspace.subjectCode}...',
        busy: controller.sending,
        maxLength: 16000,
        canSend: (text) => controller.canSend && text.trim().isNotEmpty,
        onSend: _send,
        top: [
          if (controller.keyError != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(controller.keyError!, style: errorStyle),
            ),
            const SizedBox(height: 8),
          ],
          if (controller.chatError != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(controller.chatError!, style: errorStyle),
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
                      ? 'Thử lại câu trả lời'
                      : 'Tải lại cuộc trò chuyện',
                ),
              ),
            ),
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
                          : () =>
                                controller.removeSelectedResource(resource.id),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                '${controller.selectedResources.length} tệp sẽ được gửi kèm tin nhắn này.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
