import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../models/player.dart';
import '../styles.dart';
import 'bulletin_dialog_shell.dart';
import 'death_announcement_widget.dart';
import 'game_fab_menu.dart';
import 'morning_report_widget.dart';
import 'role_facts_context.dart';
import 'role_reveal_widget.dart';
import 'voting_widget.dart';

class DaySceneDialog extends StatefulWidget {
  final GameEngine gameEngine;
  final VoidCallback onComplete;
  final void Function(String winner, String message)? onGameEnd;

  // Back-compat hooks used by GameScreen/Lobby widget tests.
  // DaySceneDialog currently doesn't use the nav index directly, but accepting
  // these keeps older wiring compiling.
  final int? selectedNavIndex;
  final void Function(int index)? onNavigate;
  final VoidCallback? onGameLogTap;

  const DaySceneDialog({
    super.key,
    required this.gameEngine,
    required this.onComplete,
    this.onGameEnd,
    this.selectedNavIndex,
    this.onNavigate,
    this.onGameLogTap,
  });

  @override
  State<DaySceneDialog> createState() => _DaySceneDialogState();
}

class _DaySceneDialogState extends State<DaySceneDialog> {
  Timer? _discussionTimer;
  Duration _discussionDuration = const Duration(minutes: 5);
  Duration _discussionRemaining = const Duration(minutes: 5);
  bool _discussionRunning = false;
  bool _timerStarted = false;
  int _maxVotes = 0;

  RoleFactsContext _factsContextNow() {
    final engine = widget.gameEngine;
    final enabledGuests =
        engine.guests.where((p) => p.isEnabled).toList(growable: false);
    final aliveGuests =
        enabledGuests.where((p) => p.isAlive).toList(growable: false);
    final dealerKillersAlive =
        aliveGuests.where((p) => p.role.id == 'dealer').length;

    return RoleFactsContext.fromRoster(
      rosterRoles: aliveGuests.map((p) => p.role).toList(growable: false),
      totalPlayers: enabledGuests.length,
      alivePlayers: aliveGuests.length,
      dealerKillersAlive: dealerKillersAlive,
    );
  }

