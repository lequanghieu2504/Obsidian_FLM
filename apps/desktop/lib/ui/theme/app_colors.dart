import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds cho 3 cột
  static const Color sidebarBackground = Color(0xFFF3F6FD); // Nền mờ nhạt cho Sidebar (cột 1)
  static const Color mainContentBackground = Colors.white;  // Nền trắng tinh cho Content (cột 2)
  static const Color rightPanelBackground = Color(0xFFF8FAFC); // Nền mờ nhạt cho Right Panel (cột 3)
  
  static const Color textMain = Color(0xFF1E293B);
  static const Color textSub = Color(0xFF64748B);
  
  // Gradients cho các Card (Tone Pastel mềm mại, sang trọng)
  static const List<LinearGradient> cardGradients = [
    // Soft Mint
    LinearGradient(
      colors: [Color(0xFF86E3CE), Color(0xFF4CBEA3)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    // Peach / Coral
    LinearGradient(
      colors: [Color(0xFFFFDD94), Color(0xFFFA897B)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    // Lavender
    LinearGradient(
      colors: [Color(0xFFCCABD8), Color(0xFF8675A9)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    // Soft Lime
    LinearGradient(
      colors: [Color(0xFFD0E6A5), Color(0xFF98C448)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    // Baby Blue
    LinearGradient(
      colors: [Color(0xFF93A5CF), Color(0xFFE4EfE9)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ];

  static LinearGradient getGradient(int index) {
    return cardGradients[index % cardGradients.length];
  }
}
