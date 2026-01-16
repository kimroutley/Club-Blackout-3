import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../logic/game_engine.dart';
import '../styles.dart';
class HomeScreen extends StatefulWidget {
  final GameEngine gameEngine;
  final VoidCallback onNavigateToLobby;
  final VoidCallback onNavigateToGuides;

  const HomeScreen({
    super.key, 
    required this.gameEngine, 
    required this.onNavigateToLobby,
    required this.onNavigateToGuides,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Fade in animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    
    // Pulse animation for primary button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
        fit: StackFit.expand,
        children: [
          // Background Image with parallax effect
          /*Image.asset(
            "Backgrounds/Club Blackout Home Menu Screen.png",
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black,
                    const Color(0xFF0D0221),
                    const Color(0xFF000000),
                  ],
                ),
              ),
            ),
          ),*/
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black,
                  const Color(0xFF0D0221),
                  const Color(0xFF000000),
                ],
              ),
            ),
          ),
          
          // Animated gradient overlay
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.6 + _pulseAnimation.value * 0.1),
                      Colors.black.withOpacity(0.9),
                    ],
                    stops: const [0.3, 0.5, 0.7, 1.0],
                  ),
                ),
              );
            },
          ),

          // Menu Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ClubBlackoutTheme.centeredConstrained(
                maxWidth: 520,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    // Primary button with pulse animation
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: child,
                        );
                      },
                      child: _buildMenuButton(
                        context,
                        "Start Game",
                        ClubBlackoutTheme.neonBlue,
                        widget.onNavigateToLobby,
                        isPrimary: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildMenuButton(
                      context,
                      "Guides",
                      ClubBlackoutTheme.neonPurple,
                      widget.onNavigateToGuides,
                    ),
                    const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
  }


  Widget _buildMenuButton(
    BuildContext context,
    String label,
    Color color,
    VoidCallback onPressed, {
    bool isPrimary = false,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (isPrimary ? 0 : 200)),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            height: isPrimary ? 72 : 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: ClubBlackoutTheme.boxGlow(color, intensity: isPrimary ? 1.2 : 0.8),
            ),
            child: child,
          ),
        );
      },
      child: FilledButton(
        onPressed: () {
          if (isPrimary) {
            HapticFeedback.mediumImpact();
          } else {
            HapticFeedback.lightImpact();
          }
          onPressed();
        },
        style: ClubBlackoutTheme.neonButtonStyle(color, isPrimary: isPrimary),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            // Use default app font for main menu buttons
            fontFamily: null,
            shadows: ClubBlackoutTheme.textGlow(color, intensity: 0.8),
          ),
        ),
      ),
    );
  }
}



