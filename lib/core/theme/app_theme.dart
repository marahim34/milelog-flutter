import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Palette mirrors the original app's carbon/teal/amber scheme.
  static const _teal = Color(0xFF00BCD4);
  static const _background = Color(0xFF121212);
  static const _surface = Color(0xFF1A1A1A);
  static const _card = Color(0xFF242424);
  static const _divider = Color(0x14FFFFFF); // 8% white

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _teal,
          brightness: Brightness.dark,
          surface: _surface,
        ),
        scaffoldBackgroundColor: _background,
        cardColor: _card,
        cardTheme: CardThemeData(
          color: _card,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: _surface,
          selectedItemColor: _teal,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: _teal,
          foregroundColor: Colors.black,
          elevation: 4,
        ),
        dividerTheme: const DividerThemeData(color: _divider, space: 1),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _teal, width: 1.5),
          ),
          labelStyle: const TextStyle(color: Colors.grey),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: _teal),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _teal,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _card,
          selectedColor: _teal.withAlpha(50),
          labelStyle: const TextStyle(color: Colors.white),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? _teal : Colors.grey,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? _teal.withAlpha(80)
                : Colors.grey.withAlpha(60),
          ),
        ),
      );
}
