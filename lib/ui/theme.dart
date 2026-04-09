/// PM3GUI app theme — 深蓝色仪表盘风格 (Dark Dashboard).
///
/// 深色仪表盘标准配色：深蓝背景、卡片色、高亮蓝与辅助灰文。
library;

import 'package:flutter/material.dart';

class AppTheme {
  // ── 深蓝色仪表盘配色 ─────────────────────────────────────
  // 深色仪表盘标准配色：深蓝背景、卡片色、高亮蓝与辅助灰文
  static const _darkBg = Color(0xFF0F172A); // 深蓝背景
  static const _darkSurface = Color(0xFF1E293B); // 卡片色
  static const _accentBlue = Color(0xFF38BDF8); // 高亮蓝
  static const _auxiliaryGrey = Color(0xFF94A3B8); // 辅助灰文
  static const _darkDivider = Color(0xFF334155); // 分隔线
  static const _darkInputFill = Color(0xFF1E293B); // 输入框背景

  // ── 单模式主题 ───────────────────────────────────────────
  static ThemeData theme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: _accentBlue,
        secondary: _accentBlue,
        tertiary: _accentBlue,
        error: const Color(0xFFF87171),
        surface: _darkSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: _auxiliaryGrey,
        outline: _darkDivider,
      ),
      scaffoldBackgroundColor: _darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkSurface,
        foregroundColor: _auxiliaryGrey,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: _darkSurface,
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
          borderSide: const BorderSide(color: _accentBlue, width: 1.5),
        ),
        filled: true,
        fillColor: _darkInputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        hintStyle: TextStyle(color: Colors.grey[600]),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _accentBlue,
          side: const BorderSide(color: _accentBlue, width: 0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _darkInputFill,
        selectedColor: _accentBlue.withValues(alpha: 0.25),
        labelStyle: const TextStyle(fontSize: 12),
        side: const BorderSide(color: _darkDivider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return _accentBlue.withValues(alpha: 0.25);
            }
            return _darkInputFill;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return _accentBlue;
            }
            return _auxiliaryGrey;
          }),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(_darkInputFill),
        dataRowColor: WidgetStateProperty.all(Colors.transparent),
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: _auxiliaryGrey,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
        dataTextStyle: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: _auxiliaryGrey,
        ),
      ),
      dividerColor: _darkDivider,
      tabBarTheme: TabBarThemeData(
        labelColor: _accentBlue,
        unselectedLabelColor: const Color(0xFF64748B),
        indicatorColor: _accentBlue,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _accentBlue;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: _darkDivider),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: _accentBlue,
        collapsedIconColor: const Color(0xFF64748B),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        linearTrackColor: _darkInputFill,
        color: _accentBlue,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkSurface,
        contentTextStyle: const TextStyle(color: _auxiliaryGrey),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── 语义色彩 helper ──────────────────────────────────────
  static Color get darkBg => _darkBg;
  static Color get darkSurface => _darkSurface;
  static Color get accentBlue => _accentBlue;
  static Color get auxiliaryGrey => _auxiliaryGrey;
  static Color get darkDivider => _darkDivider;
  static Color get darkInputFill => _darkInputFill;
}
