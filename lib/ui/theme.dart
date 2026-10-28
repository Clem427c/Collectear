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
    // Retour de Clem du 28/10 : messages en bas d'écran illisibles (texte sombre sur fond sombre).
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.night,
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
      actionTextColor: AppColors.gold,
    ),
    useMaterial3: true,
  );
}

Color rarityColor(Rarity r) => Color(r.color);
