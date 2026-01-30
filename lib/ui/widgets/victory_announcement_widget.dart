import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../styles.dart';
import 'player_icon.dart';

void showVictoryAnnouncement(
  BuildContext context,
  String winningTeam,
  List<String> winners,
  GameEngine gameEngine, {
  VoidCallback? onComplete,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.92),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Builder(
          builder: (ctx) {
            final cs = Theme.of(ctx).colorScheme;
            final teamColor = winningTeam.toLowerCase().contains('dealer')
                ? ClubBlackoutTheme.neonPurple
                : ClubBlackoutTheme.neonGreen;

            final players = gameEngine.players;

            return Container(
              decoration: ClubBlackoutTheme.neonFrame(
                color: teamColor,
                opacity: 0.95,
                borderRadius: 28,
                borderWidth: 3.0,
                showGlow: true,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Victory',
                    textAlign: TextAlign.center,
                    style: ClubBlackoutTheme.neonGlowTextStyle(
                      color: teamColor,
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4.0,
                      glowIntensity: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    winningTeam,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: teamColor.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (winners.isNotEmpty) ...[
                    Text(
                      'Congratulations to:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.5),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: winners.map((name) {
                        final player = players.firstWhere(
                          (p) => p.name.toLowerCase() == name.toLowerCase(),
                          orElse: () => players.first,
                        );
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PlayerIcon(
                              assetPath: player.role.assetPath,
                              glowColor: player.role.color,
                              size: 48,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              player.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 32),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: teamColor,
                      foregroundColor: cs.surface,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const RoundedRectangleBorder(
                        borderRadius: ClubBlackoutTheme.borderRadiusSmAll,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onComplete?.call();
                    },
                    child: const Text(
                      'Continue',
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
