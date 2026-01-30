import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../models/player.dart';
import '../styles.dart';
import 'club_alert_dialog.dart';
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
    // Timer expired logic
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

    final timerColor = isDone ? cs.error : cs.primary;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  _formatMmSs(_discussionRemaining),
                  style: tt.displayMedium?.copyWith(
                    color: timerColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              color: timerColor,
              backgroundColor: cs.surfaceContainerHighest,
            ),
            const SizedBox(height: 16),
            if (!_timerStarted)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _startDiscussionTimer(reset: true),
                  icon: const Icon(Icons.timer),
                  label: const Text('Start Timer'),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton.filledTonal(
                    onPressed: () {
                      if (_discussionRunning) {
                        _pauseDiscussionTimer();
                      } else {
                        _startDiscussionTimer(reset: false);
                      }
                    },
                    icon: Icon(
                      _discussionRunning ? Icons.pause : Icons.play_arrow,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () => _startDiscussionTimer(reset: true),
                    icon: const Icon(Icons.refresh),
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
    final engine = widget.gameEngine;
    final summary = engine.lastNightSummary.trim();
    final alive = engine.guests.where((p) => p.isAlive && p.isEnabled).toList();

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Day Phase'),
        ),
        floatingActionButton: GameFabMenu(
          gameEngine: widget.gameEngine,
          baseColor: cs.primary,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MorningReportWidget(
                summary: summary,
                players: widget.gameEngine.players,
              ),

              if (engine.players.any((p) =>
                  p.role.id == 'second_wind' && p.secondWindPendingConversion))
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Card(
                    color: cs.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.flash_on, color: cs.onTertiaryContainer),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Second Wind: eligible for conversion next night (${engine.hostDisplayName} only).',
                              style: TextStyle(
                                color: cs.onTertiaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              _buildDiscussionTimer(context),
              const SizedBox(height: 32),

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
                  padding: const EdgeInsets.only(top: 24),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.nightlight_round,
                              size: 40, color: cs.primary),
                          const SizedBox(height: 12),
                          Text(
                            'Voting Closed',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Not enough votes were cast to reach a verdict. No one was eliminated today.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () {
                                widget.onComplete();
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.nights_stay),
                              label: const Text('Go to Night'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 80), // Space for FAB
            ],
          ),
        ),
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
        return ClubAlertDialog(
          title: const Text('Tea Time'),
          content: SizedBox(
            height: 400,
            width: double.maxFinite,
            child: Column(
              children: [
                const Text('Select ONE target who voted for you:'),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: candidates.length,
                    itemBuilder: (_, i) {
                      final p = candidates[i];
                      return ListTile(
                        title: Text(p.name),
                        onTap: () {
                          selected = p;
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
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
      'The Club',
      subtitle: '${selected!.name} has been exposed!',
      factsContext: _factsContextNow(),
    );
  }
}
