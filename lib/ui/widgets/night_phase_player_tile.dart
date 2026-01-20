import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/player.dart';
import '../../logic/game_engine.dart';
import '../styles.dart';
import '../animations.dart';
import 'host_player_status_card.dart';

class NightPhasePlayerTile extends StatefulWidget {
  final Player player;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onConfirm;
  final String? statsText;
  final GameEngine gameEngine;

  const NightPhasePlayerTile({
    super.key,
    required this.player,
    required this.isSelected,
    required this.onTap,
    this.onConfirm,
    required this.gameEngine,
    this.statsText,
  });

  @override
  State<NightPhasePlayerTile> createState() => _NightPhasePlayerTileState();
}

class _NightPhasePlayerTileState extends State<NightPhasePlayerTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: ClubMotion.short);
    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    if (widget.isSelected) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(NightPhasePlayerTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
        HapticFeedback.lightImpact();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reuse full host player card for consistent look/status chips
    return Stack(
      children: [
        HostPlayerStatusCard(
          player: widget.player,
          gameEngine: widget.gameEngine,
          showControls: false,
          isSelected: widget.isSelected,
          onTap: () {
            if (widget.isSelected) {
              _controller.value = 1.0;
            } else {
              _controller.reverse();
            }
            widget.onTap();
          },
          trailing: (widget.statsText != null && widget.statsText!.isNotEmpty)
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: widget.player.role.color.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.player.role.color.withOpacity(0.6),
                    ),
                  ),
                  child: Text(
                    widget.statsText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : null,
        ),

        // Selection check overlay - NOW INTERACTIVE FOR APPROVAL
        if (widget.isSelected)
          Positioned(
            top: 8,
            right: 8,
            child: AnimatedBuilder(
              animation: _opacityAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.scale(
                    scale: 0.8 + (_opacityAnimation.value * 0.2),
                    child: FilledButton.icon(
                      onPressed: widget.onConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: ClubBlackoutTheme.neonGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                        elevation: 6,
                        shadowColor: ClubBlackoutTheme.neonGreen.withOpacity(
                          0.4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text(
                        "CONFIRM",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          fontSize: 13,
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
  }
}
