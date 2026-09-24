import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../utils/user_settings.dart';

/// The single Gemini configuration UI (API key + model).
///
/// Used by "Trợ lý học vụ" (inline in [ChatBox]) and by the subject assistant
/// (via [showAiSettingsDialog]); both write to [UserSettings], so the key is
/// entered once and shared by every chat in the app.
class AiSettingsForm extends StatefulWidget {
  const AiSettingsForm({super.key, this.onSaved, this.onCancel});

  final VoidCallback? onSaved;

  /// Shown as a "Hủy" button when not null.
  final VoidCallback? onCancel;

  @override
  State<AiSettingsForm> createState() => _AiSettingsFormState();
}

class _AiSettingsFormState extends State<AiSettingsForm> {
  final _apiController = TextEditingController();
  late String _selectedModel;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedModel = UserSettings.validModels.contains(UserSettings.geminiModel)
        ? UserSettings.geminiModel
        : UserSettings.defaultModel;
  }

  @override
  void dispose() {
    _apiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!UserSettings.hasApiKey && _apiController.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập API Key.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await UserSettings.saveGeminiSettings(_apiController.text, _selectedModel);
      _apiController.clear();
      widget.onSaved?.call();
    } catch (_) {
      setState(() => _error =
          'Không lưu được API Key vào kho bảo mật của hệ điều hành. Thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeKey() async {
    setState(() => _busy = true);
    try {
      await UserSettings.clearApiKey();
    } catch (_) {
      _error = 'Không xoá được API Key. Thử lại.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
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
      );

  @override
  Widget build(BuildContext context) {
    final hasKey = UserSettings.hasApiKey;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cấu hình Trợ lý AI',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark)),
        const SizedBox(height: 8),
        Text(
          hasKey
              ? 'Đã có API Key (lưu trong kho bảo mật của máy, dùng chung cho Trợ lý học vụ và chat trong từng môn). Chỉ nhập lại khi muốn đổi key.'
              : 'Nhập Gemini API Key một lần, dùng chung cho Trợ lý học vụ và chat trong từng môn học. Key được lưu trong kho bảo mật của máy, không nằm trong thư mục project.',
          style: const TextStyle(fontSize: 13, color: AppColors.textSub),
        ),
        const SizedBox(height: 20),
        const Text('Gemini API Key:',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.textMain)),
        const SizedBox(height: 8),
        TextField(
          controller: _apiController,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          readOnly: _busy,
          decoration: _decoration(hasKey
              ? '•••••••• (để trống nếu giữ key hiện tại)'
              : 'Nhập API Key của bạn...'),
        ),
        const SizedBox(height: 16),
        const Text('Model (dùng chung cho mọi khung chat):',
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
              items: [
                for (final m in UserSettings.validModels)
                  DropdownMenuItem(
                      value: m, child: Text(UserSettings.modelLabels[m] ?? m)),
              ],
              onChanged: _busy
                  ? null
                  : (val) {
                      if (val != null) setState(() => _selectedModel = val);
                    },
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _busy ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_busy ? 'Đang lưu…' : 'Lưu'),
          ),
        ),
        Row(
          children: [
            if (hasKey)
              TextButton(
                onPressed: _busy ? null : _removeKey,
                child: const Text('Xoá API Key'),
              ),
            const Spacer(),
            if (widget.onCancel != null && hasKey)
              TextButton(
                onPressed: _busy ? null : widget.onCancel,
                child: const Text('Hủy',
                    style: TextStyle(color: AppColors.textSub)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Opens [AiSettingsForm] as a dialog (used outside "Trợ lý học vụ").
Future<void> showAiSettingsDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AiSettingsForm(
              onSaved: () => Navigator.of(context).pop(),
              onCancel: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
