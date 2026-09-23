import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';

class NotificationHelper {
  /// Hiển thị thông báo dạng Toast nhỏ góc trên màn hình (dành cho thông báo phụ)
  static void showToast(BuildContext context, String message, {bool isError = false}) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Segoe UI', 
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 24, left: 24, right: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 10,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  /// Hiển thị Modal to, rõ ràng giữa màn hình (dành cho thông báo quan trọng, xác nhận)
  static Future<void> showImportantModal({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    Color iconColor = AppColors.primary,
    String confirmText = 'Xác nhận',
    String cancelText = 'Hủy',
    required VoidCallback onConfirm,
  }) {
    return showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              )
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: iconColor),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Segoe UI',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Segoe UI',
                  fontSize: 15,
                  color: AppColors.textSub,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                        foregroundColor: AppColors.textSub,
                      ),
                      child: Text(cancelText, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        onConfirm();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
