import 'package:flutter/material.dart';

/// Warm "cookbook" palette: paper background, terracotta accent, olive secondary.
class AppColors {
  // Accent — terracotta
  static const Color primary = Color(0xFFB4532A);
  static const Color primaryDark = Color(0xFFE58B62); // accent on dark backgrounds

  // Secondary — olive
  static const Color olive = Color(0xFF5E6B3A);
  static const Color oliveDark = Color(0xFFB9C792);

  // Light neutrals
  static const Color paper = Color(0xFFFBF8F3);
  static const Color ink = Color(0xFF221E1A);
  static const Color inkMuted = Color(0xFF6E655B);
  static const Color line = Color(0xFFE6DED3);

  // Dark neutrals
  static const Color night = Color(0xFF16130F);
  static const Color nightCard = Color(0xFF221D18);
  static const Color nightInk = Color(0xFFEEE7DD);

  // Semantic
  static const Color error = Color(0xFFB3261E);
  static const Color success = Color(0xFF5E6B3A);
  static const Color warning = Color(0xFFA8761C);

  // Kept for older call sites
  static const Color primarySeed = primary;
  static const Color primaryLight = primaryDark;
  static const Color secondary = olive;
  static const Color textPrimary = ink;
  static const Color textSecondary = inkMuted;
  static const Color divider = line;
  static const Color surface = paper;
  static const Color surfaceDark = night;
  static const Color cardDark = nightCard;
}
