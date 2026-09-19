import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import '../../models/curriculum.dart';
import '../../services/storage_service.dart';
import '../../utils/custom_toast.dart';
import '../theme/app_colors.dart';
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
      CustomToast.show(context, 'Vui lòng nhập niên khóa (VD: K19)',
          isError: true);
      return;
    }

    final currentYear = DateTime.now().year;
    final maxK = currentYear - 2004; // K1 là năm 2004

    final regex = RegExp(r'^K(\d{1,2})([A-Z])?$');
    final match = regex.firstMatch(input);

    if (match == null) {
      CustomToast.show(
          context, 'Định dạng không hợp lệ. Vui lòng nhập dạng K19 hoặc K19B.',
          isError: true);
      return;
    }

    final kNumber = int.parse(match.group(1)!);
    final suffix = match.group(2);

    if (kNumber < 1 || kNumber > maxK) {
      CustomToast.show(
          context, 'Niên khóa không hợp lệ (phải từ K1 đến K$maxK)',
          isError: true);
      return;
    }

    if (suffix == null) {
      CustomToast.show(
          context, 'Vui lòng bổ sung hậu tố cho ngành (VD: A, B, C...)',
          isError: true);
      return;
    }

    CustomToast.show(
      context,
      'Niên khóa hợp lệ: $input...Đang chuẩn bị danh sách ngành học. Vui lòng chờ trong giây lát.',
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
              userName: 'Guest',
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
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.getGradient(0),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color:
                        AppColors.getGradient(0).colors.first.withOpacity(0.3),
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
                    Icon(Icons.auto_awesome_mosaic_rounded,
                        size: 80, color: Colors.white),
                    SizedBox(height: 32),
                    Text(
                      'Obsidian\nFLM',
                      style: TextStyle(
                        fontFamily: 'Segoe UI',
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
                        fontFamily: 'Segoe UI',
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

          // Right side: Cohort input and continue button
          Expanded(
            flex: 3,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 40,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: _buildCohortState(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCohortState() {
    return Column(
      key: const ValueKey('cohort'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Welcome to Obsidian FLM!',
          style: TextStyle(
            fontFamily: 'Segoe UI',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textMain,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please enter your cohort to fetch data.',
          style: TextStyle(fontSize: 15, color: AppColors.textSub),
        ),
        const SizedBox(height: 32),
        Container(
          decoration: BoxDecoration(
            color: AppColors.sidebarBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: TextField(
            controller: _cohortController,
            decoration: const InputDecoration(
              hintText: 'e.g. K19B',
              prefixIcon: Icon(Icons.school_rounded, color: AppColors.textSub),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            onSubmitted: (_) => _validateCohort(),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _validateCohort,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.getGradient(0).colors.first,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text('Continue to Dashboard',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
