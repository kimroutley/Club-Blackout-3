import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/sound_service.dart';
import '../styles.dart';

/// Shows a dramatic victory announcement with confetti
void showVictoryAnnouncement(
  BuildContext context,
  String winningTeam,
  List<String> winners, {
  VoidCallback? onComplete,
}) {
  SoundService().playVictory();
  
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    builder: (context) => VictoryAnnouncementDialog(
      winningTeam: winningTeam,
      winners: winners,
      onComplete: onComplete,
    ),
  );
}

class VictoryAnnouncementDialog extends StatefulWidget {
  final String winningTeam;
  final List<String> winners;
  final VoidCallback? onComplete;

  const VictoryAnnouncementDialog({
    super.key,
    required this.winningTeam,
    required this.winners,
    this.onComplete,
  });

  @override
  State<VictoryAnnouncementDialog> createState() => _VictoryAnnouncementDialogState();
}

class _VictoryAnnouncementDialogState extends State<VictoryAnnouncementDialog>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _confettiController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final List<ConfettiParticle> _confetti = [];

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _confettiController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );

    // Generate confetti particles
    final random = math.Random();
    for (int i = 0; i < 50; i++) {
      _confetti.add(ConfettiParticle(
        x: random.nextDouble(),
        y: -0.1 - (random.nextDouble() * 0.3),
        rotation: random.nextDouble() * math.pi * 2,
        color: _getRandomColor(random),
        size: 8 + random.nextDouble() * 12,
      ));
    }

    // Start animations
    _fadeController.forward();
    _scaleController.forward();
    _confettiController.repeat();
  }

  Color _getRandomColor(math.Random random) {
    final colors = [
      ClubBlackoutTheme.neonOrange,
      ClubBlackoutTheme.crimsonRed,
      ClubBlackoutTheme.electricBlue,
      ClubBlackoutTheme.neonPurple,
      Colors.yellow,
      Colors.pink,
    ];
    return colors[random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).pop();
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          // Confetti background
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, child) {
              return CustomPaint(
                size: size,
                painter: ConfettiPainter(
                  particles: _confetti,
                  progress: _confettiController.value,
                ),
              );
            },
          ),
          
          // Main content
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: ClubBlackoutTheme.neonOrange,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ClubBlackoutTheme.neonOrange.withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Trophy icon
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: ClubBlackoutTheme.neonOrange.withOpacity(0.2),
                              border: Border.all(
                                color: ClubBlackoutTheme.neonOrange,
                                width: 3,
                              ),
                              boxShadow: ClubBlackoutTheme.circleGlow(
                                ClubBlackoutTheme.neonOrange,
                                intensity: 1.2,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                '🏆',
                                style: TextStyle(fontSize: 50),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // "VICTORY" text
                          Text(
                            'VICTORY!',
                            style: ClubBlackoutTheme.primaryFont.copyWith(
                              fontSize: 42,
                              color: ClubBlackoutTheme.neonOrange,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Winning team
                          Text(
                            widget.winningTeam.toUpperCase(),
                            style: ClubBlackoutTheme.primaryFont.copyWith(
                              fontSize: 28,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 24),

                          // Winners list
                          if (widget.winners.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1a1a2e),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: ClubBlackoutTheme.neonOrange.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'WINNERS',
                                    style: ClubBlackoutTheme.primaryFont.copyWith(
                                      fontSize: 16,
                                      color: ClubBlackoutTheme.neonOrange,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...widget.winners.map((name) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      name,
                                      style: ClubBlackoutTheme.primaryFont.copyWith(
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  )),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Celebration message
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ClubBlackoutTheme.neonOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: ClubBlackoutTheme.neonOrange.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              'Game Over - Well Played!',
                              style: ClubBlackoutTheme.primaryFont.copyWith(
                                fontSize: 14,
                                color: ClubBlackoutTheme.neonOrange,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Close button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _close,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ClubBlackoutTheme.neonOrange,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'FINISH',
                                style: ClubBlackoutTheme.primaryFont.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ConfettiParticle {
  final double x;
  final double y;
  final double rotation;
  final Color color;
  final double size;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.rotation,
    required this.color,
    required this.size,
  });
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double progress;

  ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final paint = Paint()
        ..color = particle.color
        ..style = PaintingStyle.fill;

      final x = particle.x * size.width;
      final y = particle.y * size.height + (progress * size.height * 1.2);
      
      if (y > size.height) continue;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.rotation + (progress * math.pi * 4));
      
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: particle.size,
        height: particle.size / 2,
      );
      canvas.drawRect(rect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) => true;
}
