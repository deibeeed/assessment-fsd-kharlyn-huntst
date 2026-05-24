import 'package:ad_ranking_prototype/data/models/ad.dart';
import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.light,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
    );
  }
}

Color tierColor(AdTier tier) {
  switch (tier) {
    case AdTier.gold:
      return const Color(0xFFD4AF37);
    case AdTier.silver:
      return const Color(0xFFB0B0B0);
    case AdTier.bronze:
      return const Color(0xFFB87333);
  }
}

String tierLabel(AdTier tier) {
  switch (tier) {
    case AdTier.gold:
      return 'GOLD';
    case AdTier.silver:
      return 'SILVER';
    case AdTier.bronze:
      return 'BRONZE';
  }
}
