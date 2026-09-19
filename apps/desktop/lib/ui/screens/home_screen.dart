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
    final maxK = currentYear - 2004;

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
            builder: (context) => DashboardLayout(
              userName: 'Minh Anh',
              child: CurriculumListScreen(
                curricula: curricula,
                cohort: input,
              ),
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
      backgroundColor: AppColors.sidebarBackground,
      body: Row(
        children: [
          // Left Side: Banner / Illustration
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
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  )
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.all(48.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school_rounded, size: 80, color: Colors.white),
                    SizedBox(height: 32),
                    Text(
                      'Obsidian\nFLM',
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -2,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Your smart companion for managing FPT University curricula. Scrape, analyze, and build your learning path automatically.',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right Side: Cohort Input
          Expanded(
            flex: 4,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.05),
                      blurRadius: 40,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thiết lập lần đầu',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Bạn học khóa nào?',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Nhập niên khóa để hệ thống đồng bộ đúng khung chương trình (VD: K19B).',
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        decoration: const InputDecoration(
                          hintText: 'K...',
                          hintStyle: TextStyle(color: AppColors.textSub, fontWeight: FontWeight.normal),
                          prefixIcon: Icon(Icons.school_rounded, color: AppColors.primary),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        ),
                        onSubmitted: (_) => _validateCohort(),
                      ),
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
