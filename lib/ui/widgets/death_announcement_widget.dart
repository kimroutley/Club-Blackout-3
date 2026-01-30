import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../models/role.dart';
import '../../services/sound_service.dart';
import '../animations.dart';
import 'club_alert_dialog.dart';
import 'role_card_widget.dart';
import 'role_facts_context.dart';

/// Shows a dramatic death announcement with role reveal
Future<void> showDeathAnnouncement(
  BuildContext context,
  Player player,
  Role? role, {
  String? causeOfDeath,
  RoleFactsContext? factsContext,
  VoidCallback? onComplete,
}) async {
  SoundService().playDeath();

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.88),
    builder: (context) => DeathAnnouncementDialog(
      player: player,
      role: role,
      causeOfDeath: causeOfDeath,
      factsContext: factsContext,
      onComplete: onComplete,
    ),
  );
}

class DeathAnnouncementDialog extends StatefulWidget {
  final Player player;
  final Role? role;
  final String? causeOfDeath;
  final RoleFactsContext? factsContext;
  final VoidCallback? onComplete;

  const DeathAnnouncementDialog({
    super.key,
    required this.player,
    this.role,
    this.causeOfDeath,
    this.factsContext,
    this.onComplete,
  });

  @override
  State<DeathAnnouncementDialog> createState() =>
      _DeathAnnouncementDialogState();
}

class _DeathAnnouncementDialogState extends State<DeathAnnouncementDialog>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: ClubMotion.overlay,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: ClubMotion.easeOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: ClubMotion.easeOutBack,
      ),
    );

    // Start animations
    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).pop();
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: ClubAlertDialog(
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: cs.errorContainer,
                    foregroundColor: cs.onErrorContainer,
                    child: const Text('💀', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Eliminated',
                      style: (tt.titleLarge ?? const TextStyle()).copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.player.name,
                      textAlign: TextAlign.center,
                      style: (tt.headlineSmall ?? const TextStyle()).copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                      ),
                    ),
                    if (widget.causeOfDeath != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.causeOfDeath!,
                        textAlign: TextAlign.center,
                        style: (tt.bodyMedium ?? const TextStyle()).copyWith(
                          color: cs.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (widget.role != null) ...[
                      const SizedBox(height: 16),
                      RoleCardWidget(
                        role: widget.role!,
                        factsContext: widget.factsContext,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: cs.errorContainer.withValues(alpha: 0.45),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'They have been eliminated from the game',
                          textAlign: TextAlign.center,
                          style: (tt.bodyMedium ?? const TextStyle()).copyWith(
                            color: cs.onSurface.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: _close,
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.errorContainer,
                    foregroundColor: cs.onErrorContainer,
                  ),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
