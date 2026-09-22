import 'package:flutter/material.dart';

/// Detox Calma design system tokens.
///
/// Principles:
/// - One accent color; green/red reserved for real semantic states.
/// - Flat surfaces: separation via space and surface color, never shadows.
/// - Single corner radius ([detoxRadius]); pills and progress tracks use
///   [detoxRadiusPill]. Never an in-between value.
/// - Hierarchy through size and weight ([detoxWeightEmphasis] is the ceiling),
///   never through color noise.
///
/// Screen patterns (keep new screens on one of these two shapes):
/// - Hero-first screens (Dashboard, Focus) open with the one number that
///   matters and no page header.
/// - Section screens (Progress, Stats, Settings, Sponsor, Automation) open with
///   `AppPageHeader` from `widgets/ui_kit.dart`.
class DetoxColors {
  // Dark palette (default). Calm teal-sage accent on warm charcoal neutrals.
  static const Color bg = Color(0xFF0D1210);
  static const Color bgAlt = Color(0xFF101714);
  static const Color card = Color(0xFF151C19);
  static const Color surface = Color(0xFF151C19);
  static const Color cardBorder = Color(0x14FFFFFF);
  static const Color cardSubtle = Color(0x0AFFFFFF);
  static const Color accent = Color(0xFF7FB8A4);
  static const Color accentSoft = Color(0xFFA8CFC0);
  static const Color accentDeep = Color(0xFF3E5D52);
  static const Color success = Color(0xFF7FB8A4);
  static const Color warning = Color(0xFFD9B36C);
  static const Color danger = Color(0xFFD98C8C);
  static const Color text = Color(0xFFE8EDEA);
  static const Color muted = Color(0xFF8C988F);

  // Light palette. Warm paper with soft sage ink.
  static const Color lightBg = Color(0xFFF6F7F4);
  static const Color lightBgAlt = Color(0xFFEFF1EC);
  static const Color lightCard = Colors.white;
  static const Color lightSurface = Colors.white;
  static const Color lightCardBorder = Color(0x14202B26);
  static const Color lightCardSubtle = Color(0xFFF8FAFF);
  static const Color lightText = Color(0xFF202B26);
  static const Color lightMuted = Color(0xFF6E7A72);
}

/// Type scale: display (hero numbers) / title / body / caption.
const TextTheme _detoxTextTheme = TextTheme(
  displayLarge: TextStyle(fontSize: 42, fontWeight: FontWeight.w600, letterSpacing: -1.0, height: 1.0),
  displayMedium: TextStyle(fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: -0.5, height: 1.05),
  headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.2),
  titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.25),
  titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
  bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.45),
  bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.4),
  labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.3, letterSpacing: 0.2),
);

const double detoxRadius = 16;

/// Fully round shapes (progress bars, pills). The only radius besides
/// [detoxRadius] that the system allows.
const double detoxRadiusPill = 999;

/// The single allowed font weight ceiling for emphasis.
const FontWeight detoxWeightEmphasis = FontWeight.w600;

class DetoxTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: DetoxColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: DetoxColors.accentDeep,
        secondary: DetoxColors.accent,
        surface: DetoxColors.card,
        onSurface: DetoxColors.text,
      ),
      textTheme: _detoxTextTheme.apply(
        bodyColor: DetoxColors.text,
        displayColor: DetoxColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: DetoxColors.text,
        elevation: 0,
        centerTitle: false,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: DetoxColors.text,
        textColor: DetoxColors.text,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: DetoxColors.card,
        contentTextStyle: _detoxTextTheme.bodyMedium?.copyWith(color: DetoxColors.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(detoxRadius)),
        behavior: SnackBarBehavior.floating,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DetoxColors.accentDeep,
          foregroundColor: DetoxColors.accentSoft,
          minimumSize: const Size.fromHeight(56),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(detoxRadius)),
          textStyle: _detoxTextTheme.titleMedium,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? DetoxColors.accent.withOpacity(0.18)
                : null,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          foregroundColor: DetoxColors.text,
          side: const BorderSide(color: DetoxColors.cardBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(detoxRadius)),
          textStyle: _detoxTextTheme.titleMedium,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: DetoxColors.accentDeep,
        foregroundColor: DetoxColors.accentSoft,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: DetoxColors.card,
        side: const BorderSide(color: DetoxColors.cardBorder),
        selectedColor: DetoxColors.accent.withOpacity(0.16),
        labelStyle: const TextStyle(color: DetoxColors.text, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(detoxRadius)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DetoxColors.bgAlt,
        labelStyle: const TextStyle(color: DetoxColors.muted),
        hintStyle: const TextStyle(color: DetoxColors.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(detoxRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(detoxRadius),
          borderSide: const BorderSide(color: DetoxColors.accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(detoxRadius),
          borderSide: const BorderSide(color: DetoxColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(detoxRadius),
          borderSide: const BorderSide(color: DetoxColors.danger, width: 1.4),
        ),
      ),
      dividerColor: DetoxColors.cardBorder,
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: DetoxColors.bg,
        indicatorColor: DetoxColors.accent.withOpacity(0.16),
        shadowColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            color: states.contains(WidgetState.selected) ? DetoxColors.text : DetoxColors.muted,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? DetoxColors.accent : DetoxColors.muted,
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: DetoxColors.accent,
        linearTrackColor: Color(0x14FFFFFF),
        circularTrackColor: Color(0x14FFFFFF),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? DetoxColors.accentDeep
              : DetoxColors.muted.withOpacity(0.35),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: DetoxColors.accentDeep,
        thumbColor: DetoxColors.accentDeep,
        inactiveTrackColor: Color(0x14FFFFFF),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? DetoxColors.accentDeep : Colors.transparent,
        ),
        side: const BorderSide(color: DetoxColors.muted),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(_detoxTextTheme.titleMedium),
          side: const WidgetStatePropertyAll(BorderSide(color: DetoxColors.cardBorder)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(detoxRadius)),
          ),
        ),
      ),
    );
  }

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: DetoxColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: DetoxColors.accentDeep,
        secondary: DetoxColors.accent,
        surface: DetoxColors.lightSurface,
        onSurface: DetoxColors.lightText,
      ),
      textTheme: _detoxTextTheme.apply(
        bodyColor: DetoxColors.lightText,
        displayColor: DetoxColors.lightText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: DetoxColors.lightText,
        elevation: 0,
        centerTitle: false,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: DetoxColors.lightText,
        textColor: DetoxColors.lightText,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: DetoxColors.lightCard,
        contentTextStyle: _detoxTextTheme.bodyMedium?.copyWith(color: DetoxColors.lightText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(detoxRadius)),
        behavior: SnackBarBehavior.floating,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DetoxColors.accentDeep,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(detoxRadius)),
          textStyle: _detoxTextTheme.titleMedium,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? DetoxColors.accent.withOpacity(0.25)
                : null,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          foregroundColor: DetoxColors.lightText,
          side: const BorderSide(color: DetoxColors.lightCardBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(detoxRadius)),
          textStyle: _detoxTextTheme.titleMedium,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: DetoxColors.accentDeep,
        foregroundColor: Colors.white,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0xFFF1F3F4),
        side: const BorderSide(color: DetoxColors.lightCardBorder),
        selectedColor: DetoxColors.accent.withOpacity(0.18),
        labelStyle: const TextStyle(color: DetoxColors.lightText, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(detoxRadius)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F3EF),
        labelStyle: const TextStyle(color: DetoxColors.lightMuted),
        hintStyle: const TextStyle(color: DetoxColors.lightMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(detoxRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(detoxRadius),
          borderSide: const BorderSide(color: DetoxColors.accentDeep, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(detoxRadius),
          borderSide: const BorderSide(color: DetoxColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(detoxRadius),
          borderSide: const BorderSide(color: DetoxColors.danger, width: 1.4),
        ),
      ),
      dividerColor: DetoxColors.lightCardBorder,
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: DetoxColors.lightBg,
        indicatorColor: DetoxColors.accent.withOpacity(0.10),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            color: states.contains(WidgetState.selected) ? DetoxColors.lightText : DetoxColors.lightMuted,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? DetoxColors.accent : DetoxColors.lightMuted,
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: DetoxColors.accentDeep,
        linearTrackColor: Color(0x14202B26),
        circularTrackColor: Color(0x14202B26),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? DetoxColors.accentDeep
              : DetoxColors.lightMuted.withOpacity(0.35),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: DetoxColors.accentDeep,
        thumbColor: DetoxColors.accentDeep,
        inactiveTrackColor: Color(0x14202B26),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? DetoxColors.accentDeep : Colors.transparent,
        ),
        side: const BorderSide(color: DetoxColors.lightMuted),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(_detoxTextTheme.titleMedium),
          side: const WidgetStatePropertyAll(BorderSide(color: DetoxColors.lightCardBorder)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(detoxRadius)),
          ),
        ),
      ),
    );
  }
}

/// Flat background: solid color only. The design disappears so the data can
/// speak (calm technology / reduced extraneous cognitive load).
class DetoxBackground extends StatelessWidget {
  const DetoxBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }
}

/// Minimal surface card: radius 16, one border, no elevation.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(detoxRadius),
        border: Border.all(
          color: isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder,
        ),
        color: isDark ? DetoxColors.card : DetoxColors.lightCard,
      ),
      child: child,
    );
  }
}
