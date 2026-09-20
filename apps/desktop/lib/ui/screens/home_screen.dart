import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/curriculum.dart';
import '../../services/storage_service.dart';
import '../../utils/notification_helper.dart';
import '../../app/theme/app_colors.dart';
import '../layouts/dashboard_layout.dart';
import 'scraping_screen.dart';
import 'curriculum_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _cohortController = TextEditingController();
  
  @override
  void dispose() {
    _cohortController.dispose();
    super.dispose();
  }

  void _validateCohort() async {
    final input = _cohortController.text.trim().toUpperCase();
    if (input.isEmpty) {
      NotificationHelper.showToast(context, 'Vui lòng nhập niên khóa (VD: K19)', isError: true);
      return;
    }

    final currentYear = DateTime.now().year;
    final maxK = currentYear - 2004; // K1 là năm 2004

    final regex = RegExp(r'^K(\d{1,2})([A-Z])?$');
    final match = regex.firstMatch(input);

    if (match == null) {
      NotificationHelper.showToast(
          context, 'Định dạng không hợp lệ. Vui lòng nhập dạng K19 hoặc K19B.',
          isError: true);
      return;
    }

    final kNumber = int.parse(match.group(1)!);
    final suffix = match.group(2);

    if (kNumber < 1 || kNumber > maxK) {
      NotificationHelper.showToast(
          context, 'Niên khóa không hợp lệ (phải từ K1 đến K$maxK)',
          isError: true);
      return;
    }

    if (suffix == null) {
      NotificationHelper.showToast(
          context, 'Vui lòng bổ sung hậu tố cho ngành (VD: A, B, C...)',
          isError: true);
      return;
    }

    NotificationHelper.showToast(
      context,
      'Niên khóa hợp lệ: $input... Đang chuẩn bị dữ liệu.',
    );

    final resultStr = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ScrapingScreen(cohort: input)),
    );

    if (!mounted) return;

    if (resultStr != null && resultStr is String) {
      try {
        final List<dynamic> jsonList = jsonDecode(resultStr);
        final List<Curriculum> curricula =
            jsonList.map((e) => Curriculum.fromJson(e)).toList();

        final storage = StorageService();
        await storage.saveCurriculumList(input, curricula);

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => CurriculumListScreen(
              curricula: curricula,
              cohort: input,
            ),
          ),
        );
      } catch (e) {
        debugPrint('Parse JSON error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Nửa trái: Illustration giống s-login
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  )
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.school_rounded, size: 80, color: Colors.white),
                    const SizedBox(height: 32),
                    const Text(
                      'Biết mình đang ở đâu trong chương trình học',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Xem toàn bộ môn học của ngành, môn nào phải học trước, và hỏi trợ lý khi cần chọn môn cho kỳ tới.',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Nửa phải: Form nhập khóa giống s-cohort
          Expanded(
            flex: 4,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 40,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.looks_one_rounded, color: AppColors.primaryLight, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Thiết lập lần đầu, bước 1 trên 2',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryLight.withValues(alpha: 0.8),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Bạn học khóa nào?',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textMain,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Khóa quyết định khung chương trình áp dụng cho bạn, nên các môn và tiên quyết sẽ khớp với khóa của bạn.',
                      style: TextStyle(fontSize: 15, color: AppColors.textSub, height: 1.5),
                    ),
                    const SizedBox(height: 40),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _cohortController,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                        decoration: const InputDecoration(
                          hintText: 'Nhập khóa (VD: K19B)',
                          hintStyle: TextStyle(color: AppColors.textSub, fontWeight: FontWeight.normal, fontSize: 16),
                          prefixIcon: Icon(Icons.school_rounded, color: AppColors.primary),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        ),
                        onSubmitted: (_) => _validateCohort(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Gợi ý: Chỉ nhập đúng định dạng hệ thống quy định (VD: K19B, K18A).',
                      style: TextStyle(fontSize: 13, color: AppColors.textSub),
                    ),
                    const SizedBox(height: 32),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _validateCohort,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Tiếp tục', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
