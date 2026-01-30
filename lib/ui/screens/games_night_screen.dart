import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logic/game_engine.dart';
import '../../logic/games_night_service.dart';
import '../styles.dart';
import '../widgets/bulletin_dialog_shell.dart';
import '../widgets/club_alert_dialog.dart';
import '../widgets/games_night_widgets.dart';
import '../widgets/neon_background.dart';
import 'hall_of_fame_screen.dart';

class GamesNightScreen extends StatefulWidget {
  final GameEngine? gameEngine;

  const GamesNightScreen({super.key, this.gameEngine});

  @override
  State<GamesNightScreen> createState() => _GamesNightScreenState();
}

class _GamesNightScreenState extends State<GamesNightScreen> {
  // We use this to force a rebuild when the service state changes
  // Ideally we would use a ValueListenable or StreamBuilder, but for now setState loop or query on build is okay
  // GamesNightService is a singleton but doesn't expose a stream yet. We can rely on build updates
  // or wrap operations.

  void _toggleGamesNight(bool enable) {
    setState(() {
      if (enable) {
        GamesNightService.instance.startSession();
      } else {
        // If disabling, we might want to confirm if they want to end it.
        // But the service logic is: if active, `recordGame` works. If not, it doesn't.
        // `startSession` just sets active=true.
        GamesNightService.instance.endSession();
      }
    });
  }

  void _clearSession() {
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isNight = widget.gameEngine?.currentPhase == GamePhase.night;

        if (isNight) {
          return ClubAlertDialog(
            title: const Text('End session?'),
            content: const Text(
              'This will stop the current Games Night session and clear all temporary recorded data.\n\nThis cannot be undone.',
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
                child: const Text('End & clear'),
              ),
            ],
          );
        }

        return BulletinDialogShell(
          accent: ClubBlackoutTheme.neonPink,
          maxWidth: 520,
          title: Text(
            'END SESSION?',
            style: ClubBlackoutTheme.bulletinHeaderStyle(
                ClubBlackoutTheme.neonPink),
          ),
          content: Text(
            'This will stop the current Games Night session and clear all temporary recorded data.\n\nThis cannot be undone.',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.9),
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                  foregroundColor: cs.onSurface.withValues(alpha: 0.7)),
              child: const Text('CANCEL'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                GamesNightService.instance.endSession();
                GamesNightService.instance.clear();
                setState(() {});
                Navigator.pop(ctx);
              },
              style: ClubBlackoutTheme.neonButtonStyle(
                  ClubBlackoutTheme.neonRed,
                  isPrimary: true),
              child: const Text('END & CLEAR'),
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
    // Placeholder for a dedicated recap screen or dialog
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isNight = widget.gameEngine?.currentPhase == GamePhase.night;

        if (isNight) {
          return ClubAlertDialog(
            title: const Text('Session Recap'),
            content: const SingleChildScrollView(
              child: Text(
                'Recap feature is coming soon!\n\nUse the insights cards below to analyze the current session.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          );
        }

        return BulletinDialogShell(
          accent: ClubBlackoutTheme.neonPink,
          maxWidth: 520,
          title: Text(
            'SESSION RECAP',
            style: ClubBlackoutTheme.bulletinHeaderStyle(
                ClubBlackoutTheme.neonPink),
          ),
          content: SingleChildScrollView(
            child: Text(
              'Recap feature is coming soon!\n\nUse the insights cards below to analyze the current session.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.9),
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                  foregroundColor: cs.onSurface.withValues(alpha: 0.7)),
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
    final isNight = widget.gameEngine?.currentPhase == GamePhase.night;

    // Determine if we should show an AppBar (if we're a standalone route)
    final canPop = Navigator.of(context).canPop();

    if (isNight) {
      if (canPop) {
        return Scaffold(
          appBar: AppBar(title: const Text('Games Night Stats')),
          body: SingleChildScrollView(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildContent(context, service, insights, isActive,
                    isNight: true),
              ),
            ),
          ),
        );
      } else {
        // Top level drawer item in Night Mode
        return Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: _buildContent(context, service, insights, isActive,
                  isNight: true),
            ),
          ),
        );
      }
    }

    // Day Phase (Neon Theme + M3 Structure)
    return Stack(
      children: [
        const Positioned.fill(
          child: NeonBackground(
            accentColor: ClubBlackoutTheme.neonPurple,
            backgroundAsset: 'Backgrounds/Club Blackout V2 Game Background.png',
            blurSigma: 12.0,
            showOverlay: true,
            child: SizedBox.expand(),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: canPop
              ? AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                )
              : null, // Handled by MainScreen
          body: Builder(
            builder: (context) {
              final topPadding = canPop
                  ? (MediaQuery.of(context).padding.top + kToolbarHeight - 12)
                  : (MediaQuery.of(context).padding.top + kToolbarHeight - 12);
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: topPadding,
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.paddingOf(context).bottom + 24,
                ),
                child: _buildContent(context, service, insights, isActive,
                    isNight: false),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, GamesNightService service,
      GamesNightInsights insights, bool isActive,
      {required bool isNight}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isNight) const SizedBox(height: 8),
        if (!isNight)
          const Text(
            'Track stats across multiple games in a single session.',
            style: TextStyle(color: Colors.white70),
          ),
        if (isNight)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Text(
              'Track stats across multiple games in a single session.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        SizedBox(height: isNight ? 8 : 16),
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
                  builder: (_) => HallOfFameScreen(isNight: isNight)),
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        const SizedBox(height: 40),
      ],
    );
  }
}
