import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system);

  void setTheme(bool isDark) {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  void toggleTheme() {
    if (state == ThemeMode.system) {
      state = ThemeMode.light;
    } else {
      state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    }
  }

  bool get isDarkMode => state == ThemeMode.dark;
}
