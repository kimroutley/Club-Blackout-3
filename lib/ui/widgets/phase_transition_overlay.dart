import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/sound_service.dart';
import '../animations.dart';

class PhaseTransitionOverlay extends StatefulWidget {
  final String phaseName;
  final Color phaseColor;
  final IconData phaseIcon;
  final VoidCallback onComplete;

  const PhaseTransitionOverlay({
    super.key,
    required this.phaseName,
    required this.phaseColor,
    required this.phaseIcon,
    required this.onComplete,
  });

  @override
  State<PhaseTransitionOverlay> createState() => _PhaseTransitionOverlayState();
}

class _PhaseTransitionOverlayState extends State<PhaseTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Play dramatic phase transition sound
    SoundService().playPhaseTransition();

    _controller = AnimationController(
      duration: ClubMotion.overlay,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: ClubMotion.easeOutBack),
      ),
    );

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_controller);

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Stack(
            children: [
              // Backdrop blur
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 10 * _fadeAnimation.value,
                    sigmaY: 10 * _fadeAnimation.value,
                  ),
                  child: Container(
                    color: cs.scrim
                        .withValues(alpha: 0.7 * _fadeAnimation.value),
                  ),
                ),
              ),

              // Phase announcement
              Center(
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Card(
                    elevation: 12,
                    color: cs.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                      side: BorderSide(
                        color: cs.outlineVariant
                            .withValues(alpha: 0.55 * _fadeAnimation.value),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor:
                                widget.phaseColor.withValues(alpha: 0.18),
                            child: Icon(
                              widget.phaseIcon,
                              size: 54,
                              color: widget.phaseColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.phaseName,
                            textAlign: TextAlign.center,
                            style: (textTheme.headlineMedium ??
                                    const TextStyle(fontSize: 28))
                                .copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Helper function to show phase transition
void showPhaseTransition(
  BuildContext context, {
  required String phaseName,
  required Color phaseColor,
  required IconData phaseIcon,
  VoidCallback? onComplete,
}) {
  bool removed = false;
  void removeOnce(OverlayEntry entry) {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  late final OverlayEntry overlay;
  overlay = OverlayEntry(
    builder: (context) => PhaseTransitionOverlay(
      phaseName: phaseName,
      phaseColor: phaseColor,
      phaseIcon: phaseIcon,
      onComplete: () {
        removeOnce(overlay);
        onComplete?.call();
      },
    ),
  );

  Overlay.of(context).insert(overlay);

  // Fallback cleanup in case the overlay is still mounted (e.g. route change).
  Future.delayed(const Duration(milliseconds: 2200), () {
    if (!removed) {
      removeOnce(overlay);
    }
  });
}
