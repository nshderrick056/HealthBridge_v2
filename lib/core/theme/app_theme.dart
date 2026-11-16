import 'package:flutter/material.dart';

/// Tokens from the Figma file "healthbridge-v2", page "Prototype v3 (reference style)".
/// The older names (teal, tealTint, ...) are kept so existing screens follow the new palette.
class HbColors {
  // v3 palette: brand green and lime lead; red and amber only mean urgent and due.
  static const brand = Color(0xFF19695A);
  static const brandLight = Color(0xFF3C8F63);
  static const brandDeep = Color(0xFF0F3F35);
  static const lime = Color(0xFFD4FF89);
  static const ink = Color(0xFF1D2220);
  static const muted = Color(0xFF5E6A66);
  static const canvas = Color(0xFFF1F4F3);
  static const white = Colors.white;
  static const line = Color(0xFFE6EBE9);

  /// Input and checkbox edges: 3.3:1 on the canvas, the minimum for a control's boundary.
  static const edge = Color(0xFF7E8A85);
  static const chevron = Color(0xFFB5BEBA);

  /// Secondary text on brand green (4.9:1).
  static const onBrand = Color(0xFFD7EAE3);
  static const red = Color(0xFFB3261E);

  /// Secondary text on the red (5:1).
  static const onRed = Color(0xFFFFE3E0);
  static const warning = Color(0xFF8A5300);
  static const amberMark = Color(0xFFE0A21E);

  // Older names, mapped onto the v3 palette.
  static const teal = brand;
  static const green = brand;
  static const textPrimary = ink;
  static const textSecondary = muted;
  static const surface = canvas;
  static const border = edge;
  static const divider = line;
  static const tealTint = Color(0xFFE3EFEA);
  static const greenTint = Color(0xFFE3EFEA);
  static const amberTint = Color(0xFFFBEFD2);
  static const redTint = Color(0xFFFDECEA);
  static const neutralTint = Color(0xFFE9EDEB);
}

class HbGradients {
  /// Feature cards: the next thing to do, the patient header.
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [HbColors.brand, HbColors.brandLight],
  );

  /// Full-screen green (sign in).
  static const deep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [HbColors.brand, HbColors.brandDeep],
  );
}

class HbShadows {
  static const card = [
    BoxShadow(color: Color(0x14102A22), blurRadius: 18, offset: Offset(0, 6)),
  ];
}

class HbText {
  static const _family = 'Outfit';
  static TextStyle _s(
    double size,
    FontWeight w,
    Color c, {
    double? height,
    double? spacing,
  }) => TextStyle(
    fontFamily: _family,
    fontSize: size,
    fontWeight: w,
    color: c,
    height: height,
    letterSpacing: spacing,
  );

  /// Sign-in headline.
  static final display = _s(
    44,
    FontWeight.w600,
    HbColors.ink,
    height: 1.1,
    spacing: -1.3,
  );
  static final headingLarge = _s(
    30,
    FontWeight.w600,
    HbColors.ink,
    height: 1.2,
    spacing: -0.6,
  );
  static final headingMedium = _s(
    20,
    FontWeight.w600,
    HbColors.ink,
    spacing: -0.2,
  );
  static final headingSmall = _s(17, FontWeight.w600, HbColors.ink);
  static final labelMedium = _s(15, FontWeight.w600, HbColors.ink);
  static final labelSmall = _s(14, FontWeight.w600, HbColors.ink);
  static final bodyMedium = _s(16, FontWeight.w400, HbColors.ink, height: 1.4);
  static final bodySmall = _s(
    15,
    FontWeight.w400,
    HbColors.muted,
    height: 1.35,
  );

  /// Tab labels only; everything else stays at 15 px or more.
  static final caption = _s(13, FontWeight.w500, HbColors.muted);
  static final sectionBold = _s(
    20,
    FontWeight.w600,
    HbColors.ink,
    spacing: -0.2,
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: HbColors.brand).copyWith(
    primary: HbColors.brand,
    onPrimary: Colors.white,
    secondary: HbColors.lime,
    onSecondary: HbColors.ink,
    error: HbColors.red,
    surface: HbColors.white,
    onSurface: HbColors.ink,
  );
  OutlineInputBorder border(Color c, [double w = 1.5]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: c, width: w),
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Outfit', // bundled in assets/fonts
    colorScheme: scheme,
    scaffoldBackgroundColor: HbColors.canvas,
    dividerColor: HbColors.line,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: HbColors.white,
      hintStyle: HbText.bodyMedium.copyWith(color: HbColors.muted),
      enabledBorder: border(HbColors.edge),
      focusedBorder: border(HbColors.brand, 2),
      errorBorder: border(HbColors.red, 2),
      focusedErrorBorder: border(HbColors.red, 2),
      errorStyle: HbText.bodySmall.copyWith(color: HbColors.red),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? HbColors.brand
            : Colors.transparent,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: HbColors.edge, width: 2),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: HbColors.white,
      selectedColor: HbColors.white,
      labelStyle: HbText.bodyMedium,
      shape: const StadiumBorder(),
      side: WidgetStateBorderSide.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? const BorderSide(color: HbColors.ink, width: 2)
            : const BorderSide(color: HbColors.line),
      ),
      showCheckmark: false,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: HbColors.ink,
      contentTextStyle: HbText.bodyMedium.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: HbColors.white,
      indicatorColor: HbColors.lime,
      labelTextStyle: WidgetStatePropertyAll(HbText.caption),
    ),
  );
}
