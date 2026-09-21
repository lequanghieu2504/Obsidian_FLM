import 'package:flutter/material.dart';
import '../features/subjects/presentation/subject_catalog_screen.dart';

class ObsidianFlmApp extends StatelessWidget {
  const ObsidianFlmApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Obsidian FLM',
        theme: _buildTheme(),
        home: const SubjectCatalogScreen(curriculumCode: 'BIT_SE_K19B'),
      );
}

/// App-wide Material 3 theme, built from one seed color per the design
/// system's "token before component" rule: every Card/AppBar/input below
/// pulls its color, radius and border from this theme rather than being
/// hand-styled where it's used.
ThemeData _buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF4355B9));
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      centerTitle: false,
      scrolledUnderElevation: 3,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
  );
}
