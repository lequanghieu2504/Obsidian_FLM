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
          padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primaryContainer.withValues(alpha: .72),
                theme.colorScheme.surface,
              ],
            ),
            border: Border(bottom: divider),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: .24),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 21,
                  color: theme.colorScheme.onPrimary,
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
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            border: Border(top: divider),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 28,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          if (children.isNotEmpty) ...[const SizedBox(height: 16), ...children],
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
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          margin: EdgeInsets.only(
            bottom: 14,
            left: isUser ? 40 : 0,
            right: isUser ? 0 : 40,
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 14),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 5),
              bottomRight: Radius.circular(isUser ? 5 : 18),
            ),
            border: Border.all(
              color: isUser
                  ? theme.colorScheme.primary.withValues(alpha: .12)
                  : theme.colorScheme.outlineVariant.withValues(alpha: .7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isUser
                          ? theme.colorScheme.primary.withValues(alpha: .12)
                          : theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isUser
                          ? Icons.person_rounded
                          : Icons.auto_awesome_rounded,
                      size: 13,
                      color: onBubbleColor,
                    ),
                  ),
                  const SizedBox(width: 8),
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
                      iconSize: 15,
                      color: onBubbleColor.withValues(alpha: .72),
                      onPressed: () => _copy(context),
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              SimpleMarkdown(
                data: text,
                baseStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: onBubbleColor,
                  height: 1.5,
                ),
              ),
              if (footer != null) ...[const SizedBox(height: 10), footer!],
            ],
          ),
        ),
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
      final isEnter =
          event.logicalKey == LogicalKeyboardKey.enter ||
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
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...top,
            if (busy) ...[
              const LinearProgressIndicator(semanticsLabel: 'Đang chờ Gemini'),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: const Text('Đang chờ Gemini…'),
              ),
              const SizedBox(height: 8),
            ],
            if (secondaryActions.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: secondaryActions,
              ),
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    readOnly: busy,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: maxLength,
                    decoration: InputDecoration(
                      hintText: label,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (context, value, _) => Tooltip(
                    message: 'Gửi tin nhắn',
                    child: SizedBox.square(
                      dimension: 46,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: canSend(value.text) ? onSend : null,
                        child: const Icon(
                          Icons.send_rounded,
                          size: 20,
                          semanticLabel: 'Gửi',
                        ),
                      ),
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
