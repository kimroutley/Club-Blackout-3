import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class HolographicWatermark extends StatefulWidget {
  final Color color;

  const HolographicWatermark({super.key, required this.color});

  @override
  State<HolographicWatermark> createState() => _HolographicWatermarkState();
}

class _HolographicWatermarkState extends State<HolographicWatermark>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  // OPTIMIZATION: Use ValueNotifiers for gyro data to avoid full widget rebuilds
  final ValueNotifier<Offset> _gyroOffset = ValueNotifier(Offset.zero);
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  // Cache the expensive text pattern widget
  late Widget _cachedPatternLayer;
  late Widget _cachedGhostLayer;

  @override
  void initState() {
    super.initState();

    // 1. Shimmer loop (visual flair)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // 2. Pre-build the heavy text patterns
    // By building these once and reusing them, we save massive layout costs
    _cachedPatternLayer = RepaintBoundary(
      child: _buildPattern(
        widget.color.withOpacity(0.04), // Softer tint for better legibility
        isHologram: true,
      ),
    );

    _cachedGhostLayer = RepaintBoundary(
      child: _buildPattern(Colors.white.withOpacity(0.015), isHologram: true),
    );

    _startListening();
  }

  void _startListening() {
    // 3. Listen to sensors but DO NOT setState
    // Instead, update the ValueNotifier.
    // This allows us to target ONLY the Transform widget for updates.
    _gyroSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      if (!mounted) return;

      // Smoothing / Damping
      // We take the current offset and move it towards the target
      final double sensitivity = 4.0;
      final double targetX = event.y * sensitivity;
      final double targetY = event.x * sensitivity;

      // Update the notifier directly.
      // Note: For ultra-smoothness we could use a temporary variable and
      // interpolate in a Ticker, but ValueNotifier is cheap enough here compared to setState
      _gyroOffset.value = Offset(targetX, targetY);
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _gyroSubscription?.cancel();
    _gyroOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The base layer - Static or very slow moving
          // We put the heavy text stuff in an OverflowBox so we can rotate it
          OverflowBox(
            maxWidth: 800,
            maxHeight: 800,
            child: Transform.rotate(
              angle: -0.3,
              child: ValueListenableBuilder<Offset>(
                valueListenable: _gyroOffset,
                builder: (context, offset, child) {
                  // This builder ONLY rebuilds the transforms,
                  // NOT the text widgets inside _cachedPatternLayer
                  return Stack(
                    children: [
                      // Layer 1: Main Tinted Hologram (Moves with Gyro)
                      // We use TweenAnimationBuilder for extra smoothing if raw gyro is jittery,
                      // but raw Stream update to ValueNotifier is usually responsive enough.
                      Transform.translate(
                        offset: offset,
                        child: _cachedPatternLayer,
                      ),

                      // Layer 2: Ghost (Moves Opposite)
                      Transform.translate(
                        offset: -offset,
                        child: _cachedGhostLayer,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Gradient Shimmer Overlay (Deterministic animation)
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.transparent,
                      widget.color.withOpacity(0.03),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                    transform: GradientRotation(
                      _shimmerController.value * 6.28,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPattern(Color color, {bool isHologram = false}) {
    // Create a repeating text block
    // "CLUB BLACKOUT" repeated
    const String rowText =
        "CLUB BLACKOUT      CLUB BLACKOUT      CLUB BLACKOUT      CLUB BLACKOUT";

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(15, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            // Offset every other line for brick pattern
            index.isEven ? rowText : "      $rowText",
            style: TextStyle(
              fontFamily:
                  'Hyperwave', // Use the branding font if suitable, or standard blocky
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 4.0,
              // If it's the hologram layer, maybe add blur?
              shadows: isHologram
                  ? [
                      Shadow(
                        blurRadius: 4.0,
                        color: color.withOpacity(0.5),
                        offset: const Offset(0, 0),
                      ),
                    ]
                  : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
          ),
        );
      }),
    );
  }
}
