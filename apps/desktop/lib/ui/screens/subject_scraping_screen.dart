import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

class SubjectScrapingScreen extends StatefulWidget {
  final String detailUrl;
  final String curriculumCode;

  const SubjectScrapingScreen({
    super.key,
    required this.detailUrl,
    required this.curriculumCode,
  });

  @override
  State<SubjectScrapingScreen> createState() => _SubjectScrapingScreenState();
}

class _SubjectScrapingScreenState extends State<SubjectScrapingScreen> {
  final _controller = WebviewController();
  bool _isInitializing = true;
  bool _isExtracting = false;
  bool _showCaptcha = false;
  String _statusMessage = 'Đang kết nối đến hệ thống...';
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _initWebview();
  }

  Future<void> _initWebview() async {
    try {
      await _controller.initialize();
      setState(() => _isInitializing = false);

      final fullUrl = widget.detailUrl.startsWith('http') 
          ? widget.detailUrl 
          : 'https://flm.fpt.edu.vn${widget.detailUrl.startsWith('/') ? '' : '/'}${widget.detailUrl}';
      
      setState(() => _statusMessage = 'Đang tải dữ liệu Môn học...');
      await _controller.loadUrl(fullUrl);
      
      _startAutoScraping();
    } catch (e) {
      debugPrint('WebView Init Error: $e');
    }
  }

  void _startAutoScraping() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isExtracting || !mounted) return;
      
      try {
        final result = await _controller.executeScript('''
          (() => { return document.documentElement.outerHTML; })();
        ''');

        if (result != null) {
          final html = result.toString();
          
          // Kiểm tra xem đã load tới trang chi tiết chưa
          if (html.contains('CurriculumCode') || html.contains('tbSubjectGroup') || html.contains(widget.curriculumCode)) {
            timer.cancel();
            _extractHtml(html);
          } 
          // Kiểm tra xem có bị dính CAPTCHA không
          else if (html.contains('cf-browser-verification') || html.contains('g-recaptcha') || html.contains('Just a moment')) {
            if (!_showCaptcha) {
              setState(() {
                _showCaptcha = true;
                _statusMessage = 'Hệ thống yêu cầu xác thực CAPTCHA!';
              });
            }
          }
        }
      } catch (e) {
        // Bỏ qua lỗi khi DOM chưa sẵn sàng
      }
    });
  }

  void _extractHtml(String htmlContent) async {
    if (_isExtracting) return;
    setState(() {
      _isExtracting = true;
      _showCaptcha = false; // Ẩn trình duyệt đi
      _statusMessage = 'Đã quét thấy dữ liệu! Đang lưu trữ...';
    });

    try {
      final file = File('curriculum_detail_${widget.curriculumCode}.html');
      await file.writeAsString(htmlContent);
      setState(() => _statusMessage = 'Hoàn tất cào dữ liệu!');
      
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.of(context).pop('SUCCESS');
      }
    } catch (e) {
      debugPrint('Extract error: $e');
      setState(() => _isExtracting = false);
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FD),
      body: Stack(
        children: [
          // 1. Trình duyệt Webview (Chỉ hiển thị khi có CAPTCHA)
          if (!_isInitializing)
            Positioned.fill(
              child: Opacity(
                opacity: _showCaptcha ? 1.0 : 0.0,
                child: Webview(_controller),
              ),
            ),
          
          // 2. Màn hình chờ (Loading Overlay) siêu đẹp
          if (!_showCaptcha)
            Positioned.fill(
              child: Container(
                color: const Color(0xFFF0F4FD),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(48),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 40, offset: const Offset(0, 10))
                      ]
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            const SizedBox(
                              width: 80,
                              height: 80,
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            Icon(Icons.auto_awesome_rounded, size: 32, color: const Color(0xFF10B981).withOpacity(0.8)),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Obsidian FLM',
                          style: TextStyle(
                            fontFamily: 'Segoe UI',
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                            fontFamily: 'Segoe UI',
                            fontSize: 15,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
          // 3. Thông báo CAPTCHA nếu bị chặn
          if (_showCaptcha)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.redAccent,
                child: SafeArea(
                  child: Text(
                    '⚠️ Xin lỗi, hệ thống FLM đang yêu cầu xác thực. Vui lòng giải CAPTCHA bên dưới để tiếp tục tự động hóa!',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Segoe UI', fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
