import 'package:flutter/material.dart';

class DetoxColors {
  static const Color bg = Color(0xFF08111F);
  static const Color bgAlt = Color(0xFF0F1C30);
  static const Color card = Color(0xFF15253C);
  static const Color surface = Color(0xFF15253C);
  static const Color cardBorder = Color(0x26FFFFFF);
  static const Color accent = Color(0xFF2D71F6);
  static const Color accentSoft = Color(0xFF66B8FF);
  static const Color success = Color(0xFF31D0AA);
  static const Color warning = Color(0xFFFFB84D);
  static const Color danger = Color(0xFFFF6B7A);
  static const Color text = Colors.white;
  static const Color muted = Color(0xFF96A8C0);

  static const Color lightBg = Color(0xFFF4F7FF);
  static const Color lightBgAlt = Color(0xFFE8F0FF);
  static const Color lightCard = Colors.white;
  static const Color lightSurface = Colors.white;
  static const Color lightCardBorder = Color(0x140C2242);
  static const Color lightText = Color(0xFF13233C);
  static const Color lightMuted = Color(0xFF67778E);
}

class DetoxTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: DetoxColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: DetoxColors.accent,
        secondary: DetoxColors.accentSoft,
        surface: DetoxColors.card,
        onSurface: DetoxColors.text,
      ),
      textTheme: base.textTheme.apply(
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
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(color: DetoxColors.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        behavior: SnackBarBehavior.floating,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DetoxColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: DetoxColors.text,
          side: const BorderSide(color: DetoxColors.cardBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: DetoxColors.accent,
        foregroundColor: Colors.white,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: DetoxColors.card.withOpacity(0.92),
        side: const BorderSide(color: DetoxColors.cardBorder),
        selectedColor: DetoxColors.accent.withOpacity(0.22),
        labelStyle: const TextStyle(color: DetoxColors.text),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DetoxColors.card.withOpacity(0.92),
        labelStyle: const TextStyle(color: DetoxColors.muted),
        hintStyle: const TextStyle(color: DetoxColors.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: DetoxColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: DetoxColors.accentSoft),
        ),
      ),
      dividerColor: Colors.white10,
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: DetoxColors.card.withOpacity(0.96),
        indicatorColor: DetoxColors.accent.withOpacity(0.22),
        shadowColor: Colors.transparent,
        labelTextStyle: MaterialStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(MaterialState.selected) ? DetoxColors.text : DetoxColors.muted,
            fontWeight: states.contains(MaterialState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        iconTheme: MaterialStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(MaterialState.selected) ? DetoxColors.accentSoft : DetoxColors.muted,
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: DetoxColors.accent,
        linearTrackColor: Color(0x332D71F6),
        circularTrackColor: Color(0x332D71F6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) => Colors.white),
        trackColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.selected)
              ? DetoxColors.accent.withOpacity(0.6)
              : Colors.white24,
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: DetoxColors.accent,
        thumbColor: DetoxColors.accentSoft,
        inactiveTrackColor: Colors.white12,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.selected) ? DetoxColors.accent : Colors.transparent,
        ),
        side: const BorderSide(color: DetoxColors.cardBorder),
      ),
    );
  }

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: DetoxColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: DetoxColors.accent,
        secondary: DetoxColors.accentSoft,
        surface: DetoxColors.lightSurface,
        onSurface: DetoxColors.lightText,
      ),
      textTheme: base.textTheme.apply(
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
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(color: DetoxColors.lightText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        behavior: SnackBarBehavior.floating,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DetoxColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: DetoxColors.lightText,
          side: const BorderSide(color: DetoxColors.lightCardBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: DetoxColors.accent,
        foregroundColor: Colors.white,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0xFFF1F5FF),
        side: const BorderSide(color: DetoxColors.lightCardBorder),
        selectedColor: DetoxColors.accent.withOpacity(0.14),
        labelStyle: const TextStyle(color: DetoxColors.lightText),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        labelStyle: const TextStyle(color: DetoxColors.lightMuted),
        hintStyle: const TextStyle(color: DetoxColors.lightMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: DetoxColors.lightCardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: DetoxColors.accentSoft),
        ),
      ),
      dividerColor: const Color(0x140C2242),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: DetoxColors.lightCard.withOpacity(0.98),
        indicatorColor: DetoxColors.accent.withOpacity(0.14),
        labelTextStyle: MaterialStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(MaterialState.selected) ? DetoxColors.lightText : DetoxColors.lightMuted,
            fontWeight: states.contains(MaterialState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        iconTheme: MaterialStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(MaterialState.selected) ? DetoxColors.accent : DetoxColors.lightMuted,
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: DetoxColors.accent,
        linearTrackColor: Color(0x222D71F6),
        circularTrackColor: Color(0x222D71F6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) => Colors.white),
        trackColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.selected)
              ? DetoxColors.accent.withOpacity(0.6)
              : const Color(0x220C2242),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: DetoxColors.accent,
        thumbColor: DetoxColors.accentSoft,
        inactiveTrackColor: Color(0x220C2242),
      ),
    );
  }
}

class DetoxBackground extends StatelessWidget {
  const DetoxBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgStart = isDark ? DetoxColors.bgAlt : DetoxColors.lightBgAlt;
    final bgEnd = isDark ? DetoxColors.bg : DetoxColors.lightBg;
    final glowColor = DetoxColors.accent.withOpacity(isDark ? 0.22 : 0.14);
    final glowSoft = DetoxColors.accentSoft.withOpacity(isDark ? 0.14 : 0.10);

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bgStart, bgEnd],
              ),
            ),
          ),
        ),
        Positioned(
          top: -80,
          left: -70,
          child: _GlowBlob(size: MediaQuery.of(context).size.width * 0.72, color: glowColor),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.28,
          right: -50,
          child: _GlowBlob(size: 180, color: glowSoft),
        ),
        Positioned(
          bottom: 100,
          right: -90,
          child: _GlowBlob(size: 260, color: glowColor),
        ),
        child,
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.82),
              blurRadius: 80,
              spreadRadius: 22,
            ),
          ],
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    DetoxColors.card.withOpacity(0.92),
                    const Color(0xFF132136).withOpacity(0.88),
                  ]
                : [
                    Colors.white.withOpacity(0.96),
                    const Color(0xFFF6F9FF).withOpacity(0.96),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.18) : const Color(0x140C2242),
              blurRadius: 26,
              spreadRadius: 0,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
