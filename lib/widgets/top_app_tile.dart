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
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(0.04),
          border: Border.all(color: Colors.white10),
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
                      border: Border.all(color: DetoxColors.surface, width: 2),
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
                    style: const TextStyle(color: DetoxColors.muted),
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
