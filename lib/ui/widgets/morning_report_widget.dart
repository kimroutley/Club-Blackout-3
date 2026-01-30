import 'package:flutter/material.dart';

import '../../models/player.dart';
import '../animations.dart';
import '../styles.dart';
import 'player_icon.dart';

class MorningReportWidget extends StatelessWidget {
  final String summary;
  final List<Player> players;

  const MorningReportWidget({
    super.key,
    required this.summary,
    this.players = const [],
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reportLines = summary
        .split('\n')
        .map((s) => s.trim())
        .where((s) =>
            s.isNotEmpty &&
            s != 'Good Morning, Clubbers!' &&
            !s.startsWith('Here is what'))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'WTF HAPPENED LAST NIGHT',
              style: ClubBlackoutTheme.bulletinHeaderStyle(
                  ClubBlackoutTheme.neonOrange),
            ),
            const Icon(Icons.emergency_rounded,
                color: ClubBlackoutTheme.neonOrange, size: 24),
          ],
        ),
        const SizedBox(height: 16),
        if (reportLines.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'A QUIET NIGHT. NO INCIDENTS RECORDED.',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.6),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reportLines.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final line = reportLines[i].replaceFirst('•', '').trim();
              final lineColor = _getLineColor(line);
              return UiAnims.fadeIn(
                Container(
                  decoration: ClubBlackoutTheme.bulletinItemDecoration(
                      color: lineColor),
                  padding: ClubBlackoutTheme.rowPadding,
                  child: Row(
                    children: [
                      _getLineWidget(line, context),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          line,
                          style:
                              ClubBlackoutTheme.bulletinBodyStyle(cs.onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _getLineWidget(String line, BuildContext context) {
    if (players.isNotEmpty) {
      // Find player names in the line (case insensitive)
      final l = line.toLowerCase();
      Player? matchingPlayer;
      for (final p in players) {
        if (l.contains(p.name.toLowerCase())) {
          matchingPlayer = p;
          break;
        }
      }

      if (matchingPlayer != null) {
        return PlayerIcon(
          assetPath: matchingPlayer.role.assetPath,
          glowColor: matchingPlayer.role.color,
          size: 32,
          isAlive: true, // Always show alive icons in the report for clarity
        );
      }
    }

    return _getLineIcon(line);
  }

  Color _getLineColor(String line) {
    final l = line.toLowerCase();
    if (l.contains('died') ||
        l.contains('found dead') ||
        l.contains('murder') ||
        l.contains('heartbreak')) {
      return ClubBlackoutTheme.neonRed;
    }
    if (l.contains('survived') ||
        l.contains('saved') ||
        l.contains('miracle') ||
        l.contains('returned')) {
      return ClubBlackoutTheme.neonGreen;
    }
    if (l.contains('rumour')) {
      return ClubBlackoutTheme.neonPurple;
    }
    if (l.contains('alibi') || l.contains('sent home')) {
      return ClubBlackoutTheme.neonBlue;
    }
    if (l.contains('swapped') ||
        l.contains('switched') ||
        l.contains('personas')) {
      return ClubBlackoutTheme.neonPink;
    }
    return ClubBlackoutTheme.neonOrange;
  }

  Widget _getLineIcon(String line) {
    final l = line.toLowerCase();
    IconData iconData = Icons.info_outline_rounded;
    final Color color = _getLineColor(line);

    if (l.contains('died') ||
        l.contains('found dead') ||
        l.contains('murder') ||
        l.contains('heartbreak')) {
      iconData = Icons.person_off_rounded;
    } else if (l.contains('survived') ||
        l.contains('saved') ||
        l.contains('miracle') ||
        l.contains('returned')) {
      iconData = Icons.favorite_rounded;
    } else if (l.contains('rumour')) {
      iconData = Icons.record_voice_over_rounded;
    } else if (l.contains('alibi')) {
      iconData = Icons.verified_user_rounded;
    } else if (l.contains('sent home')) {
      iconData = Icons.exit_to_app_rounded;
    } else if (l.contains('swapped') ||
        l.contains('switched') ||
        l.contains('personas')) {
      iconData = Icons.swap_horiz_rounded;
    }

    return Icon(iconData, color: color, size: 20);
  }
}
