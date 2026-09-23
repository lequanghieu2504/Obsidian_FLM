import 'package:flutter/material.dart';
import '../../utils/notification_helper.dart';
import '../../app/theme/app_colors.dart';
import '../layouts/dashboard_layout.dart';
import '../../utils/folder_reader.dart';
import '../../models/curriculum_data.dart';
import '../../utils/user_settings.dart';

class HomeScreen extends StatefulWidget {
  final bool forceShowUpload;

  const HomeScreen({super.key, this.forceShowUpload = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;
  bool _hasCache = false;
  bool _isCheckingCache = true;

  @override
  void initState() {
    super.initState();
    _checkCache();
  }

  Future<void> _checkCache() async {
    await UserSettings.ensureLoaded();
    final cached = await FolderReader.getCachedCurriculum();
    if (!mounted) return;
    
    if (cached != null && !widget.forceShowUpload) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => DashboardLayout(curriculumData: cached),
        ),
      );
    } else {
      setState(() {
        _isCheckingCache = false;
        _hasCache = cached != null;
      });
    }
  }

  void _handleUploadFolder() async {
    setState(() {
      _isLoading = true;
    });

    try {
      var curriculumData = await FolderReader.importAndParseFolder();
      
      if (!mounted) return;
      
      if (curriculumData == null) {
        setState(() {
          _isLoading = false;
        });
        return; // User canceled picker
      }

      if (curriculumData.combos.isNotEmpty) {
        final selectedComboId = await _showComboSelectionDialog(curriculumData.combos);
        if (selectedComboId != null) {
          await FolderReader.saveSelectedCombo(selectedComboId);
          // Re-parse để lấy dữ liệu đã lọc môn theo combo
          curriculumData = await FolderReader.getCachedCurriculum();
        }
      }
      
      if (!mounted || curriculumData == null) return;
      
      NotificationHelper.showToast(context, 'Tải dữ liệu thành công!');
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => DashboardLayout(curriculumData: curriculumData!),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      NotificationHelper.showToast(context, 'Lỗi tải dữ liệu: $e', isError: true);
    }
  }

  Future<String?> _showComboSelectionDialog(List<Combo> combos) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false, // Bắt buộc chọn
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Chọn Chuyên ngành hẹp', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: combos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final combo = combos[index];
                return InkWell(
                  onTap: () => Navigator.of(context).pop(combo.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.primaryBg,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bookmark_added_rounded, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            combo.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _handleLoadCache() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final curriculumData = await FolderReader.getCachedCurriculum();
      
      if (!mounted) return;
      
      if (curriculumData != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DashboardLayout(curriculumData: curriculumData),
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
        });
        NotificationHelper.showToast(context, 'Không tìm thấy dữ liệu đã lưu', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      NotificationHelper.showToast(context, 'Lỗi đọc dữ liệu: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingCache) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Nửa trái: Illustration
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
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.school_rounded, size: 80, color: Colors.white),
                    const SizedBox(height: 32),
                    const Text(
                      'Làm chủ lộ trình\nhọc tập của bạn',
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
                      'Tận dụng dữ liệu từ hệ thống để phân tích, sắp xếp và vạch ra chiến lược học tập hiệu quả nhất.',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.8),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Nửa phải: Hướng dẫn & Tải lên
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
                      color: Colors.black.withOpacity(0.03),
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
                        const Icon(Icons.extension_rounded, color: AppColors.primaryLight, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Chuẩn bị dữ liệu',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryLight.withOpacity(0.8),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Tải lên khung chương trình',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textMain,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInstructionStep(
                            '1',
                            'Cài đặt Extension "Obsidian FLM" trên trình duyệt của bạn.',
                          ),
                          const SizedBox(height: 12),
                          _buildInstructionStep(
                            '2',
                            'Đăng nhập vào hệ thống trường và dùng Extension để tải về thư mục dữ liệu.',
                          ),
                          const SizedBox(height: 12),
                          _buildInstructionStep(
                            '3',
                            'Giải nén thư mục vừa tải và chọn tải lên tại đây.',
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _handleUploadFolder,
                          icon: const Icon(Icons.folder_open_rounded),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          label: const Text('Chọn thư mục dữ liệu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      
                      if (_hasCache) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: _handleLoadCache,
                            icon: const Icon(Icons.history_rounded),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.primary.withOpacity(0.5), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            label: const Text('Tiếp tục với dữ liệu lần trước', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ]
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String step, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textMain,
              height: 1.4,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
