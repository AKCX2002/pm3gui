/// PM3GUI app theme.
///
/// Dark-first design inspired by Proxmark3GUI's qdarkstyle.
library;

import 'package:flutter/material.dart';

class AppTheme {
  static const _primaryColor = Color(0xFF2196F3);
  static const _accentColor = Color(0xFF64FFDA);
  static const _errorColor = Color(0xFFFF5252);

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: _primaryColor,
        secondary: _accentColor,
        error: _errorColor,
        surface: const Color(0xFF1E1E2E),
      ),
      scaffoldBackgroundColor: const Color(0xFF181825),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E2E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: const Color(0xFF1E1E2E),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: const Color(0xFF2A2A3C),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(const Color(0xFF2A2A3C)),
        dataRowColor: WidgetStateProperty.all(Colors.transparent),
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white70,
          fontFamily: 'monospace',
        ),
        dataTextStyle: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Colors.white,
        ),
      ),
      dividerColor: const Color(0xFF3A3A4C),
      tabBarTheme: TabBarTheme(
        labelColor: _primaryColor,
        unselectedLabelColor: Colors.white54,
        indicatorColor: _primaryColor,
      ),
    );
  }

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: _primaryColor,
        secondary: const Color(0xFF00BFA5),
        error: _errorColor,
      ),
      cardTheme: CardTheme(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
        dataTextStyle: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
        ),
      ),
    );
  }
}
