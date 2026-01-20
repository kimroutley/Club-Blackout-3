import 'package:flutter/animation.dart';

/// Shared animation timings and curves for consistent motion.
class ClubMotion {
  static const Duration micro = Duration(milliseconds: 180);
  static const Duration quick = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 260);
  static const Duration short = Duration(milliseconds: 300);
  static const Duration page = Duration(milliseconds: 320);
  static const Duration overlay = Duration(milliseconds: 1200);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
  static const Curve easeOutBack = Curves.easeOutBack;
  static const Curve easeIn = Curves.easeIn;
}
