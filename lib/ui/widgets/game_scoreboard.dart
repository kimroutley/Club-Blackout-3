import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../logic/shenanigans_tracker.dart';
import '../styles.dart';
import 'bulletin_dialog_shell.dart';
import 'player_icon.dart';

class GameScoreboard extends StatelessWidget {
  final GameEngine gameEngine;
  final VoidCallback onRestart;

  const GameScoreboard({
    super.key,
    required this.gameEngine,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final awards = ShenanigansTracker.generateAwards(gameEngine);
    final winnerColor = gameEngine.winner?.toLowerCase().contains('dealer') == true 
        ? ClubBlackoutTheme.neonPurple 
        : ClubBlackoutTheme.neonGreen;
    return BulletinDialogShell(
      accent: winnerColor,
      maxWidth: 520,
      maxHeight: 720,
      insetPadding: ClubBlackoutTheme.dialogInsetPadding,
      padding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(
            Icons.emoji_events_rounded,
            color: winnerColor,
            size: 60,
          ),
          const SizedBox(height: 16),
          Text(
            (gameEngine.winner ?? 'Game over'),
            style: ClubBlackoutTheme.glowTextStyle(
              base: ClubBlackoutTheme.headingStyle,
              color: winnerColor,
              fontSize: 28,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            gameEngine.winMessage ?? 'The game has reached its conclusion.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            height: 1,
            color: cs.onSurface.withValues(alpha: 0.12),
            width: double.infinity,
          ),
          const SizedBox(height: 16),
          Text(
            'Nightclub legends',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: awards.isEmpty
                ? Center(
                    child: Text(
                      'No shenanigans detected tonight.',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                    ),
                  )
                : ListView.builder(
                    itemCount: awards.length,
                    itemBuilder: (context, index) {
                      final award = awards[index];
                      final player =
                          gameEngine.players.where((p) => p.id == award.playerId).firstOrNull ??
                              gameEngine.guests.where((p) => p.id == award.playerId).firstOrNull;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: award.color.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                if (player != null)
                                  PlayerIcon(
                                    assetPath: player.role.assetPath,
                                    glowColor: award.color,
                                    size: 52,
                                  )
                                else
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: award.color.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      award.icon,
                                      color: award.color,
                                      size: 24,
                                    ),
                                  ),
                                if (player != null)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: award.color,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: cs.surface, width: 2),
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      award.icon,
                                      color: Colors.black,
                                      size: 12,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        award.title,
                                        style: TextStyle(
                                          color: award.color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        award.value.toString(),
                                        style: TextStyle(
                                          color: cs.onSurface.withValues(alpha: 0.54),
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    award.playerName,
                                    style: TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    award.description,
                                    style: TextStyle(
                                      color: cs.onSurface.withValues(alpha: 0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: ClubBlackoutTheme.neonButtonStyle(
                ClubBlackoutTheme.neonBlue,
                isPrimary: true,
              ),
              onPressed: onRestart,
              icon: const Icon(Icons.home_rounded),
              label: const Text('Back to lobby'),
            ),
          ),
        ],
      ),
    );
  }
}
