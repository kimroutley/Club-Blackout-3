import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// App-wide scroll behavior tuned for Material 3.
///
/// - Android: clamping physics (no iOS-style bounce)
/// - iOS/macOS: bouncing physics
/// - No scrollbars (keeps the neon aesthetic clean)
class ClubBlackoutScrollBehavior extends MaterialScrollBehavior {
  const ClubBlackoutScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics();
      default:
        return const ClampingScrollPhysics();
    }
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
