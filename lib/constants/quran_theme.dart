import 'package:flutter/material.dart';

class QuranTheme {
  final Color bg;
  final Color cardBg;
  final Color emeraldDeep;
  final Color emeraldMid;
  final Color emeraldLight;
  final Color emeraldGlow;
  final Color glassWhite;
  final Color borderGlass;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Brightness brightness;

  QuranTheme({
    required this.bg,
    required this.cardBg,
    required this.emeraldDeep,
    required this.emeraldMid,
    required this.emeraldLight,
    required this.emeraldGlow,
    required this.glassWhite,
    required this.borderGlass,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.brightness,
  });

  static QuranTheme of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return QuranTheme(
        bg: const Color(0xFF0F1711), // Very deep charcoal-green
        cardBg: const Color(0xFF1A241E), // Slightly lighter surface
        emeraldDeep: const Color(0xFF26A69A),
        emeraldMid: const Color(0xFF00897B),
        emeraldLight: const Color(0xFF4DB6AC),
        emeraldGlow: const Color(0xFF80CBC4),
        glassWhite: const Color(0x12FFFFFF),
        borderGlass: const Color(0x18FFFFFF),
        textPrimary: const Color(0xFFE0E2E0),
        textSecondary: const Color(0xFFB0B3B0),
        textMuted: const Color(0xFF707571),
        brightness: Brightness.dark,
      );
    } else {
      return QuranTheme(
        bg: const Color(0xFFFBFDFA), // Clean off-white
        cardBg: Colors.white,
        emeraldDeep: const Color(0xFF00695C),
        emeraldMid: const Color(0xFF00897B),
        emeraldLight: const Color(0xFF26A69A),
        emeraldGlow: const Color(0xFF004D40),
        glassWhite: const Color(0x0A000000),
        borderGlass: const Color(0x10000000),
        textPrimary: const Color(0xFF191C1B),
        textSecondary: const Color(0xFF3F4946),
        textMuted: const Color(0xFF707976),
        brightness: Brightness.light,
      );
    }
  }
}
