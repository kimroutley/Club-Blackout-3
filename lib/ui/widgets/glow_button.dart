import 'package:flutter/material.dart';

import '../styles.dart';

class GlowButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color glowColor;
  final bool isPrimary;

  const GlowButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.glowColor,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;

    final bg = isPrimary
        ? glowColor.withValues(alpha: 0.95)
        : glowColor.withValues(alpha: 0.70);
    final fg = ClubBlackoutTheme.contrastOn(bg);

    return DecoratedBox(
      decoration: enabled
          ? ClubBlackoutTheme.neonFrame(
              color: glowColor,
              opacity: isPrimary ? 0.95 : 0.55,
              borderRadius: ClubBlackoutTheme.radiusMd,
              borderWidth: 2.0,
              showGlow: isPrimary,
            )
          : BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.10),
              borderRadius: ClubBlackoutTheme.borderRadiusMdAll,
            ),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: enabled ? bg : cs.onSurface.withValues(alpha: 0.10),
          foregroundColor: fg,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(ClubBlackoutTheme.controlHeight),
          shape: ClubBlackoutTheme.roundedShapeMd,
          padding: ClubBlackoutTheme.controlPadding,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith(
            (states) {
              if (states.contains(WidgetState.pressed)) {
                return fg.withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)) {
                return fg.withValues(alpha: 0.08);
              }
              return null;
            },
          ),
        ),
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}
