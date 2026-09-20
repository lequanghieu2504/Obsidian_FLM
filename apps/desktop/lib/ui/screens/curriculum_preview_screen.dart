import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/curriculum.dart';
import '../../app/theme/app_colors.dart';
import '../../utils/html_parser.dart';
import '../../utils/notification_helper.dart';
import '../../services/storage_service.dart';
import '../layouts/dashboard_layout.dart';
import 'subject_scraping_screen.dart';
import 'curriculum_detail_screen.dart';

class CurriculumPreviewScreen extends StatefulWidget {
  final Curriculum curriculum;
  
  const CurriculumPreviewScreen({
    super.key,
    required this.curriculum,
  });

  @override
  State<CurriculumPreviewScreen> createState() => _CurriculumPreviewScreenState();
}

class _CurriculumPreviewScreenState extends State<CurriculumPreviewScreen> {
  void _confirmSelection() async {
    // Logic tương tự _handleItemClick cũ
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SubjectScrapingScreen(
          detailUrl: widget.curriculum.detailUrl,
          curriculumCode: widget.curriculum.code,
        ),
      ),
    );

    if (!mounted) return;

    if (result == 'SUCCESS') {
      NotificationHelper.showToast(context, 'Đã tải xong chi tiết của ${widget.curriculum.code}!');
      
      try {
        final htmlFile = File('curriculum_detail_${widget.curriculum.code}.html');
        final htmlStr = await htmlFile.readAsString();
        
        final subjects = HtmlParser.parseCurriculumDetail(htmlStr);
        await StorageService().saveCurriculumDetails(widget.curriculum.code, subjects);
        await htmlFile.delete();
        
        if (!mounted) return;
        
        // Push DashboardLayout
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DashboardLayout(
              userName: 'Guest',
              curriculumCode: widget.curriculum.code,
              subjects: subjects,
            ),
          ),
        );
      } catch (e) {
        NotificationHelper.showToast(context, 'Lỗi khi xử lý dữ liệu: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textMain,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Chi tiết chuyên ngành', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.curriculum.code,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.curriculum.name,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textMain,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Mô tả chi tiết',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    widget.curriculum.description.isEmpty 
                        ? 'Không có mô tả chi tiết cho chuyên ngành này.' 
                        : widget.curriculum.description,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSub,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _confirmSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Xác nhận chọn chuyên ngành',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
