import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Page header: eyebrow + title + subtitle, left aligned, no icon container.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.icon,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: DetoxColors.accent,
                letterSpacing: 1.2,
              ),
        ),
        const SizedBox(height: 6),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? DetoxColors.muted
                    : DetoxColors.lightMuted,
              ),
        ),
      ],
    );
  }
}

/// Section title with an optional subtitle and optional trailing widget.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? DetoxColors.muted
        : DetoxColors.lightMuted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

/// Semantic status chip. Reserve it for live states (session active, shield
/// active, sponsor pending) — never for decoration.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
  });

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color ??
        (isDark ? DetoxColors.accent : DetoxColors.accent);
    final muted = isDark ? DetoxColors.muted : DetoxColors.lightMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(detoxRadius),
        color: effectiveColor.withOpacity(0.12),
        border: Border.all(color: effectiveColor.withOpacity(0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: effectiveColor),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: effectiveColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          // Muted color referenced for neutral pills.
          if (effectiveColor == muted) const SizedBox.shrink(),
        ],
      ),
    );
  }
}

/// Hero card: title + subtitle + optional semantic badge + body.
/// No icon container, no stacked decoration — content carries the hierarchy.
class HeroInfoCard extends StatelessWidget {
  const HeroInfoCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.badge,
    this.action,
    this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final StatusPill? badge;
  final Widget? action;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? DetoxColors.muted
        : DetoxColors.lightMuted;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                badge!,
              ],
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: action!),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Compact stat tile: value, label, optional helper. Border-minimal.
class FriendlyStatTile extends StatelessWidget {
  const FriendlyStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.helper,
    this.icon,
    this.color,
  });

  final String label;
  final String value;
  final String helper;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? DetoxColors.muted
        : DetoxColors.lightMuted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(detoxRadius),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? DetoxColors.cardBorder
              : DetoxColors.lightCardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: color ?? muted),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 2),
          Text(
            helper,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

/// Tappable list tile with a soft icon, title, subtitle and optional trailing.
class SoftActionTile extends StatelessWidget {
  const SoftActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? DetoxColors.muted : DetoxColors.lightMuted;
    final effectiveColor = color ?? (isDark ? DetoxColors.accent : DetoxColors.accent);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(detoxRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(detoxRadius),
            border: Border.all(
              color: isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: effectiveColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
