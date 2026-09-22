import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Page header with eyebrow, title, subtitle and a rounded icon.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [DetoxColors.accent, DetoxColors.accentSoft],
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: const TextStyle(
                  color: DetoxColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(color: DetoxColors.muted, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Section title with an optional subtitle.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(color: DetoxColors.muted, height: 1.3),
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

/// Small rounded status chip with an optional icon and semantic color.
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
    final effectiveColor = color ?? DetoxColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: effectiveColor.withOpacity(0.14),
        border: Border.all(color: effectiveColor.withOpacity(0.35)),
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
              style: TextStyle(
                color: effectiveColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero card with icon, title, subtitle, optional badge and body content.
class HeroInfoCard extends StatelessWidget {
  const HeroInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.action,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final StatusPill? badge;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: DetoxColors.accent.withOpacity(0.16),
                  border: Border.all(color: DetoxColors.accent.withOpacity(0.35)),
                ),
                child: Icon(icon, color: DetoxColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: DetoxColors.muted,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
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
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Compact stat tile: big value on top, label and helper text below.
class FriendlyStatTile extends StatelessWidget {
  const FriendlyStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? DetoxColors.accent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: effectiveColor.withOpacity(0.08),
        border: Border.all(color: effectiveColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: effectiveColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: DetoxColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            helper,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: DetoxColors.muted, fontSize: 11.5),
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
    final effectiveColor = color ?? DetoxColors.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.04)
                : Colors.white.withOpacity(0.7),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white10
                  : DetoxColors.lightCardBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: effectiveColor.withOpacity(0.14),
                ),
                child: Icon(icon, color: effectiveColor, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: DetoxColors.muted,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
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
