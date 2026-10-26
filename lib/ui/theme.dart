import 'package:flutter/material.dart';

import '../core/cards.dart';

class AppColors {
  AppColors._();
  static const ink = Color(0xFF1B1440);
  static const night = Color(0xFF2A1F5C);
  static const violet = Color(0xFF7B5CFF);
  static const gold = Color(0xFFFFB627);
  static const teal = Color(0xFF2EC4B6);
  static const coral = Color(0xFFFF6B6B);
  static const mist = Color(0xFFF3F1FA);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.violet,
    brightness: Brightness.dark,
    surface: AppColors.ink,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ink,
    useMaterial3: true,
  );
}

Color rarityColor(Rarity r) => Color(r.color);
