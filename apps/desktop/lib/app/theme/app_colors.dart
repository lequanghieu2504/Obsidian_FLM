import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors (Monochromatic Blue)
  static const Color primary = Color(0xFF2563EB); // Blue 600
  static const Color primaryLight = Color(0xFF60A5FA); // Blue 400
  static const Color primaryDark = Color(0xFF1D4ED8); // Blue 700
  static const Color primaryLighter = Color(0xFFDBEAFE); // Blue 100
  
  // Backgrounds
  static const Color background = Color(0xFFF8FAFC); // App background
  static const Color sidebarBackground = Color(0xFFEFF6FF); // Very light blue
  static const Color surface = Colors.white; // Card/Main content background
  static const Color rightPanelBackground = Color(0xFFF1F5F9); 
  
  // Text Colors
  static const Color textMain = Color(0xFF0F172A); // Slate 900
  static const Color textSub = Color(0xFF64748B); // Slate 500
  static const Color textInverse = Colors.white;

  // Status/Accents
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Gradients (Monochromatic Blue transitions)
  static const List<LinearGradient> cardGradients = [
    LinearGradient(
      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)], // Blue 500 -> 700
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [Color(0xFF60A5FA), Color(0xFF2563EB)], // Blue 400 -> 600
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [Color(0xFF93C5FD), Color(0xFF3B82F6)], // Blue 300 -> 500
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ];

  static LinearGradient getGradient(int index) {
    return cardGradients[index % cardGradients.length];
  }
}
