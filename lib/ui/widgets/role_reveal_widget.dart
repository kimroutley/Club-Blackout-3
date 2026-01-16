import 'package:flutter/material.dart';
import '../../models/role.dart';
import '../../services/sound_service.dart';
import '../styles.dart';
import 'role_card_widget.dart';

/// Displays a dramatic role reveal with animations
void showRoleReveal(
  BuildContext context,
  Role role,
  String playerName, {
  String? subtitle,
  VoidCallback? onComplete,
}) {
  SoundService().playRoleReveal();
  
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    builder: (context) => RoleRevealDialog(
      role: role,
      playerName: playerName,
      subtitle: subtitle,
      onComplete: onComplete,
    ),
  );
}

class RoleRevealDialog extends StatefulWidget {
  final Role role;
  final String playerName;
  final String? subtitle;
  final VoidCallback? onComplete;

  const RoleRevealDialog({
    super.key,
    required this.role,
    required this.playerName,
    this.subtitle,
    this.onComplete,
  });

  @override
  State<RoleRevealDialog> createState() => _RoleRevealDialogState();
}

class _RoleRevealDialogState extends State<RoleRevealDialog>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

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

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
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

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    // Start animations in sequence
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _scaleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _glowController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).pop();
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: Listenable.merge([_fadeAnimation, _scaleAnimation, _glowAnimation]),
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: SingleChildScrollView(
                child: Column( // Main layout column
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The Receipt Card
                    Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      // Add glow to the wrapper if desired, mimicking the old style but around the card
                      decoration: BoxDecoration(
                         borderRadius: BorderRadius.circular(12),
                         boxShadow: [
                            BoxShadow(
                              color: widget.role.color.withOpacity(0.2 + (_glowAnimation.value * 0.3)),
                              blurRadius: 20 + (_glowAnimation.value * 10),
                              spreadRadius: 2,
                            )
                         ]
                      ),
                      child: RoleCardWidget(
                        role: widget.role,
                        playerName: widget.playerName,
                      ),
                    ),
                    
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        widget.subtitle!,
                        style: ClubBlackoutTheme.primaryFont.copyWith(
                          fontSize: 16,
                          color: widget.role.color,
                          fontStyle: FontStyle.italic,
                          shadows: [Shadow(color: widget.role.color, blurRadius: 10)]
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Close button
                    Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _close,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.role.color,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'CONTINUE',
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
    );
  }
}
