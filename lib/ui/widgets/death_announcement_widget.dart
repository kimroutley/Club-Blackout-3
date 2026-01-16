import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../models/role.dart';
import '../../services/sound_service.dart';
import '../styles.dart';
import 'role_card_widget.dart';

/// Shows a dramatic death announcement with role reveal
void showDeathAnnouncement(
  BuildContext context,
  Player player,
  Role? role, {
  String? causeOfDeath,
  VoidCallback? onComplete,
}) {
  SoundService().playDeath();
  
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    builder: (context) => DeathAnnouncementDialog(
      player: player,
      role: role,
      causeOfDeath: causeOfDeath,
      onComplete: onComplete,
    ),
  );
}

class DeathAnnouncementDialog extends StatefulWidget {
  final Player player;
  final Role? role;
  final String? causeOfDeath;
  final VoidCallback? onComplete;

  const DeathAnnouncementDialog({
    super.key,
    required this.player,
    this.role,
    this.causeOfDeath,
    this.onComplete,
  });

  @override
  State<DeathAnnouncementDialog> createState() => _DeathAnnouncementDialogState();
}

class _DeathAnnouncementDialogState extends State<DeathAnnouncementDialog>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutBack,
      ),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Start animations
    _fadeController.forward();
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _pulseController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
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
        animation: Listenable.merge([_fadeAnimation, _scaleAnimation, _pulseAnimation]),
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
                    color: ClubBlackoutTheme.crimsonRed,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ClubBlackoutTheme.crimsonRed.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Skull icon
                    Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ClubBlackoutTheme.crimsonRed.withOpacity(0.2),
                          border: Border.all(
                            color: ClubBlackoutTheme.crimsonRed,
                            width: 3,
                          ),
                          boxShadow: ClubBlackoutTheme.circleGlow(
                            ClubBlackoutTheme.crimsonRed,
                            intensity: 1.2,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            '💀',
                            style: TextStyle(fontSize: 50),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // "RIP" text
                    Text(
                      'R.I.P.',
                      style: ClubBlackoutTheme.primaryFont.copyWith(
                        fontSize: 36,
                        color: ClubBlackoutTheme.crimsonRed,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Player name
                    Text(
                      widget.player.name,
                      style: ClubBlackoutTheme.primaryFont.copyWith(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    // Cause of death
                    if (widget.causeOfDeath != null)
                      Text(
                        widget.causeOfDeath!,
                        style: ClubBlackoutTheme.primaryFont.copyWith(
                          fontSize: 14,
                          color: Colors.white60,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),

                    const SizedBox(height: 24),

                    // Role reveal
                    if (widget.role != null) ...[
                      RoleCardWidget(role: widget.role!),
                      const SizedBox(height: 16),
                    ],

                    // Final message
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ClubBlackoutTheme.crimsonRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ClubBlackoutTheme.crimsonRed.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        'They have been eliminated from the game',
                        style: ClubBlackoutTheme.primaryFont.copyWith(
                          fontSize: 14,
                          color: ClubBlackoutTheme.crimsonRed,
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
                          backgroundColor: ClubBlackoutTheme.crimsonRed,
                          foregroundColor: Colors.white,
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
