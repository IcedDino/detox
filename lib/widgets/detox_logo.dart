import 'package:flutter/material.dart';

class DetoxLogo extends StatelessWidget {
  const DetoxLogo({super.key, this.size = 56, this.showLabel = false});

  final double size;
  final bool showLabel;

  static const String _logoPath = 'assets/images/Logo_detox.png';

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55256AF4),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Image.asset(
          _logoPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: const Color(0xFF081223),
              alignment: Alignment.center,
              child: Icon(
                Icons.shield_rounded,
                size: size * 0.5,
                color: const Color(0xFF7DDCFF),
              ),
            );
          },
        ),
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
              'focus · block · control',
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
