import 'package:flutter/material.dart';

const brand = Color(0xFF0F766E);

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: brand, brightness: b);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFF4F6F8) : scheme.surface,
    appBarTheme: AppBarTheme(centerTitle: false, backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0, foregroundColor: scheme.onSurface),
    inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
  );
}
