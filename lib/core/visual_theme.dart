import 'package:flutter/material.dart';

const forest = Color(0xFF173F35);
const paper = Color(0xFFFAF8F2);
const honey = Color(0xFFF1C66D);
const clay = Color(0xFFAC583D);
const muted = Color(0xFF647169);
const line = Color(0xFFE1E5DA);

ThemeData vitrinaTheme() {
  final base = ThemeData(useMaterial3: true, fontFamily: 'Manrope');
  final text = base.textTheme.apply(bodyColor: forest, displayColor: forest);
  TextStyle display(TextStyle? style, double size) => style!.copyWith(
    fontFamily: 'Fraunces',
    fontSize: size,
    fontWeight: FontWeight.w600,
    height: 1.12,
    letterSpacing: -.7,
  );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: forest,
      primary: forest,
      secondary: clay,
      surface: paper,
      onSurface: forest,
      outline: line,
    ),
    scaffoldBackgroundColor: paper,
    textTheme: text.copyWith(
      displayLarge: display(text.displayLarge, 60),
      displayMedium: display(text.displayMedium, 48),
      headlineLarge: display(text.headlineLarge, 40),
      headlineMedium: display(text.headlineMedium, 32),
      headlineSmall: display(text.headlineSmall, 26),
      titleLarge: text.titleLarge!.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        letterSpacing: -.5,
      ),
      titleMedium: text.titleMedium!.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: text.bodyLarge!.copyWith(fontSize: 15, height: 1.6),
      bodyMedium: text.bodyMedium!.copyWith(fontSize: 13, height: 1.6),
      labelLarge: text.labelLarge!.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: paper,
      foregroundColor: forest,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 76,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
      labelStyle: const TextStyle(color: muted, fontSize: 14),
      hintStyle: const TextStyle(color: muted, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: forest, width: 1.6),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
        shape: rounded,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: forest,
        side: const BorderSide(color: line),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        shape: rounded,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: rounded,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFE6EDDD),
      side: const BorderSide(color: line),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      labelStyle: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 74,
      elevation: 0,
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFE8EFDF),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: forest,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: line, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: forest,
      shape: rounded,
    ),
  );
}
