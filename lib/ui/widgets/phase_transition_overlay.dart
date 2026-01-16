import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/sound_service.dart';
import '../styles.dart';

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
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    // Play dramatic phase transition sound
    SoundService().playPhaseTransition();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);

    _glowAnimation = Tween<double>(begin: 0.0, end: 50.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 300), widget.onComplete);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    color: Colors.black.withOpacity(0.7 * _fadeAnimation.value),
                  ),
                ),
              ),

              // Phase announcement
              Center(
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: widget.phaseColor.withOpacity(_fadeAnimation.value),
                        width: 3,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.phaseColor.withOpacity(0.3 * _fadeAnimation.value),
                          Colors.black.withOpacity(0.9 * _fadeAnimation.value),
                          widget.phaseColor.withOpacity(0.3 * _fadeAnimation.value),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.phaseColor.withOpacity(0.6 * _fadeAnimation.value),
                          blurRadius: _glowAnimation.value,
                          spreadRadius: _glowAnimation.value * 0.3,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.phaseColor.withOpacity(0.2),
                            border: Border.all(
                              color: widget.phaseColor,
                              width: 3,
                            ),
                            boxShadow: ClubBlackoutTheme.circleGlow(
                              widget.phaseColor,
                              intensity: 1.0 + (_fadeAnimation.value * 0.6),
                            ),
                          ),
                          child: Icon(
                            widget.phaseIcon,
                            size: 64,
                            color: widget.phaseColor,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          widget.phaseName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Hyperwave',
                            color: widget.phaseColor,
                            letterSpacing: 4,
                            shadows: ClubBlackoutTheme.textGlow(widget.phaseColor, intensity: 2.0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Particles effect
              ...List.generate(20, (index) {
                final random = (index * 47) % 100 / 100;
                final xPos = random;
                final delay = random * 0.5;
                final particleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _controller,
                    curve: Interval(delay, 1.0, curve: Curves.easeOut),
                  ),
                );
                
                return Positioned(
                  left: MediaQuery.of(context).size.width * xPos,
                  top: -50 + (MediaQuery.of(context).size.height * particleAnim.value),
                  child: Opacity(
                    opacity: (1 - particleAnim.value) * _fadeAnimation.value,
                    child: Container(
                      width: 4 + (index % 3) * 2,
                      height: 4 + (index % 3) * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.phaseColor,
                        boxShadow: [
                          BoxShadow(
                            color: widget.phaseColor,
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
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
  final overlay = OverlayEntry(
    builder: (context) => PhaseTransitionOverlay(
      phaseName: phaseName,
      phaseColor: phaseColor,
      phaseIcon: phaseIcon,
      onComplete: () {
        onComplete?.call();
      },
    ),
  );

  Overlay.of(context).insert(overlay);
  
  Future.delayed(const Duration(milliseconds: 1800), () {
    overlay.remove();
  });
}
