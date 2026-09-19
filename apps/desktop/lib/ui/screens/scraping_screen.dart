import 'dart:io';
import '../../app/theme/app_colors.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

class ScrapingScreen extends StatefulWidget {
  final String cohort;
  const ScrapingScreen({super.key, required this.cohort});

  @override
  State<ScrapingScreen> createState() => _ScrapingScreenState();
}

class _ScrapingScreenState extends State<ScrapingScreen> {
  final _controller = WebviewController();
  bool _isWebviewInitialized = false;
  String _status = 'Đang tải dữ liệu từ FLM... Vui lòng chờ trong giây lát.';

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  bool _hasSearched = false;

  Future<void> initPlatformState() async {
    try {
      await _controller.initialize();

      // Khởi tạo trang web
      await _controller.loadUrl(
          'https://flm.fpt.edu.vn/gui/role/guest/ListCurriculum?educationLevel=fptu');

      if (!mounted) return;
      setState(() {
        _isWebviewInitialized = true;
      });

      // Bắt đầu vòng lặp kiểm tra để tự động điền form và bấm Search
      Timer.periodic(const Duration(seconds: 2), (timer) async {
        if (!mounted || !_isWebviewInitialized) {
          timer.cancel();
          return;
        }

        try {
          final isCaptcha = await _controller
              .executeScript("document.getElementById('captchaForm') !== null");

          if (isCaptcha == true) {
            _hasSearched = false; // Reset nếu bị quăng lại captcha
            if (mounted)
              setState(
                  () => _status = 'Vui lòng tích vào CAPTCHA để tiếp tục...');
            return;
          }

          // Kiểm tra xem đã có bảng kết quả chưa (có nhiều hơn 1 thẻ table do thẻ đầu tiên là thẻ search của flm)
          final hasResults = await _controller
              .executeScript("document.querySelectorAll('table').length > 1");

          if (hasResults == true) {
            timer.cancel();
            if (mounted) setState(() => _status = 'Đang xử lý dữ liệu...');

            // Chạy JS để bóc tách bảng thành JSON
            final jsonStr = await _controller.executeScript('''
              (function() {
                var results = [];
                var rows = document.querySelectorAll('#gvCurriculum tbody tr');
                for (var i = 0; i < rows.length; i++) {
                   var cols = rows[i].querySelectorAll('td');
                   if (cols.length >= 6) {
                       var aTag = cols[2].querySelector('a');
                       results.push({
                           code: cols[1].innerText.trim(),
                           name: aTag ? aTag.innerText.trim() : cols[2].innerText.trim(),
                           detailUrl: aTag ? 'https://flm.fpt.edu.vn' + aTag.getAttribute('href') : '',
                           description: cols[3].innerText.trim(),
                           decisionNo: cols[4].innerText.trim(),
                           totalCredit: cols[5].innerText.trim()
                       });
                   }
                }
                return JSON.stringify(results);
              })();
            ''');

            if (jsonStr != null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Xử lý dữ liệu Ngành học thành công!')),
              );
              Navigator.of(context).pop(jsonStr);
            } else if (mounted) {
              Navigator.of(context).pop();
            }
            return;
          }

          // Nếu chưa có kết quả và chưa bấm Search -> Tự động điền form và Search
          if (!_hasSearched) {
            if (mounted)
              setState(() =>
                  _status = 'Đang tự động tìm từ khóa ${widget.cohort}...');
            _hasSearched = true; // Đánh dấu đã bấm để không bấm lại liên tục

            await _controller.executeScript('''
               var input = document.getElementById('txtCurCode');
               if (input) {
                   input.value = '${widget.cohort}';
                   var btn = document.querySelector('button[type="submit"]');
                   if (btn) btn.click();
               }
            ''');
          } else {
            if (mounted)
              setState(() => _status = 'Đang chờ máy chủ FLM phản hồi...');
          }
        } catch (e) {
          debugPrint('Execute script error: $e');
        }
      });
    } catch (e) {
      debugPrint('WebView Exception: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showWebview = _status.contains('CAPTCHA');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đồng bộ dữ liệu'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!showWebview) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
            ],
            Text(_status, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Expanded(
              child: showWebview && _isWebviewInitialized
                  ? Webview(_controller)
                  : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}
