import 'package:flutter/material.dart';

class AppColors {
  // Monochromatic Blue System
  static const Color primary = Color(0xFF2563EB); // blue-600
  static const Color primaryLight = Color(0xFF3B82F6); // blue-500
  static const Color primaryDark = Color(0xFF1D4ED8); // blue-700
  static const Color primaryBg = Color(0xFFEFF6FF); // blue-50
  
  // Neutral Colors (Background & Surface)
  static const Color background = Color(0xFFF8FAFC); // slate-50
  static const Color surface = Colors.white;
  static const Color sidebarBackground = Color(0xFFF1F5F9); // slate-100
  
  // Text Colors
  static const Color textMain = Color(0xFF0F172A); // slate-900
  static const Color textSub = Color(0xFF64748B); // slate-500
  static const Color textInverse = Colors.white;

  // Semantic Colors
  static const Color success = Color(0xFF10B981); // emerald-500
  static const Color warning = Color(0xFFF59E0B); // amber-500
  static const Color error = Color(0xFFEF4444); // red-500
  static const Color info = primary; // Alias for primary in this theme

  // Gradients for Cards
  static const List<LinearGradient> cardGradients = [
    LinearGradient(
      colors: [Color(0xFF2563EB), Color(0xFF3B82F6)], // blue-600 to blue-500
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)], // blue-700 to blue-600
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)], // blue-900 to blue-800
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ];

  static LinearGradient getGradient(int index) {
    return cardGradients[index % cardGradients.length];
  }
}
