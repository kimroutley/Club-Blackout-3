import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../logic/shenanigans_tracker.dart';
import '../styles.dart';
import 'club_alert_dialog.dart';
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

    return ClubAlertDialog(
      title: Column(
        children: [
          Icon(Icons.emoji_events, color: winnerColor, size: 48),
          const SizedBox(height: 12),
          Text(
            gameEngine.winner ?? 'Game Over',
            style: TextStyle(
              color: winnerColor,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 600,
        child: Column(
          children: [
            Text(
              gameEngine.winMessage ?? 'The game has reached its conclusion.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Nightclub Legends',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: awards.isEmpty
                  ? Center(
                      child: Text(
                        'No shenanigans detected tonight.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: awards.length,
                      itemBuilder: (context, index) {
                        final award = awards[index];
                        final player =
                            gameEngine.players.where((p) => p.id == award.playerId).firstOrNull ??
                                gameEngine.guests.where((p) => p.id == award.playerId).firstOrNull;

                        return Card(
                          elevation: 0,
                          color: cs.surfaceContainer,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: player != null
                                ? PlayerIcon(
                                    assetPath: player.role.assetPath,
                                    glowColor: award.color,
                                    size: 40,
                                  )
                                : CircleAvatar(
                                    backgroundColor: award.color.withValues(alpha: 0.1),
                                    child: Icon(award.icon, color: award.color),
                                  ),
                            title: Text(
                              award.title,
                              style: TextStyle(
                                color: award.color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  award.playerName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(award.description),
                              ],
                            ),
                            trailing: Text(
                              award.value.toString(),
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton.icon(
          onPressed: onRestart,
          icon: const Icon(Icons.home),
          label: const Text('Back to Lobby'),
        ),
      ],
    );
  }
}
