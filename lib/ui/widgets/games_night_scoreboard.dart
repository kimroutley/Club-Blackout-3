import 'package:flutter/material.dart';
import '../../logic/games_night_service.dart';
import '../../logic/shenanigans_tracker.dart';
import '../styles.dart';
import 'club_alert_dialog.dart';

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
    const themeColor = ClubBlackoutTheme.neonBlue;

    return ClubAlertDialog(
      title: Column(
        children: [
          const Icon(Icons.emoji_events, color: themeColor, size: 48),
          const SizedBox(height: 12),
          Text(
            'Games Night Recap',
            style: TextStyle(
              color: themeColor,
              fontWeight: FontWeight.bold,
              fontSize: 24,
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
              'Values aggregated across ${snapshots.length} games.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Hall of Fame',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
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
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: awards.length,
                      itemBuilder: (context, index) {
                        final award = awards[index];
                        return Card(
                          elevation: 0,
                          color: cs.surfaceContainer,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  award.color.withValues(alpha: 0.1),
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurface,
                                  ),
                                ),
                                Text(award.description),
                              ],
                            ),
                            trailing: Text(
                              award.value,
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
        FilledButton(
          onPressed: onClose,
          child: const Text('Close Recap'),
        ),
      ],
    );
  }
}
