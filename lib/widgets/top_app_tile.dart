import 'package:flutter/material.dart';

import '../models/usage_models.dart';
import '../theme/app_theme.dart';
import 'app_icon_badge.dart';

class TopAppTile extends StatelessWidget {
  const TopAppTile({
    super.key,
    required this.entry,
    required this.index,
  });

  final AppUsageEntry entry;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? DetoxColors.muted : DetoxColors.lightMuted;
    final border = isDark ? Colors.white10 : DetoxColors.lightCardBorder;
    final background = isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFF);

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: background,
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AppIconBadge(
                  packageName: entry.packageName,
                  iconBytes: entry.iconBytes,
                  size: 42,
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: DetoxColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${entry.minutes} min today',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${entry.minutes}m',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
