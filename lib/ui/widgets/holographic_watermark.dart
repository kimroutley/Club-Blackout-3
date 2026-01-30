import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../styles.dart';

class HolographicWatermark extends StatefulWidget {
  final Color color;

  /// Master switch for expensive animation + sensor-driven effects.
  ///
  /// When false, the widget renders a static, lightweight watermark.
  final bool enabled;

  /// Text used in the repeating pattern.
  ///
  /// Defaults to the brand watermark used across the app.
  final String text;

  /// If true, uses the gyroscope to add subtle parallax.
  ///
  /// Disable this for deterministic, low-noise visuals (e.g., cards in dialogs).
  final bool enableGyro;

  /// If true, pauses shimmer/gyro-driven updates while a scrollable ancestor
  /// is actively scrolling. This reduces jank during list/page scrolling.
  final bool pauseWhileScrolling;

  const HolographicWatermark({
    super.key,
    required this.color,
    this.enabled = true,
    this.text = 'CLUB BLACKOUT',
    this.enableGyro = true,
    this.pauseWhileScrolling = true,
  });

  @override
  State<HolographicWatermark> createState() => _HolographicWatermarkState();
}

class _HolographicWatermarkState extends State<HolographicWatermark>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  // OPTIMIZATION: Use ValueNotifiers for gyro data to avoid full widget rebuilds
  final ValueNotifier<Offset> _gyroOffset = ValueNotifier(Offset.zero);
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  bool _gyroAvailable = false;

  final ValueNotifier<bool> _isScrolling = ValueNotifier(false);
  Timer? _scrollDebounce;

  // Cache the expensive text pattern widget
  late Widget _cachedPatternLayer;
  late Widget _cachedGhostLayer;

  @override
  void initState() {
    super.initState();

    // 1. Shimmer loop (visual flair)
    _shimmerController =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat();

    // 2. Pre-build the heavy text patterns
    // By building these once and reusing them, we save massive layout costs
    _cachedPatternLayer = RepaintBoundary(
      child: _buildPattern(
        widget.color.withValues(alpha: 0.02),
        isHologram: true,
      ),
    );

    _cachedGhostLayer = RepaintBoundary(
      child: _buildPattern(
        ClubBlackoutTheme.pureWhite.withValues(alpha: 0.010),
        isHologram: true,
      ),
    );

    if (!widget.enabled) {
      _shimmerController.stop();
    }

    if (widget.enabled && widget.enableGyro) {
      _startListening();
    }
  }

  @override
  void didUpdateWidget(covariant HolographicWatermark oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Enable/disable expensive effects without reconstructing the widget.
    if (oldWidget.enabled != widget.enabled) {
      if (!widget.enabled) {
        if (_shimmerController.isAnimating) {
          _shimmerController.stop();
        }
        _gyroSubscription?.cancel();
        _gyroSubscription = null;
        _gyroOffset.value = Offset.zero;
      } else {
        if (!_isScrolling.value && !_shimmerController.isAnimating) {
          _shimmerController.repeat();
        }
        if (widget.enableGyro && _gyroSubscription == null) {
          _startListening();
        }
      }
    }

    // If gyro is toggled while enabled, start/stop listening.
    if (widget.enabled && oldWidget.enableGyro != widget.enableGyro) {
      if (widget.enableGyro) {
        if (_gyroSubscription == null) {
          _startListening();
        }
      } else {
        _gyroSubscription?.cancel();
        _gyroSubscription = null;
        _gyroOffset.value = Offset.zero;
      }
    }
  }

  void _startListening() {
    // 3. Listen to sensors but DO NOT setState
    // Instead, update the ValueNotifier.
    // This allows us to target ONLY the Transform widget for updates.
    try {
      _gyroAvailable = true;

      _gyroSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
        if (!mounted) return;

        // Avoid updating the notifier (and therefore rebuilding transforms)
        // while the UI is actively scrolling.
        if (widget.pauseWhileScrolling && _isScrolling.value) return;

        // Smoothing / Damping
        // We take the current offset and move it towards the target
        const double sensitivity = 4.0;
        final double targetX = event.y * sensitivity;
        final double targetY = event.x * sensitivity;

        // Update the notifier directly.
        // Note: For ultra-smoothness we could use a temporary variable and
        // interpolate in a Ticker, but ValueNotifier is cheap enough here compared to setState
        _gyroOffset.value = Offset(targetX, targetY);
      }, onError: (_) {
        _gyroAvailable = false;
        _gyroOffset.value = Offset.zero;
      });
    } catch (_) {
      // In widget tests / unsupported platforms, the sensor stream may be unavailable.
      _gyroAvailable = false;
      _gyroOffset.value = Offset.zero;
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _gyroSubscription?.cancel();
    _gyroOffset.dispose();
    _scrollDebounce?.cancel();
    _isScrolling.dispose();
    super.dispose();
  }

  Color _shiftHue(Color color, double degrees) {
    final hsv = HSVColor.fromColor(color);
    final h = (hsv.hue + degrees) % 360;
    return hsv.withHue(h < 0 ? h + 360 : h).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final holoA = _shiftHue(widget.color, -18).withValues(alpha: 0.045);
    final holoB = _shiftHue(widget.color, 12).withValues(alpha: 0.040);
    final holoC = _shiftHue(widget.color, 35).withValues(alpha: 0.035);

    // Lightweight, static render (no shimmer, no gyro transforms, no scroll listeners).
    if (!widget.enabled) {
      return ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            OverflowBox(
              maxWidth: 800,
              maxHeight: 800,
              child: Transform.rotate(
                angle: -0.3,
                child: Stack(
                  children: [
                    Opacity(
                      opacity: 0.020,
                      child: _cachedPatternLayer,
                    ),
                    Opacity(
                      opacity: 0.014,
                      child: _cachedGhostLayer,
                    ),
                    // Keep a faint, non-animated tint so the card still reads "holo".
                    IgnorePointer(
                      child: Opacity(
                        opacity: 0.020,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.transparent,
                                holoA,
                                holoB,
                                holoC,
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.35, 0.55, 0.75, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (!widget.pauseWhileScrolling) return false;

        if (notification is ScrollStartNotification ||
            notification is ScrollUpdateNotification) {
          if (!_isScrolling.value) _isScrolling.value = true;
          _scrollDebounce?.cancel();
          _scrollDebounce = Timer(const Duration(milliseconds: 140), () {
            if (!mounted) return;
            _isScrolling.value = false;
          });
        } else if (notification is ScrollEndNotification) {
          _scrollDebounce?.cancel();
          _isScrolling.value = false;
        }

        return false;
      },
      child: ClipRect(
        child: ValueListenableBuilder<bool>(
          valueListenable: _isScrolling,
          builder: (context, isScrolling, _) {
            if (widget.pauseWhileScrolling) {
              if (isScrolling) {
                if (_shimmerController.isAnimating) {
                  _shimmerController.stop();
                }
              } else {
                if (!_shimmerController.isAnimating) {
                  _shimmerController.repeat();
                }
              }
            }

            return Stack(
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
                        final effectiveOffset =
                            (widget.enableGyro && !isScrolling)
                                ? offset
                                : Offset.zero;

                        // Almost invisible until motion is detected.
                        // We map motion magnitude to a subtle intensity curve.
                        final motion = (widget.enableGyro &&
                                !isScrolling &&
                                _gyroAvailable)
                            ? effectiveOffset.distance
                            : 0.0;
                        final t = (motion / 6.0).clamp(0.0, 1.0);
                        final intensity = Curves.easeOutCubic.transform(t);

                        const double baseOpacity = 0.006;
                        final activeBoost = widget.enableGyro ? 0.14 : 0.0;
                        final patternOpacity =
                            (baseOpacity + intensity * activeBoost)
                                .clamp(0.0, 0.22);

                        final shimmerOpacity =
                            (0.004 + intensity * 0.10).clamp(0.0, 0.16);

                        // This builder ONLY rebuilds the transforms,
                        // NOT the text widgets inside _cachedPatternLayer
                        return Stack(
                          children: [
                            // Layer 1: Main Tinted Hologram (Moves with Gyro)
                            Transform.translate(
                              offset: effectiveOffset,
                              child: Opacity(
                                opacity: patternOpacity,
                                child: _cachedPatternLayer,
                              ),
                            ),

                            // Layer 2: Ghost (Moves Opposite)
                            Transform.translate(
                              offset: -effectiveOffset,
                              child: Opacity(
                                opacity:
                                    (patternOpacity * 0.75).clamp(0.0, 0.18),
                                child: _cachedGhostLayer,
                              ),
                            ),

                            // Shimmer is applied here so it can also be intensity-scaled.
                            if (!isScrolling)
                              IgnorePointer(
                                child: AnimatedBuilder(
                                  animation: _shimmerController,
                                  builder: (context, child) {
                                    return Opacity(
                                      opacity: shimmerOpacity,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.transparent,
                                              holoA,
                                              holoB,
                                              holoC,
                                              Colors.transparent,
                                            ],
                                            stops: const [
                                              0.0,
                                              0.35,
                                              0.55,
                                              0.75,
                                              1.0
                                            ],
                                            transform: GradientRotation(
                                              _shimmerController.value * 6.28,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPattern(Color color, {bool isHologram = false}) {
    // Create a repeating text block
    // Brand pattern repeated.
    final String rowText =
        '${widget.text}     ${widget.text}     ${widget.text}     ${widget.text}';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(15, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            // Offset every other line for brick pattern
            index.isEven ? rowText : '      $rowText',
            style: TextStyle(
              fontFamily: ClubBlackoutTheme.neonGlowFontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 3.0,
              // If it's the hologram layer, maybe add blur?
              shadows: isHologram
                  ? [
                      Shadow(
                        blurRadius: 4.0,
                        color: color.withValues(alpha: 0.5),
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
