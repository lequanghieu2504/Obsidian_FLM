import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../services/chat_service.dart';
import '../../models/curriculum_data.dart';
import '../../utils/user_settings.dart';

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
  bool _isLoading = false;
  bool _isSettingsMode = false;

  late TextEditingController _apiController;
  late String _selectedModel;

  @override
  void initState() {
    super.initState();
    _apiController = TextEditingController(text: UserSettings.geminiApiKey);
    _selectedModel = UserSettings.validModels.contains(UserSettings.geminiModel)
        ? UserSettings.geminiModel
        : 'gemini-3.8-flash';
    if (UserSettings.geminiApiKey.isEmpty) {
      _isSettingsMode = true;
    }
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

    if (UserSettings.geminiApiKey.isEmpty) {
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
    _apiController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildSettingsView() {
    return Expanded(
      child: Container(
        color: const Color(0xFFF8FAFC),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cấu hình Trợ lý',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark)),
            const SizedBox(height: 8),
            const Text('Vui lòng nhập API Key để sử dụng tính năng Chat.',
                style: TextStyle(fontSize: 14, color: AppColors.textSub)),
            const SizedBox(height: 24),
            const Text('Gemini API Key:',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.textMain)),
            const SizedBox(height: 8),
            TextField(
              controller: _apiController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Nhập API Key của bạn...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Chọn Model:',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.textMain)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedModel,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                        value: 'gemini-3.8-flash',
                        child: Text('Gemini 3.8 Flash')),
                    DropdownMenuItem(
                        value: 'gemini-3.5-flash-lite',
                        child: Text('Gemini 3.5 Flash-Lite')),
                    DropdownMenuItem(
                        value: 'gemini-3.1-pro-preview',
                        child: Text('Gemini Pro (Bản cũ)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedModel = val);
                  },
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  await UserSettings.saveGeminiSettings(
                      _apiController.text, _selectedModel);
                  _initChat();
                  setState(() => _isSettingsMode = false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Lưu & Bắt đầu Chat'),
              ),
            ),
            if (UserSettings.geminiApiKey.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => setState(() => _isSettingsMode = false),
                  child: const Text('Hủy',
                      style: TextStyle(color: AppColors.textSub)),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.isOverlay ? 380 : double.infinity,
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
                  final isUser = msg.role == 'user';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: isUser
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!isUser) ...[
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
                        ],
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? AppColors.primary
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16).copyWith(
                                bottomRight: isUser
                                    ? const Radius.circular(4)
                                    : const Radius.circular(16),
                                bottomLeft: !isUser
                                    ? const Radius.circular(4)
                                    : const Radius.circular(16),
                              ),
                              border: isUser
                                  ? null
                                  : Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              msg.text,
                              style: TextStyle(
                                color:
                                    isUser ? Colors.white : AppColors.textMain,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                        if (isUser) const SizedBox(width: 28),
                      ],
                    ),
                  );
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

            // Input Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Hỏi về môn học...',
                        hintStyle: const TextStyle(color: AppColors.textSub),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              const BorderSide(color: AppColors.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => _sendMessage(_textController.text),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
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
