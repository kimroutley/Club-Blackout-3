import 'package:flutter/material.dart';

/// Shared animation timings and curves for consistent motion.
class ClubMotion {
  static const Duration micro = Duration(milliseconds: 180);
  static const Duration short = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration overlay = Duration(milliseconds: 1800);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeOutBack = Curves.easeOutBack;
}

class UiAnims {
  static Widget fadeIn(Widget child, {Duration duration = ClubMotion.short}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      builder: (_, v, __) => Opacity(opacity: v, child: child),
    );
  }
}
