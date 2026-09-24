import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/assistant/presentation/simple_markdown.dart';

/// Shared layout for every AI chat in the app — "Trợ lý học vụ"
/// ([ChatBox]) and the per-subject assistant ([SubjectChatPanel]) — so both
/// look and behave the same:
///
///   header (avatar · title/subtitle · icon actions)
///   ─────────────
///   body (messages or [AssistantEmptyState])
///   ─────────────
///   composer ([AssistantComposer])
class AssistantChatLayout extends StatelessWidget {
  const AssistantChatLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.body,
    required this.composer,
    this.framed = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget body;
  final Widget composer;

  /// Rounded border around the whole panel (when it sits among other cards,
  /// e.g. the subject detail page). The side drawer uses no frame.
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = BorderSide(color: theme.colorScheme.outlineVariant);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          decoration: BoxDecoration(border: Border(bottom: divider)),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.smart_toy_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
        Expanded(child: body),
        Container(
          decoration: BoxDecoration(border: Border(top: divider)),
          child: composer,
        ),
      ],
    );
    return Material(
      color: theme.colorScheme.surface,
      shape: framed
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: divider,
            )
          : null,
      clipBehavior: framed ? Clip.antiAlias : Clip.none,
      child: content,
    );
  }
}

/// Small icon button used in the chat header.
class AssistantHeaderAction extends StatelessWidget {
  const AssistantHeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
      );
}

/// Shown in the body before the first message.
class AssistantEmptyState extends StatelessWidget {
  const AssistantEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.children = const [],
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 36, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...children,
          ],
        ],
      ),
    );
  }
}

/// One chat message: sender label, copy button, selectable Markdown body.
class AssistantMessageCard extends StatelessWidget {
  const AssistantMessageCard({
    super.key,
    required this.isUser,
    required this.text,
    this.footer,
  });

  final bool isUser;
  final String text;

  /// Extra content under the message (e.g. attachment chips).
  final Widget? footer;

  Future<void> _copy(BuildContext context) async {
    // Raw Markdown source, so pasting elsewhere keeps **bold**, - lists...
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Đã copy vào clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                isUser ? Icons.person_outline : Icons.auto_awesome_outlined,
                size: 16,
                color: onBubbleColor,
              ),
              const SizedBox(width: 6),
              Text(
                isUser ? 'Bạn' : 'Gemini',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: onBubbleColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Copy tin nhắn',
                  iconSize: 16,
                  color: onBubbleColor,
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.copy_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SimpleMarkdown(
            data: text,
            baseStyle: theme.textTheme.bodyLarge?.copyWith(
              color: onBubbleColor,
              height: 1.5,
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 10),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// Input area: optional status widgets on top, a multi-line field
/// (Enter sends, Shift+Enter new line — wire [enterToSend] onto the
/// [focusNode]), then optional secondary actions + the send button.
class AssistantComposer extends StatelessWidget {
  const AssistantComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.busy,
    required this.canSend,
    required this.onSend,
    this.top = const [],
    this.secondaryActions = const [],
    this.maxLength,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final bool busy;

  /// Whether the send button is enabled for the current text.
  final bool Function(String text) canSend;
  final VoidCallback onSend;
  final List<Widget> top;
  final List<Widget> secondaryActions;
  final int? maxLength;

  /// Key handler for [focusNode]: Enter sends (when allowed), Shift+Enter
  /// falls through so the field inserts a newline.
  static FocusOnKeyEventCallback enterToSend({
    required bool Function() canSendNow,
    required VoidCallback onSend,
  }) {
    return (node, event) {
      final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter;
      if (event is! KeyDownEvent ||
          !isEnter ||
          HardwareKeyboard.instance.isShiftPressed) {
        return KeyEventResult.ignored;
      }
      if (canSendNow()) onSend();
      return KeyEventResult.handled;
    };
  }

  @override
  Widget build(BuildContext context) {
    // Status + field scroll within a height cap on short windows.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .35,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...top,
            if (busy) ...[
              const LinearProgressIndicator(
                semanticsLabel: 'Đang chờ Gemini',
              ),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: const Text('Đang chờ Gemini…'),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: busy,
              minLines: 1,
              maxLines: 4,
              maxLength: maxLength,
              decoration: InputDecoration(
                labelText: label,
                helperText: 'Enter để gửi · Shift+Enter để xuống dòng',
                border: const OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                ...secondaryActions,
                SizedBox(
                  width: 120,
                  child: ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, value, _) => FilledButton.icon(
                      onPressed: canSend(value.text) ? onSend : null,
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Gửi'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
