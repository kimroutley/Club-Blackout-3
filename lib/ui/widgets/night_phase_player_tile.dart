import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../models/player.dart';
import '../styles.dart';
import 'player_icon.dart';

class NightPhasePlayerTile extends StatelessWidget {
  final Player player;
  final bool isSelected;
  final GameEngine gameEngine;
  final String? statsText;
  final VoidCallback? onTap;
  final VoidCallback? onConfirm;

  const NightPhasePlayerTile({
    super.key,
    required this.player,
    required this.isSelected,
    required this.gameEngine,
    this.statsText,
    this.onTap,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    // final cs = Theme.of(context).colorScheme;

    final subtitle = statsText ?? player.role.name;
    final accent = player.role.color;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: isSelected ? 4 : 1,
        color: isSelected
            ? accent.withValues(alpha: 0.25)
            : cs.surfaceContainerHigh.withValues(alpha: 0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isSelected
              ? BorderSide(color: accent, width: 2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                PlayerIcon(
                  assetPath: player.role.assetPath,
                  glowColor: accent,
                  glowIntensity: isSelected ? 0.5 : 0.0,
                  size: 48,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        player.name,
                        style: ClubBlackoutTheme.glowTextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          glow: false, // isSelected, // Maybe too much glow
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle.toUpperCase(),
                        style: TextStyle(
                          color: isSelected
                              ? accent
                              : Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onConfirm != null) ...[
                  const SizedBox(width: 16),
                  IgnorePointer(
                    ignoring: !isSelected,
                    child: AnimatedOpacity(
                      opacity: isSelected ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: SizedBox(
                        height: 40,
                        child: FilledButton(
                          onPressed: onConfirm,
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: ClubBlackoutTheme.contrastOn(accent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'CONFIRM',
                                style: TextStyle(
                                  color: ClubBlackoutTheme.contrastOn(accent),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: ClubBlackoutTheme.contrastOn(accent),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
