import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../models/curriculum_data.dart';
import '../../utils/user_settings.dart';
import 'ai_settings_form.dart';
import 'assistant_chat_layout.dart';

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
    // Same as the subject chat: Enter sends, Shift+Enter adds a new line.
    _inputFocus.onKeyEvent = AssistantComposer.enterToSend(
      canSendNow: () =>
          !_isLoading && _textController.text.trim().isNotEmpty,
      onSend: () => _sendMessage(_textController.text),
    );
    _initChat();
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AiSettingsForm(
        onSaved: () => setState(() => _isSettingsMode = false),
        onCancel: () => setState(() => _isSettingsMode = false),
      ),
    );
  }

  Widget _buildMessages() {
    if (_chatService.history.isEmpty && !_isLoading) {
      return AssistantEmptyState(
        title: 'Hỏi Trợ lý học vụ',
        description:
            'Hỏi về khung chương trình, lộ trình các kỳ, môn tiên quyết hay '
            'chuyên ngành hẹp. Khung chương trình và bảng điểm của bạn được '
            'gửi cho Gemini khi bạn hỏi.',
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in const [
                'Kỳ tới nên học gì?',
                'Môn nào khó nhất?',
              ])
                ActionChip(
                  label: Text(q),
                  onPressed: () => _sendMessage(q),
                ),
            ],
          ),
        ],
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _chatService.history.length,
      itemBuilder: (context, index) {
        final msg = _chatService.history[index];
        return AssistantMessageCard(
          isUser: msg.role == 'user',
          text: msg.text,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AssistantChatLayout(
      title: 'Trợ lý học vụ',
      subtitle: 'Dựa trên khung chương trình của bạn',
      actions: [
        AssistantHeaderAction(
          icon: Icons.key_outlined,
          tooltip: 'Cài đặt API Key & Model',
          onPressed: _isLoading
              ? null
              : () => setState(() => _isSettingsMode = !_isSettingsMode),
        ),
        AssistantHeaderAction(
          icon: Icons.delete_sweep_outlined,
          tooltip: 'Xóa lịch sử chat',
          onPressed: _isLoading || _chatService.history.isEmpty
              ? null
              : () {
                  setState(_chatService.clearHistory);
                  _initChat();
                },
        ),
        AssistantHeaderAction(
          icon: widget.isOverlay
              ? Icons.open_in_full_rounded
              : Icons.close_fullscreen_rounded,
          tooltip:
              widget.isOverlay ? 'Mở toàn màn hình' : 'Thu nhỏ dạng thanh trượt',
          onPressed: widget.onToggleMode,
        ),
        AssistantHeaderAction(
          icon: Icons.close_rounded,
          tooltip: 'Đóng',
          onPressed: widget.onClose,
        ),
      ],
      body: _isSettingsMode ? _buildSettingsView() : _buildMessages(),
      composer: AssistantComposer(
        controller: _textController,
        focusNode: _inputFocus,
        label: 'Hỏi về chương trình, môn học...',
        busy: _isLoading,
        canSend: (text) =>
            !_isLoading && !_isSettingsMode && text.trim().isNotEmpty,
        onSend: () => _sendMessage(_textController.text),
      ),
    );
  }
}
