import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../logic/player_status_resolver.dart';
import '../../models/player.dart';
import '../styles.dart';
import 'player_icon.dart';

class HostPlayerStatusCard extends StatelessWidget {
  final Player player;
  final GameEngine gameEngine;
  final bool showControls;
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget? trailing;

  const HostPlayerStatusCard({
    super.key,
    required this.player,
    required this.gameEngine,
    this.showControls = true,
    this.isSelected = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final statuses = PlayerStatusResolver.resolveStatus(player, gameEngine);
    final glow = player.role.color;
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 3 : 0,
      color: isSelected
          ? glow.withValues(alpha: 0.25)
          : cs.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: ClubBlackoutTheme.borderRadiusMdAll,
        side: isSelected ? BorderSide(color: glow, width: 2) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: ClubBlackoutTheme.fieldPadding,
          child: Row(
            children: [
              // Icon
              PlayerIcon(
                assetPath: player.role.assetPath,
                glowColor: glow,
                size: 44,
                isAlive: player.isAlive,
                isEnabled: player.isEnabled,
                glowIntensity: isSelected ? 1.0 : 0.8,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      player.role.name,
                      style: TextStyle(
                        color: glow.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (statuses.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: statuses
                            .take(5)
                            .map(
                              (s) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: s.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: s.color.withValues(alpha: 0.4),
                                      width: 1.0),
                                ),
                                child: Text(
                                  s.label,
                                  style: TextStyle(
                                    color: s.color,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              if (showControls)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Switch(
                    activeTrackColor: glow.withValues(alpha: 0.5),
                    activeThumbColor: glow,
                    value: player.isEnabled,
                    onChanged: (v) {
                      player.isEnabled = v;
                      gameEngine.refreshUi();
                    },
                  ),
                ),
              if (trailing != null) const SizedBox(width: 8),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ), // End InkWell
    ); // End Card
  }
}
