import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DetoxLogo extends StatelessWidget {
  const DetoxLogo({super.key, this.size = 56, this.showLabel = false});

  final double size;
  final bool showLabel;

  static const String _logoPath = 'assets/images/detox_logo.png';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final logo = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Image.asset(
          _logoPath,
          fit: BoxFit.cover,
          opacity: const AlwaysStoppedAnimation(0.92),
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: isDark ? DetoxColors.card : DetoxColors.lightCard,
              alignment: Alignment.center,
              child: Icon(
                Icons.shield_rounded,
                size: size * 0.5,
                color: isDark ? DetoxColors.accent : DetoxColors.accentDeep,
              ),
            );
          },
        ),
      ),
    );

    if (!showLabel) return logo;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logo,
        const SizedBox(height: 12),
        Text(
          'Detox',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 2),
        Text(
          'focus · block · control',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isDark ? DetoxColors.muted : DetoxColors.lightMuted,
              ),
        ),
      ],
    );
  }
}
