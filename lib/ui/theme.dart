/// PM3GUI app theme — 莫兰迪色系 (Morandi palette).
///
/// Muted, low-saturation, warm-toned colors for a refined aesthetic.
library;

import 'package:flutter/material.dart';

class AppTheme {
  // ── 莫兰迪色板 ──────────────────────────────────────────
  // 主色调：雾蓝 / 灰豆绿 / 灰玫瑰 / 暖灰
  static const _morandiBlue = Color(0xFF7E9AAB); // 莫兰迪蓝
  static const _morandiGreen = Color(0xFF8FA9A0); // 莫兰迪绿
  static const _morandiRose = Color(0xFFBFA2A2); // 莫兰迪玫瑰
  static const _morandiTaupe = Color(0xFFA89F91); // 莫兰迪暖灰
  static const _morandiLavender = Color(0xFF9B96B4); // 莫兰迪薰衣草
  static const _morandiError = Color(0xFFC47D7D); // 柔和红
  static const _morandiSuccess = Color(0xFF8EAD8E); // 柔和绿
  static const _morandiWarning = Color(0xFFC9B07F); // 柔和黄

  // ── 深色面板 ────────────────────────────────────────────
  static const _darkBg = Color(0xFF232832);
  static const _darkSurface = Color(0xFF2A303B);
  static const _darkCard = Color(0xFF2E3441);
  static const _darkDivider = Color(0xFF3A4050);
  static const _darkInputFill = Color(0xFF323845);

  // ── 浅色面板 ────────────────────────────────────────────
  static const _lightBg = Color(0xFFF2EDE8);
  static const _lightSurface = Color(0xFFFAF7F4);
  static const _lightCard = Color(0xFFFFFFFF);
  static const _lightDivider = Color(0xFFDAD3CC);
  static const _lightInputFill = Color(0xFFF5F1ED);

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: _morandiBlue,
        secondary: _morandiGreen,
        tertiary: _morandiLavender,
        error: _morandiError,
        surface: _darkSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: const Color(0xFFD4D0CC),
        outline: _darkDivider,
      ),
      scaffoldBackgroundColor: _darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkSurface,
        foregroundColor: Color(0xFFD4D0CC),
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: _darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _darkDivider, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _darkDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _darkDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _morandiBlue, width: 1.5),
        ),
        filled: true,
        fillColor: _darkInputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        hintStyle: TextStyle(color: Colors.grey[600]),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _morandiBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _morandiBlue,
          side: const BorderSide(color: _morandiBlue, width: 0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _darkInputFill,
        selectedColor: _morandiBlue.withValues(alpha: 0.25),
        labelStyle: const TextStyle(fontSize: 12),
        side: const BorderSide(color: _darkDivider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return _morandiBlue.withValues(alpha: 0.25);
            }
            return _darkInputFill;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return _morandiBlue;
            }
            return const Color(0xFFD4D0CC);
          }),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(_darkInputFill),
        dataRowColor: WidgetStateProperty.all(Colors.transparent),
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFFB0ADA8),
          fontFamily: 'monospace',
          fontSize: 12,
        ),
        dataTextStyle: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Color(0xFFD4D0CC),
        ),
      ),
      dividerColor: _darkDivider,
      tabBarTheme: TabBarTheme(
        labelColor: _morandiBlue,
        unselectedLabelColor: const Color(0xFF8A8680),
        indicatorColor: _morandiBlue,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _morandiBlue;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: _darkDivider),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: _morandiBlue,
        collapsedIconColor: Color(0xFF8A8680),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        linearTrackColor: _darkInputFill,
        color: _morandiBlue,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkCard,
        contentTextStyle: const TextStyle(color: Color(0xFFD4D0CC)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: _morandiBlue,
        secondary: _morandiGreen,
        tertiary: _morandiLavender,
        error: _morandiError,
        surface: _lightSurface,
        onPrimary: Colors.white,
        onSurface: const Color(0xFF4A4540),
        outline: _lightDivider,
      ),
      scaffoldBackgroundColor: _lightBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightSurface,
        foregroundColor: Color(0xFF4A4540),
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: _lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _lightDivider, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _lightDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _lightDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _morandiBlue, width: 1.5),
        ),
        filled: true,
        fillColor: _lightInputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _morandiBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _morandiBlue,
          side: const BorderSide(color: _morandiBlue, width: 0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _lightInputFill,
        selectedColor: _morandiBlue.withValues(alpha: 0.15),
        labelStyle: const TextStyle(fontSize: 12),
        side: const BorderSide(color: _lightDivider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          fontSize: 12,
          color: Color(0xFF6A645E),
        ),
        dataTextStyle: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Color(0xFF4A4540),
        ),
      ),
      dividerColor: _lightDivider,
      tabBarTheme: TabBarTheme(
        labelColor: _morandiBlue,
        unselectedLabelColor: const Color(0xFF8A8480),
        indicatorColor: _morandiBlue,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _lightCard,
        contentTextStyle: const TextStyle(color: Color(0xFF4A4540)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── 语义色彩 helper ──────────────────────────────────────
  static Color get morandiBlue => _morandiBlue;
  static Color get morandiGreen => _morandiGreen;
  static Color get morandiRose => _morandiRose;
  static Color get morandiTaupe => _morandiTaupe;
  static Color get morandiLavender => _morandiLavender;
  static Color get morandiError => _morandiError;
  static Color get morandiSuccess => _morandiSuccess;
  static Color get morandiWarning => _morandiWarning;
}
