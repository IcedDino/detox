import 'package:flutter/material.dart';

class DetoxLogo extends StatelessWidget {
  const DetoxLogo({super.key, this.size = 56, this.showLabel = false});

  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D4ED8), Color(0xFF061226)],
        ),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66256AF4),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.62,
            height: size * 0.62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.22),
              border: Border.all(color: const Color(0x66FFFFFF), width: 1.6),
            ),
          ),
          Positioned(
            left: size * 0.2,
            top: size * 0.2,
            child: Container(
              width: size * 0.16,
              height: size * 0.16,
              decoration: const BoxDecoration(
                color: Color(0xFFAEE7FF),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Icon(
            Icons.shield_moon_rounded,
            size: size * 0.42,
            color: const Color(0xFF8ED1FF),
          ),
          Positioned(
            bottom: size * 0.18,
            right: size * 0.16,
            child: Container(
              padding: EdgeInsets.all(size * 0.05),
              decoration: BoxDecoration(
                color: const Color(0xFF0F2B57),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x664A90E2)),
              ),
              child: Icon(
                Icons.school_rounded,
                size: size * 0.16,
                color: const Color(0xFFAEE7FF),
              ),
            ),
          ),
        ],
      ),
    );

    if (!showLabel) return logo;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Detox',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
            ),
            Text(
              'shield · focus · study zones',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF8A9BB0),
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
