import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logic/game_engine.dart';
import '../../logic/games_night_service.dart';
import '../styles.dart';
import '../widgets/club_alert_dialog.dart';
import '../widgets/games_night_widgets.dart';
import 'hall_of_fame_screen.dart';

class GamesNightScreen extends StatefulWidget {
  final GameEngine? gameEngine;

  const GamesNightScreen({super.key, this.gameEngine});

  @override
  State<GamesNightScreen> createState() => _GamesNightScreenState();
}

class _GamesNightScreenState extends State<GamesNightScreen> {
  void _toggleGamesNight(bool enable) {
    setState(() {
      if (enable) {
        GamesNightService.instance.startSession();
      } else {
        GamesNightService.instance.endSession();
      }
    });
  }

  void _clearSession() {
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return ClubAlertDialog(
          title: const Text('End session?'),
          content: Text(
            'This will stop the current Games Night session and clear all temporary recorded data.\n\nThis cannot be undone.',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                GamesNightService.instance.endSession();
                GamesNightService.instance.clear();
                setState(() {});
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(
                backgroundColor: cs.errorContainer,
                foregroundColor: cs.onErrorContainer,
              ),
              child: const Text('End & clear'),
            ),
          ],
        );
      },
    );
  }

  void _copyToClipboard(BuildContext context) {
    final data = GamesNightService.instance.toJson();
    final str = const JsonEncoder.withIndent('  ').convert(data);
    Clipboard.setData(ClipboardData(text: str));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Games Night JSON copied to clipboard')),
    );
  }

  void _showRecap(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return ClubAlertDialog(
          title: const Text('Session Recap'),
          content: SingleChildScrollView(
            child: Text(
              'Recap feature is coming soon!\n\nUse the insights cards below to analyze the current session.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = GamesNightService.instance;
    final isActive = service.isActive;
    final insights = service.getInsights();
    final cs = Theme.of(context).colorScheme;

    // Determine if we should show an AppBar (if we're a standalone route)
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Games Night Stats'),
        centerTitle: true,
        automaticallyImplyLeading: canPop,
        leading: canPop
            ? null
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Track stats across multiple games in a single session.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                GamesNightControlCard(
                  isActive: isActive,
                  startedAt: service.sessionStartTime,
                  gamesRecorded: service.gamesRecordedCount,
                  totalEvents: insights.actions.totalLogEntries,
                  onToggle: _toggleGamesNight,
                  onClear: _clearSession,
                  onCopyJson: () => _copyToClipboard(context),
                  onShowHallOfFame: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              const HallOfFameScreen(isNight: true)),
                    );
                  },
                  onShowRecap: () => _showRecap(context),
                ),
                if (service.gamesRecordedCount > 0) ...[
                  const SizedBox(height: 16),
                  GamesNightSummaryCard(insights: insights),
                  const SizedBox(height: 16),
                  GamesNightVotingCard(insights: insights),
                  const SizedBox(height: 16),
                  GamesNightRolesCard(insights: insights),
                  const SizedBox(height: 16),
                  GamesNightActionsCard(insights: insights),
                ],
                if (isActive && service.gamesRecordedCount == 0)
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'Session is active!\nPlay games to see stats here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
