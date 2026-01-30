import 'package:flutter/material.dart';
import '../../logic/games_night_service.dart';
import '../../logic/shenanigans_tracker.dart';
import '../styles.dart';
import 'bulletin_dialog_shell.dart';

class GamesNightScoreboard extends StatelessWidget {
  final GamesNightService service;
  final VoidCallback onClose;

  const GamesNightScoreboard({
    super.key,
    required this.service,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final snapshots = service.completedGameSnapshots;
    final awards = ShenanigansTracker.generateSessionAwards(snapshots);
    
    // Theme color - Neutral Gold/Blue for session stats
    const themeColor = ClubBlackoutTheme.neonBlue;

    return BulletinDialogShell(
      accent: themeColor,
      maxWidth: 520,
      maxHeight: 720,
      insetPadding: ClubBlackoutTheme.dialogInsetPadding,
      padding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: themeColor,
            size: 60,
          ),
          const SizedBox(height: 16),
          Text(
            'GAMES NIGHT RECAP',
            style: ClubBlackoutTheme.glowTextStyle(
              base: ClubBlackoutTheme.headingStyle,
              color: themeColor,
              fontSize: 28,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Values aggregated across ${snapshots.length} games.',
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
            'HALL OF FAME',
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
                      snapshots.isEmpty
                          ? 'No games completed yet.'
                          : 'No outliers detected across the session.',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                    ),
                  )
                : ListView.builder(
                    itemCount: awards.length,
                    itemBuilder: (context, index) {
                      final award = awards[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.05),
                          borderRadius: ClubBlackoutTheme.borderRadiusSmAll,
                          border: Border.all(
                            color: award.color.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
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
                                        award.value,
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
              onPressed: onClose,
              icon: const Icon(Icons.close),
              label: const Text('Close recap'),
            ),
          ),
        ],
      ),
    );
  }
}