  Duration _computeDiscussionDuration() {
    // Rule: 30 seconds per alive player, capped to 10 players (5 minutes).
    final aliveCount = widget.gameEngine.guests
        .where((p) => p.isAlive && p.isEnabled)
        .where((p) => p.role.id != 'host')
        .length;
    final capped = aliveCount.clamp(1, 10);
    return Duration(seconds: capped * 30);
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _discussionDuration = _computeDiscussionDuration();
        _discussionRemaining = _discussionDuration;
        _timerStarted = false;
        _discussionRunning = false;
      });
    });
  }

  @override
  void dispose() {
    _discussionTimer?.cancel();
    super.dispose();
  }

  void _startDiscussionTimer({bool reset = false}) {
    _discussionTimer?.cancel();
    if (reset) {
      _discussionRemaining = _discussionDuration;
    }
    _timerStarted = true;
    _discussionRunning = true;
    _discussionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_discussionRunning) return;
      if (_discussionRemaining.inSeconds <= 0) {
        _discussionRunning = false;
        _discussionTimer?.cancel();
        _handleTimerExpired();
        setState(() {});
        return;
      }
      setState(() {
        _discussionRemaining =
            Duration(seconds: _discussionRemaining.inSeconds - 1);
      });
    });
    setState(() {});
  }

  void _handleTimerExpired() {
    // If we're here, the timer reached 0.
    // The requirement says: if < 2 votes, go to night.
    // We'll let the UI state reflect this.
  }

  void _pauseDiscussionTimer() {
    _discussionRunning = false;
    setState(() {});
  }

  String _formatMmSs(Duration d) {
    final total = d.inSeconds.clamp(0, 999999);
    final mm = (total ~/ 60).toString().padLeft(2, '0');
    final ss = (total % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Widget _buildDiscussionTimer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDone = _discussionRemaining.inSeconds <= 0;
    final progress = _discussionDuration.inSeconds <= 0
        ? 0.0
        : (_discussionRemaining.inSeconds / _discussionDuration.inSeconds)
            .clamp(0.0, 1.0);

    final timerColor =
        isDone ? ClubBlackoutTheme.neonRed : ClubBlackoutTheme.neonOrange;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: ClubBlackoutTheme.borderRadiusMdAll,
        side: BorderSide(
          color: timerColor.withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: ClubBlackoutTheme.fieldPadding,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_timerStarted)
                        Text(
                          'Time: ${_formatMmSs(_discussionDuration)}',
                          style: tt.labelSmall?.copyWith(
                            color: timerColor.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  _formatMmSs(_discussionRemaining),
                  style: ClubBlackoutTheme.glowTextStyle(
                    base: tt.displaySmall,
                    color: timerColor,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            ClubBlackoutTheme.gap12,
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor:
                    cs.surfaceContainerHighest.withValues(alpha: 0.6),
                valueColor: AlwaysStoppedAnimation<Color>(timerColor),
              ),
            ),
            ClubBlackoutTheme.gap16,
            if (!_timerStarted)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _startDiscussionTimer(reset: true),
                  style: ClubBlackoutTheme.neonButtonStyle(
                    ClubBlackoutTheme.neonOrange,
                    isPrimary: true,
                  ),
                  icon: const Icon(Icons.timer_rounded),
                  label: const Text('Start timer'),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () {
                      if (_discussionRunning) {
                        _pauseDiscussionTimer();
                      } else {
                        _startDiscussionTimer(reset: false);
                      }
                    },
                    tooltip:
                        _discussionRunning ? 'Pause Timer' : 'Resume Timer',
                    icon: Icon(
                      _discussionRunning
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    style: IconButton.styleFrom(foregroundColor: timerColor),
                  ),
                  ClubBlackoutTheme.hGap8,
                  IconButton(
                    onPressed: () => _startDiscussionTimer(reset: true),
                    tooltip: 'Reset Timer',
                    icon: const Icon(Icons.refresh_rounded),
                    style: IconButton.styleFrom(foregroundColor: timerColor),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final engine = widget.gameEngine;
    final summary = engine.lastNightSummary.trim();
    final alive = engine.guests.where((p) => p.isAlive && p.isEnabled).toList();

    return Dialog.fullscreen(
      backgroundColor: cs.surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                'Backgrounds/Club Blackout V2 Game Background.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                child: Container(
                  color: cs.scrim.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      cs.scrim.withValues(alpha: 0.28),
                      Colors.transparent,
                      cs.scrim.withValues(alpha: 0.35),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: cs.onSurface,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: null,
              centerTitle: false,
            ),
            floatingActionButton: GameFabMenu(
              gameEngine: widget.gameEngine,
              baseColor: ClubBlackoutTheme.neonOrange,
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,
            bottomNavigationBar: BottomAppBar(
              shape: const CircularNotchedRectangle(),
              notchMargin: 8.0,
              color: cs.surfaceContainerHighest.withValues(alpha: 0.92),
              surfaceTintColor:
                  ClubBlackoutTheme.neonOrange.withValues(alpha: 0.10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    style: IconButton.styleFrom(foregroundColor: cs.onSurface),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  if (widget.onGameLogTap != null)
                    IconButton(
                      icon: const Icon(Icons.history_rounded),
                      tooltip: 'Game log',
                      style:
                          IconButton.styleFrom(foregroundColor: cs.onSurface),
                      onPressed: widget.onGameLogTap,
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            body: SingleChildScrollView(
              padding: ClubBlackoutTheme.rowPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MorningReportWidget(
                    summary: summary,
                    players: widget.gameEngine.players,
                  ),

                  // --- CUSTOM TOAST/REMINDER FOR HOST ---
                  if (engine.players.any((p) =>
                      p.role.id == 'second_wind' &&
                      p.secondWindPendingConversion))
                    Padding(
                      padding: ClubBlackoutTheme.topInset16,
                      child: Card(
                        elevation: 0,
                        color:
                            cs.surfaceContainerHighest.withValues(alpha: 0.45),
                        shape: RoundedRectangleBorder(
                          borderRadius: ClubBlackoutTheme.borderRadiusMdAll,
                          side: BorderSide(
                            color: ClubBlackoutTheme.neonPink
                                .withValues(alpha: 0.6),
                            width: 1.2,
                          ),
                        ),
                        child: Padding(
                          padding: ClubBlackoutTheme.inset16,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.flash_on_rounded,
                                color: ClubBlackoutTheme.neonPink,
                              ),
                              ClubBlackoutTheme.hGap12,
                              Expanded(
                                child: Text(
                                  'Second Wind: eligible for conversion next night (${engine.hostDisplayName} only). Dealers must forfeit their kill to convert.',
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurface.withValues(alpha: 0.92),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  ClubBlackoutTheme.gap24,
                  _buildDiscussionTimer(context),
                  ClubBlackoutTheme.gap32,

                  ClubBlackoutTheme.gap8,
                  VotingWidget(
                    players: alive,
                    gameEngine: engine,
                    isVotingEnabled:
                        _timerStarted && _discussionRemaining.inSeconds > 0,
                    onMaxVotesChanged: (max) => setState(() => _maxVotes = max),
                    onComplete: (eliminated, verdict) {
                      _pauseDiscussionTimer();
                      _showResults(context, eliminated, verdict);
                    },
                  ),
                  if (_discussionRemaining.inSeconds <= 0 &&
                      _timerStarted &&
                      _maxVotes < 2)
                    Padding(
                      padding: ClubBlackoutTheme.topInset24,
                      child: Card(
                        elevation: 0,
                        color:
                            cs.surfaceContainerHighest.withValues(alpha: 0.45),
                        shape: RoundedRectangleBorder(
                          borderRadius: ClubBlackoutTheme.borderRadiusMdAll,
                          side: BorderSide(
                            color: ClubBlackoutTheme.neonBlue
                                .withValues(alpha: 0.6),
                            width: 1.2,
                          ),
                        ),
                        child: Padding(
                          padding: ClubBlackoutTheme.inset16,
                          child: Column(
                            children: [
                              const Icon(
                                Icons.nightlight_rounded,
                                color: ClubBlackoutTheme.neonBlue,
                                size: 40,
                              ),
                              ClubBlackoutTheme.gap12,
                              Text(
                                'Voting closed',
                                style: ClubBlackoutTheme.neonGlowTextStyle(
                                  base: tt.headlineSmall,
                                  color: ClubBlackoutTheme.neonBlue,
                                  fontWeight: FontWeight.w800,
                                  glowIntensity: 0.85,
                                ),
                              ),
                              ClubBlackoutTheme.gap8,
                              Text(
                                'Not enough votes were cast to reach a verdict. No one was eliminated today.',
                                textAlign: TextAlign.center,
                                style: tt.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              ClubBlackoutTheme.gap16,
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    widget.onComplete();
                                    Navigator.of(context).pop();
                                  },
                                  style: ClubBlackoutTheme.neonButtonStyle(
                                    ClubBlackoutTheme.neonBlue,
                                    isPrimary: true,
                                  ),
                                  icon: const Icon(Icons.nights_stay_rounded),
                                  label: const Text('Go to night'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ClubBlackoutTheme.gap40,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showResults(
    BuildContext context,
    Player eliminated,
    String verdict,
  ) async {
    await showDeathAnnouncement(
      context,
      eliminated,
      eliminated.role,
      causeOfDeath: 'VERDICT: $verdict',
      factsContext: _factsContextNow(),
      onComplete: () async {
        widget.gameEngine.processDeath(eliminated, cause: 'vote');
        await _maybeResolveTeaSpillerVoteRetaliation(context);

        if (!context.mounted) return;
        Navigator.of(context).pop();
        widget.onComplete();
      },
    );
  }

  Future<void> _maybeResolveTeaSpillerVoteRetaliation(
      BuildContext context) async {
    final engine = widget.gameEngine;
    final teaId = engine.pendingTeaSpillerId;
    if (teaId == null) return;

    final eligibleIds =
        List<String>.from(engine.pendingTeaSpillerEligibleVoterIds);
    if (eligibleIds.isEmpty) {
      // Should be handled defensively by the engine; clear any stale state.
      engine.pendingTeaSpillerId = null;
      engine.pendingTeaSpillerEligibleVoterIds = <String>[];
      return;
    }

    final candidates = engine.players
        .where((p) => p.isAlive && p.isEnabled)
        .where((p) => eligibleIds.contains(p.id))
        .toList(growable: false);

    if (candidates.isEmpty) {
      engine.pendingTeaSpillerId = null;
      engine.pendingTeaSpillerEligibleVoterIds = <String>[];
      return;
    }

    Player? selected;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return BulletinDialogShell(
          accent: ClubBlackoutTheme.neonOrange,
          maxWidth: 520,
          maxHeight: 820,
          padding: ClubBlackoutTheme.inset24,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_food_beverage_rounded,
                color: ClubBlackoutTheme.neonOrange,
                size: 48,
              ),
              ClubBlackoutTheme.gap16,
              Text(
                'Tea time',
                style: ClubBlackoutTheme.glowTextStyle(
                  base: ClubBlackoutTheme.headingStyle,
                  color: ClubBlackoutTheme.neonOrange,
                  fontSize: 28,
                ),
              ),
              ClubBlackoutTheme.gap12,
              Text(
                'Hand the screen to the Tea Spiller.\nSelect ONE target who voted for you:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              ClubBlackoutTheme.gap24,
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => ClubBlackoutTheme.gap12,
                  itemBuilder: (_, i) {
                    final p = candidates[i];
                    return FilledButton(
                      style: ClubBlackoutTheme.neonButtonStyle(
                        ClubBlackoutTheme.neonOrange,
                        isPrimary: true,
                      ),
                      onPressed: () {
                        selected = p;
                        Navigator.of(ctx).pop();
                      },
                      child: Text(
                        p.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!context.mounted) return;
    if (selected == null) return;

    final ok = engine.completeTeaSpillerReveal(selected!.id);
    if (!ok) return;

    await showRoleReveal(
      context,
      selected!.role,
      'The club',
      subtitle: '${selected!.name} has been exposed!',
      factsContext: _factsContextNow(),
    );
  }
}
