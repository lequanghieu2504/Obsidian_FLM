import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/curriculum_data.dart';
import '../utils/user_settings.dart';

class ChatMessage {
  final String role; // 'user' or 'model'
  final String text;

  ChatMessage({required this.role, required this.text});

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] as String,
        text: json['text'] as String,
      );
}

class ChatService {
  List<ChatMessage> _history = [];
  GenerativeModel? _model;
  ChatSession? _chatSession;

  List<ChatMessage> get history => _history;

  Future<File> _getHistoryFile() async {
    final currentDir = Directory.current;
    final dataDir = Directory(p.join(currentDir.path, 'data'));
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    return File(p.join(dataDir.path, 'chat_history.json'));
  }

  Future<void> loadHistory() async {
    try {
      final file = await _getHistoryFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _history = jsonList.map((j) => ChatMessage.fromJson(j)).toList();
      }
    } catch (e) {
      _history = [];
    }
  }

  Future<void> saveHistory() async {
    try {
      final file = await _getHistoryFile();
      final jsonList = _history.map((m) => m.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      // Ignore
    }
  }

  void clearHistory() {
    _history.clear();
    _chatSession = null;
    saveHistory();
  }

  String _compressCurriculumData(CurriculumData data) {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('### THÔNG TIN KHUNG CHƯƠNG TRÌNH ###');
    buffer.writeln('Khóa/Ngành: ${data.metadata['curriculumCode'] ?? 'Unknown'}');
    buffer.writeln('Tổng số môn: ${data.subjects.length}');
    buffer.writeln('Danh sách môn học:');
    
    // Nén dữ liệu: Chỉ lấy Code, Name, Credits, Prerequisite, Semester
    for (var sub in data.subjects) {
      buffer.write('- Kỳ ${sub.semester}: [${sub.code}] ${sub.name} (${sub.credits} tín chỉ). ');
      if (sub.preRequisite != null && sub.preRequisite!.isNotEmpty) {
        buffer.write('Tiên quyết: ${sub.preRequisite}. ');
      }
      buffer.writeln();
    }

    if (data.allCombos.isNotEmpty) {
      buffer.writeln('\n### DANH SÁCH CHUYÊN NGÀNH HẸP (COMBOS) ###');
      buffer.writeln('Sinh viên có thể chọn 1 trong các chuyên ngành hẹp (Combo) dưới đây để thay thế cho các môn tự chọn (Elective) tương ứng:');
      for (var combo in data.allCombos) {
        buffer.write('- [${combo.code}] ${combo.name}');
        if (combo.subjects != null && combo.subjects!.isNotEmpty) {
          final subjectCodes = combo.subjects!.map((s) => s.code).join(', ');
          buffer.write(': Gồm các môn học $subjectCodes');
        }
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  Future<void> initializeModel(CurriculumData curriculumData) async {
    if (UserSettings.geminiApiKey.isEmpty) {
      _model = null;
      _chatSession = null;
      return;
    }

    String transcriptContext = '';
    try {
      final currentDir = Directory.current;
      final file = File(p.join(currentDir.path, 'data', 'transcript.json'));
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        if (jsonList.isNotEmpty) {
           transcriptContext = '\n\n### BẢNG ĐIỂM CÁ NHÂN CỦA SINH VIÊN ###\n';
           transcriptContext += 'Sinh viên đã cung cấp bảng điểm hiện tại. Dưới đây là các môn đã/đang học:\n';
           for(var item in jsonList) {
              final code = item['subjectCode'];
              final name = item['subjectName'];
              final status = item['status'];
              final grade = item['grade'];
              transcriptContext += '- [$code] $name: Trạng thái "$status", Điểm "${grade.isNotEmpty ? grade : "Chưa có"}"\n';
           }
        }
      }
    } catch (e) {
      // Ignore
    }

    final String compressedData = _compressCurriculumData(curriculumData);
    final String systemInstruction = '''
Bạn là "Trợ lý học vụ", một tư vấn viên thân thiện và chuyên nghiệp. 
Hãy dựa VÀO KHUNG CHƯƠNG TRÌNH ĐƯỢC CUNG CẤP BÊN DƯỚI để tư vấn cho sinh viên.$transcriptContext
Nếu câu hỏi nằm ngoài phạm vi khung chương trình, hãy nói rõ là bạn chỉ tư vấn dựa trên dữ liệu hiện có.
Trả lời ngắn gọn, thân thiện và chính xác. Trình bày rõ ràng bằng Markdown.

$compressedData
''';

    _model = GenerativeModel(
      model: UserSettings.geminiModel,
      apiKey: UserSettings.geminiApiKey,
      systemInstruction: Content.system(systemInstruction),
    );

    // Reconstruct chat history for Gemini
    List<Content> apiHistory = _history.map((msg) {
      return msg.role == 'user' ? Content.text(msg.text) : Content.model([TextPart(msg.text)]);
    }).toList();

    _chatSession = _model!.startChat(history: apiHistory);
  }

  Future<String> sendMessage(String userText) async {
    final trimmedText = userText.trim();
    _history.add(ChatMessage(role: 'user', text: trimmedText));
    saveHistory();

    if (_chatSession == null) {
      final errorMsg = 'Lỗi: Vui lòng vào Cài đặt (Bấm biểu tượng ⚙️) để nhập Gemini API Key hợp lệ. Sau đó hãy khởi động lại ứng dụng hoặc tắt mở lại khung chat để hệ thống nhận diện API key mới.';
      _history.add(ChatMessage(role: 'model', text: errorMsg));
      saveHistory();
      return errorMsg;
    }

    int maxRetries = 2;
    for (int i = 0; i <= maxRetries; i++) {
      try {
        final response = await _chatSession!.sendMessage(Content.text(trimmedText));
        final botText = response.text ?? 'Xin lỗi, tôi không thể xử lý yêu cầu này.';
        _history.add(ChatMessage(role: 'model', text: botText.trim()));
        saveHistory();
        return botText.trim();
      } catch (e) {
        final errorString = e.toString();
        
        // Nếu là lỗi 503 (quá tải) và chưa hết số lần thử, chờ 2s rồi thử lại
        if (errorString.contains('503') && i < maxRetries) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        // Nếu hết lần thử hoặc là lỗi khác, hiển thị thông báo thân thiện
        String errorMsg;
        if (errorString.contains('503')) {
          errorMsg = 'Hệ thống AI hiện đang quá tải do có nhiều người truy cập (Lỗi 503). Vui lòng thử lại sau ít phút nhé!';
        } else if (errorString.contains('API key not valid') || errorString.contains('API_KEY_INVALID')) {
          errorMsg = 'API Key của bạn không hợp lệ hoặc đã hết hạn. Vui lòng kiểm tra lại trong phần Cài đặt.';
        } else {
          // Trích xuất dòng đầu tiên của lỗi để tránh xuất nguyên khối JSON dài dòng
          final shortError = errorString.split('\\n').first.replaceAll(RegExp(r'[{}]'), '').trim();
          errorMsg = 'Rất tiếc, đã có lỗi xảy ra khi gọi AI. Vui lòng thử lại.\\n(Chi tiết: $shortError)';
        }

        _history.add(ChatMessage(role: 'model', text: errorMsg));
        saveHistory();
        return errorMsg;
      }
    }
    
    return 'Lỗi không xác định.';
  }
}
