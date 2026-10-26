import 'package:flutter/material.dart';

/// Tokens from the Figma file "healthbridge-v2" (HealthBridge/* styles).
class HbColors {
  static const teal = Color(0xFF087A67);
  static const green = Color(0xFF147A49);
  static const red = Color(0xFFB4232C);
  static const warning = Color(0xFF9A5B00);
  static const textPrimary = Color(0xFF132824);
  static const textSecondary = Color(0xFF536A65);
  static const surface = Color(0xFFF4F7F6);
  static const white = Colors.white;
  static const border = Color(0xFFCBDAD6);
  static const divider = Color(0xFFE2EAE7);
  static const tealTint = Color(0xFFE5F4F0);
  static const greenTint = Color(0xFFE4F5EA);
  static const amberTint = Color(0xFFFFF2D6);
  static const redTint = Color(0xFFFDE8EA);
  static const neutralTint = Color(0xFFEDF3F1);
}

class HbText {
  static const _family = 'Inter';
  static TextStyle _s(double size, FontWeight w, Color c, [double? height]) =>
      TextStyle(
        fontFamily: _family,
        fontSize: size,
        fontWeight: w,
        color: c,
        height: height,
      );

  static final headingLarge = _s(24, FontWeight.w700, HbColors.textPrimary);
  static final headingMedium = _s(20, FontWeight.w600, HbColors.textPrimary);
  static final headingSmall = _s(16, FontWeight.w600, HbColors.textPrimary);
  static final labelMedium = _s(14, FontWeight.w600, HbColors.textPrimary);
  static final labelSmall = _s(12, FontWeight.w600, HbColors.textPrimary);
  static final bodyMedium = _s(14, FontWeight.w400, HbColors.textPrimary);
  static final bodySmall = _s(12, FontWeight.w400, HbColors.textSecondary);
  static final caption = _s(10, FontWeight.w400, HbColors.textSecondary);
  static final sectionBold = _s(14, FontWeight.w700, HbColors.textPrimary);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: HbColors.teal).copyWith(
    primary: HbColors.teal,
    error: HbColors.red,
    surface: HbColors.surface,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter', // falls back to the platform font until the Inter files are bundled
    colorScheme: scheme,
    scaffoldBackgroundColor: HbColors.surface,
    dividerColor: HbColors.divider,
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? HbColors.teal
            : Colors.transparent,
      ),
      side: const BorderSide(color: HbColors.border, width: 1.5),
    ),
  );
}
