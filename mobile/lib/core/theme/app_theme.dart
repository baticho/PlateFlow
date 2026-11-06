import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Serif display face for titles, Inter for UI text.
const String kDisplayFont = 'Lora';
const String kTextFont = 'Inter';

class AppTheme {
  static const _light = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFF6DDD0),
    onPrimaryContainer: Color(0xFF4A1B08),
    secondary: AppColors.olive,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE3E7CF),
    onSecondaryContainer: Color(0xFF1F2610),
    tertiary: Color(0xFFA8761C),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFF5E2BC),
    onTertiaryContainer: Color(0xFF3A2700),
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: AppColors.paper,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkMuted,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF6F1EA),
    surfaceContainer: Color(0xFFF1EBE2),
    surfaceContainerHigh: Color(0xFFEBE4D9),
    surfaceContainerHighest: Color(0xFFE5DDD0),
    outline: Color(0xFFCFC5B8),
    outlineVariant: AppColors.line,
    inverseSurface: Color(0xFF332E29),
    onInverseSurface: Color(0xFFF7F1E8),
    inversePrimary: AppColors.primaryDark,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  static const _dark = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.primaryDark,
    onPrimary: Color(0xFF3A1404),
    primaryContainer: Color(0xFF5C2A14),
    onPrimaryContainer: Color(0xFFFFDCCB),
    secondary: AppColors.oliveDark,
    onSecondary: Color(0xFF263010),
    secondaryContainer: Color(0xFF3D4725),
    onSecondaryContainer: Color(0xFFE3E7CF),
    tertiary: Color(0xFFE5BE73),
    onTertiary: Color(0xFF3A2700),
    tertiaryContainer: Color(0xFF574008),
    onTertiaryContainer: Color(0xFFF5E2BC),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    surface: AppColors.night,
    onSurface: AppColors.nightInk,
    onSurfaceVariant: Color(0xFFB5AA9C),
    surfaceContainerLowest: Color(0xFF110E0B),
    surfaceContainerLow: Color(0xFF1C1814),
    surfaceContainer: AppColors.nightCard,
    surfaceContainerHigh: Color(0xFF2B251F),
    surfaceContainerHighest: Color(0xFF342D26),
    outline: Color(0xFF5A5047),
    outlineVariant: Color(0xFF3A322A),
    inverseSurface: Color(0xFFEEE7DD),
    onInverseSurface: Color(0xFF332E29),
    inversePrimary: AppColors.primary,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  static ThemeData light() => _build(_light);
  static ThemeData dark() => _build(_dark);

  static ThemeData _build(ColorScheme cs) {
    final base = ThemeData(useMaterial3: true, colorScheme: cs, fontFamily: kTextFont);
    TextStyle? serif(TextStyle? s, {double? height}) =>
        s?.copyWith(fontFamily: kDisplayFont, fontWeight: FontWeight.w600, height: height, letterSpacing: -0.2);
    final tt = base.textTheme;
    final textTheme = tt.copyWith(
      displaySmall: serif(tt.displaySmall),
      headlineLarge: serif(tt.headlineLarge),
      headlineMedium: serif(tt.headlineMedium),
      headlineSmall: serif(tt.headlineSmall, height: 1.2),
      titleLarge: serif(tt.titleLarge, height: 1.25),
      titleMedium: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.1),
    ).apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);

    final rounded10 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));

    return base.copyWith(
      scaffoldBackgroundColor: cs.surface,
      textTheme: textTheme,
      dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: kDisplayFont,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
          letterSpacing: -0.2,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? cs.primary : cs.onSurfaceVariant,
              size: 24,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 11,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? cs.primary : cs.onSurfaceVariant,
            )),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        shape: rounded10,
        side: BorderSide(color: cs.outline),
        backgroundColor: cs.surface,
        selectedColor: cs.onSurface,
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface),
        secondaryLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.surface),
        checkmarkColor: cs.surface,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outline)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outline)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerLowest),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: cs.outline),
        )),
        hintStyle: WidgetStatePropertyAll(TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: rounded10,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: rounded10,
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.outline),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: rounded10,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: cs.primary, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: rounded10,
          side: BorderSide(color: cs.outline),
          selectedBackgroundColor: cs.onSurface,
          selectedForegroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: cs.onSurface,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicatorColor: cs.primary,
        dividerColor: cs.outlineVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: cs.outline,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(color: cs.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: cs.outline, width: 1.5),
      ),
      listTileTheme: ListTileThemeData(iconColor: cs.onSurfaceVariant),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: cs.primary),
    );
  }
}
