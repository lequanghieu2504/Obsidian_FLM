import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/assistant/presentation/simple_markdown.dart';
import '../../app/theme/app_colors.dart';
import '../../services/chat_service.dart';
import '../../models/curriculum_data.dart';
import '../../utils/user_settings.dart';
import 'ai_settings_form.dart';

class ChatBox extends StatefulWidget {
  final CurriculumData curriculumData;
  final bool isOverlay;
  final VoidCallback onToggleMode;
  final VoidCallback onClose;

  const ChatBox({
    super.key,
    required this.curriculumData,
    required this.isOverlay,
    required this.onToggleMode,
    required this.onClose,
  });

  @override
  State<ChatBox> createState() => _ChatBoxState();
}

class _ChatBoxState extends State<ChatBox> {
  final ChatService _chatService = ChatService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  bool _isLoading = false;
  bool _isSettingsMode = false;

  @override
  void initState() {
    super.initState();
    if (!UserSettings.hasApiKey) {
      _isSettingsMode = true;
    }
    // Key/model are shared app-wide: re-create the Gemini session whenever
    // they change (here or from a subject's chat).
    UserSettings.aiSettingsRevision.addListener(_onAiSettingsChanged);
    _inputFocus.onKeyEvent = _handleComposerKeyEvent;
    _initChat();
  }

  /// Same as the subject chat: Enter sends, Shift+Enter adds a new line.
  KeyEventResult _handleComposerKeyEvent(FocusNode node, KeyEvent event) {
    final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (event is! KeyDownEvent ||
        !isEnter ||
        HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    if (!_isLoading) _sendMessage(_textController.text);
    return KeyEventResult.handled;
  }

  Future<void> _copyMessage(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Đã copy vào clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  void _onAiSettingsChanged() {
    if (!mounted) return;
    _initChat();
  }

  Future<void> _initChat() async {
    await _chatService.loadHistory();
    await _chatService.initializeModel(widget.curriculumData);
    if (mounted) setState(() {});
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    if (!UserSettings.hasApiKey) {
      setState(() => _isSettingsMode = true);
      return;
    }

    _textController.clear();
    setState(() => _isLoading = true);
    _scrollToBottom();

    await _chatService.sendMessage(text);

    if (mounted) {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    UserSettings.aiSettingsRevision.removeListener(_onAiSettingsChanged);
    _textController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Widget _buildSettingsView() {
    return Expanded(
      child: Container(
        color: const Color(0xFFF8FAFC),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AiSettingsForm(
            onSaved: () => setState(() => _isSettingsMode = false),
            onCancel: () => setState(() => _isSettingsMode = false),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: widget.isOverlay
            ? const Border(left: BorderSide(color: Color(0xFFE2E8F0)))
            : null,
        boxShadow: widget.isOverlay
            ? [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(-5, 0))
              ]
            : null,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.smart_toy_rounded,
                      color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trợ lý học vụ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textMain)),
                      Text('Dựa trên khung chương trình của bạn',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSub)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.textSub),
                  onSelected: (value) {
                    if (value == 'toggle') {
                      widget.onToggleMode();
                    } else if (value == 'clear') {
                      setState(() {
                        _chatService.clearHistory();
                      });
                      _initChat();
                    } else if (value == 'close') {
                      widget.onClose();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'settings',
                      child: Text('Cài đặt API Key & Model'),
                      onTap: () => setState(() => _isSettingsMode = true),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(widget.isOverlay
                          ? 'Mở toàn màn hình'
                          : 'Thu nhỏ dạng thanh trượt'),
                    ),
                    const PopupMenuItem(
                      value: 'clear',
                      child: Text('Xóa lịch sử chat'),
                    ),
                    if (widget.isOverlay)
                      const PopupMenuItem(
                        value: 'close',
                        child: Text('Đóng'),
                      ),
                  ],
                )
              ],
            ),
          ),

          if (_isSettingsMode)
            _buildSettingsView()
          else ...[
            // Message List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _chatService.history.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _chatService.history.length) {
                    return _buildTypingIndicator();
                  }

                  final msg = _chatService.history[index];
                  return _buildMessage(msg);
                },
              ),
            ),

            // Suggestion Chips
            if (_chatService.history.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildSuggestionChip('Kỳ tới nên học gì?'),
                    const SizedBox(width: 8),
                    _buildSuggestionChip('Môn nào khó nhất?'),
                  ],
                ),
              ),

            // Composer (same layout as the subject chat)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isLoading) ...[
                    const LinearProgressIndicator(
                      semanticsLabel: 'Đang chờ Gemini',
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _textController,
                    focusNode: _inputFocus,
                    readOnly: _isLoading,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Hỏi về chương trình, môn học...',
                      helperText: 'Enter để gửi · Shift+Enter để xuống dòng',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 140,
                      child: ValueListenableBuilder(
                        valueListenable: _textController,
                        builder: (context, value, _) => FilledButton.icon(
                          onPressed: !_isLoading && value.text.trim().isNotEmpty
                              ? () => _sendMessage(_textController.text)
                              : null,
                          icon: const Icon(Icons.send_outlined),
                          label: const Text('Gửi'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One message card — same format as the subject chat
  /// ([SubjectChatPanel]): sender label, copy button, Markdown body that can
  /// be selected and copied.
  Widget _buildMessage(ChatMessage msg) {
    final theme = Theme.of(context);
    final isUser = msg.role == 'user';
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
                  onPressed: () => _copyMessage(msg.text),
                  icon: const Icon(Icons.copy_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SimpleMarkdown(
            data: msg.text,
            baseStyle: theme.textTheme.bodyLarge?.copyWith(
              color: onBubbleColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return InkWell(
      onTap: () => _sendMessage(text),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: const TextStyle(color: AppColors.textSub, fontSize: 13)),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              color: AppColors.primaryBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded,
                size: 14, color: AppColors.primary),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16)
                  .copyWith(bottomLeft: const Radius.circular(4)),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
                SizedBox(width: 8),
                Text('Đang nghĩ...',
                    style: TextStyle(color: AppColors.textSub)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
