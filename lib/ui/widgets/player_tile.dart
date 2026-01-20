import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../logic/game_engine.dart';
import '../../logic/player_status_resolver.dart';
import '../styles.dart';
import 'host_player_status_card.dart';

class PlayerTile extends StatelessWidget {
  final Player player;
  final bool isSelected;
  final VoidCallback? onTap;
  final int? voteCount;
  final bool isCompact;
  final GameEngine? gameEngine;

  const PlayerTile({
    super.key,
    required this.player,
    this.isSelected = false,
    this.onTap,
    this.voteCount,
    this.isCompact = false,
    this.gameEngine,
  });

  @override
  Widget build(BuildContext context) {
    if (!isCompact && gameEngine != null) {
      // Use standard consistent tile design
      return HostPlayerStatusCard(
        player: player,
        gameEngine: gameEngine!,
        showControls: false, // Never show controls in player lists
        isSelected: isSelected,
        onTap: onTap,
        trailing: voteCount != null
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: player.role.color.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  '$voteCount',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            : null,
      );
    }

    final color = player.role.color;

    if (isCompact) {
      // Resolve statuses for compact view
      final statuses = gameEngine != null
          ? PlayerStatusResolver.resolveStatus(player, gameEngine!)
          : <PlayerStatusDisplay>[];

      return Card(
        margin: EdgeInsets.zero,
        elevation: isSelected ? 4 : 1,
        color: isSelected
            ? color.withOpacity(0.15)
            : Colors.black.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? color : color.withOpacity(0.3),
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withOpacity(0.2),
          highlightColor: color.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                    boxShadow: isSelected
                        ? ClubBlackoutTheme.circleGlow(color, intensity: 0.8)
                        : ClubBlackoutTheme.circleGlow(color, intensity: 0.3),
                  ),
                  child: ClipOval(
                    child: player.role.assetPath.isNotEmpty
                        ? Image.asset(
                            player.role.assetPath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.person, color: color, size: 48),
                          )
                        : Icon(Icons.person, color: color, size: 48),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  player.name.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (statuses.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 2,
                    children: statuses
                        .map(
                          (s) => Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: s.color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: s.color.withOpacity(0.8),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (voteCount != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$voteCount',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.25)
              : Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.6),
            width: isSelected ? 3 : 2, // Thicker borders
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 5,
                  ),
                ],
        ),
        child: Row(
          children: [
            // Character Icon
            Container(
              width: 72, // Increased from 56
              height: 72, // Increased from 56
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color,
                  width: 3,
                ), // Bolder Icon Border
                boxShadow: ClubBlackoutTheme.circleGlow(color, intensity: 0.8),
              ),
              child: ClipOval(
                child: player.role.assetPath.isNotEmpty
                    ? Image.asset(
                        player.role.assetPath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.person, color: color, size: 40),
                      )
                    : Icon(
                        Icons.person,
                        color: color,
                        size: 40,
                      ), // Increased from 32
              ),
            ),
            const SizedBox(width: 16),
            // Player Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    player.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18, // Larger text
                      fontWeight: FontWeight.w900, // Extra bold
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      player.role.name.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 12, // Larger
                        fontWeight: FontWeight.w900, // Extra bold
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Vote Count (if applicable)
            if (voteCount != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.5), blurRadius: 8),
                  ],
                ),
                child: Text(
                  '$voteCount',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
