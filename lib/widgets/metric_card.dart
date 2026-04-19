import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    this.icon,
    this.leading,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData? icon;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? DetoxColors.text : DetoxColors.lightText;
    final muted = isDark ? DetoxColors.muted : DetoxColors.lightMuted;

    final resolvedLeading = leading ?? Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: DetoxColors.accent.withOpacity(0.16),
        border: Border.all(
          color: isDark ? Colors.white12 : DetoxColors.lightCardBorder,
        ),
      ),
      child: Icon(icon ?? Icons.auto_graph_outlined, color: DetoxColors.accentSoft),
    );

    return GlassCard(
      child: Row(
        children: [
          resolvedLeading,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: muted),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, height: 1.18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
