import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The Detox "Umbral" symbol.
///
/// The artwork is a filled mark, not a picture inside a frame, so it is drawn
/// at its own colour for the current theme: sage on dark surfaces, deep green
/// on light ones. There is no container, border or opacity, because the
/// silhouette already carries its own corner and its own contrast.
class DetoxLogo extends StatelessWidget {
  const DetoxLogo({super.key, this.size = 56, this.showLabel = false});

  final double size;
  final bool showLabel;

  static const String _darkAsset = 'assets/images/detox_symbolo_oscuro.png';
  static const String _lightAsset = 'assets/images/detox_symbolo_claro.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final symbol = Image.asset(
      isDark ? _darkAsset : _lightAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      // The mark is vector artwork exported at 512 px. High quality keeps the
      // rounded corners and the door edge clean at every size.
      filterQuality: FilterQuality.high,
      semanticLabel: 'Detox',
      errorBuilder: (context, error, stackTrace) => SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.shield_rounded,
          size: size * 0.56,
          color: isDark ? DetoxColors.accent : DetoxColors.accentDeep,
        ),
      ),
    );

    if (!showLabel) return symbol;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        symbol,
        const SizedBox(height: 12),
        Text('Detox', style: theme.textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(
          'focus · block · control',
          style: theme.textTheme.labelSmall?.copyWith(
                color: isDark ? DetoxColors.muted : DetoxColors.lightMuted,
              ),
        ),
      ],
    );
  }
}
