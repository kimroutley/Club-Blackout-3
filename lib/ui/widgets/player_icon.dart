import 'package:flutter/material.dart';
import '../styles.dart';

class PlayerIcon extends StatelessWidget {
  final String assetPath;
  final Color glowColor;
  final double size;
  final bool isAlive;
  final bool isEnabled;
  final double glowIntensity;

  const PlayerIcon({
    super.key,
    required this.assetPath,
    required this.glowColor,
    this.size = 48,
    this.isAlive = true,
    this.isEnabled = true,
    this.glowIntensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.surface,
            border: Border.all(
              color: isEnabled
                  ? glowColor.withValues(alpha: 0.65)
                  : cs.onSurface.withValues(alpha: 0.1),
              width: size * 0.04 + 0.5, // Scale border with size
            ),
            boxShadow: isEnabled && isAlive
                ? [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.4 * glowIntensity),
                      blurRadius: size * 0.25,
                      spreadRadius: size * 0.02,
                    )
                  ]
                : null,
          ),
          child: ClipOval(
            child: Opacity(
              opacity: isEnabled ? 1.0 : 0.4,
              child: Image.asset(
                assetPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.person_rounded,
                  color: glowColor.withValues(alpha: 0.5),
                  size: size * 0.6,
                ),
              ),
            ),
          ),
        ),
        if (!isAlive)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surface.withValues(alpha: 0.65),
              ),
              child: Icon(
                Icons.close_rounded,
                color: ClubBlackoutTheme.neonRed,
                size: size * 0.5,
              ),
            ),
          ),
      ],
    );
  }
}
