import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../logic/game_engine.dart';
import '../../models/player.dart';
import '../../ui/utils/player_sort.dart';
import '../styles.dart';
import '../animations.dart';
import '../widgets/player_tile.dart';
import 'game_drawer.dart';

/// Day phase dialog with Material 3 design matching night phase flow
class DaySceneDialog extends StatefulWidget {
  final GameEngine gameEngine;
  final VoidCallback onComplete;
  final void Function(String winner, String message)? onGameEnd;
  final void Function(int index)? onNavigate;
  final VoidCallback? onGameLogTap;
  final int selectedNavIndex;

  const DaySceneDialog({
    super.key,
    required this.gameEngine,
    required this.onComplete,
    this.onGameEnd,
    this.onNavigate,
    this.onGameLogTap,
    this.selectedNavIndex = 0,
  });

  @override
  State<DaySceneDialog> createState() => _DaySceneDialogState();
}

class _DaySceneDialogState extends State<DaySceneDialog>
    with TickerProviderStateMixin {
  late Timer _timer;
  late int _remainingSeconds;
  late AnimationController _pulseController;
  int _currentStep =
      0; // 0=Day summary (was morning), 1=Medic?, 2=Voting, 3=Post-Vote Medic?
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _stepKeys = {};
  final Map<String, int> _voteCounts = {};
  String?
  _eliminatedPlayerId; // Track who was just eliminated for post-vote revive
  bool _abilityFabExpanded = false; // Controls FAB menu expansion

  @override
  void initState() {
    super.initState();

    // Calculate timer: 30 seconds per alive player, max 5 minutes if 10+ players
    final aliveCount = widget.gameEngine.players
        .where((p) => p.isActive)
        .length;
    final baseTime = aliveCount * 30;
    _remainingSeconds = (aliveCount >= 10)
        ? (baseTime > 300 ? 300 : baseTime)
        : baseTime;

    // Start countdown timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });

    // Pulse animation for timer
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<String> get _lastNightSummaryLines {
    final summary = widget.gameEngine.lastNightSummary;
    if (summary.isEmpty) return [];
    return summary
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Color _getTimerColor() {
    if (_remainingSeconds > 60) return ClubBlackoutTheme.neonGreen;
    if (_remainingSeconds > 30) return ClubBlackoutTheme.neonOrange;
    return Colors.red;
  }

  void _advanceStep() {
    // Determine max step based on available actions
    final steps = _buildDaySteps();
    final maxStep = steps.length;
    // int maxStep = 2; // Morning + Events + Voting
    // if (_canMedicReviveNightDeaths()) maxStep = 3; // Add pre-vote medic step

    if (_currentStep < maxStep - 1) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentStep++;
      });
      _scrollToStep(_currentStep);
    } else {
      // Check if we just finished voting and medic can revive the eliminated player
      if (_eliminatedPlayerId != null && _canMedicReviveEliminated()) {
        setState(() {
          _currentStep++;
        });
        _scrollToStep(_currentStep);
      } else {
        // Proceed to complete day
        _completeDay();
      }
    }
  }

  void _regressStep() {
    if (_currentStep > 0) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentStep--;
      });
      _scrollToStep(_currentStep);
    }
  }

  void _scrollToStep(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_stepKeys.containsKey(index) &&
          _stepKeys[index]!.currentContext != null) {
        Scrollable.ensureVisible(
          _stepKeys[index]!.currentContext!,
          duration: ClubMotion.page,
          curve: ClubMotion.easeOut,
          alignment: 0.2,
        );
      }
    });
  }

  bool _canMedicReviveNightDeaths() {
    try {
      final medic = widget.gameEngine.players.firstWhere(
        (p) => p.role.id == 'medic' && p.isAlive,
      );
      if (medic.medicChoice != 'RESUSCITATE_ONCE' || medic.hasReviveToken) {
        return false;
      }
      // Only allow reviving players who died in the last night (before today's voting)
      final currentDay = widget.gameEngine.dayCount;
      final nightDeaths = widget.gameEngine.players
          .where(
            (p) =>
                !p.isAlive &&
                p.deathDay != null &&
                p.deathDay == currentDay - 1, // Only last night's deaths
          )
          .toList();
      return nightDeaths.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _canMedicReviveEliminated() {
    try {
      final medic = widget.gameEngine.players.firstWhere(
        (p) => p.role.id == 'medic' && p.isAlive,
      );
      if (medic.medicChoice != 'RESUSCITATE_ONCE' || medic.hasReviveToken) {
        return false;
      }
      // Check if there's an eliminated player from this vote
      return _eliminatedPlayerId != null;
    } catch (_) {
      return false;
    }
  }

  void _completeDay() {
    Navigator.of(context).pop();
    widget.onComplete();
  }

  bool _isOnEventsStep() {
    return _currentStep == 0;
  }

  bool _isOnVotingStep() {
    // Voting follows Morning Report (0)
    int votingIndex = 1;
    if (_canMedicReviveNightDeaths()) votingIndex = 2;
    return _currentStep == votingIndex && _eliminatedPlayerId == null;
  }

  void _confirmVote() {
    // Find player with most votes
    if (_voteCounts.isEmpty || _voteCounts.values.every((v) => v == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No votes have been cast yet!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Find the player(s) with the most votes
    final maxVotes = _voteCounts.values.reduce((a, b) => a > b ? a : b);
    final playersWithMaxVotes = _voteCounts.entries
        .where((entry) => entry.value == maxVotes)
        .map((entry) => entry.key)
        .toList();

    if (playersWithMaxVotes.isEmpty) return;

    // For simplicity, take the first player if there's a tie
    // (In the real game, host would break ties)
    final eliminatedId = playersWithMaxVotes.first;
    final eliminatedPlayer = widget.gameEngine.players.firstWhere(
      (p) => p.id == eliminatedId,
    );

    // Process vote via engine to handle all rules (deflections, retaliations, etc.)
    widget.gameEngine.voteOutPlayer(eliminatedId);

    // Check if the player actually died (Second Wind or Deflection might save them)
    if (eliminatedPlayer.isAlive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Target survived the vote! (Check logs: Deflection or Second Wind?)",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      _advanceStep();
      return;
    }

    // Track for potential medic revive
    setState(() {
      _eliminatedPlayerId = eliminatedId;
    });

    // Check game end state immediately
    if (widget.gameEngine.checkWinConditions() && widget.onGameEnd != null) {
      widget.onGameEnd!(
        widget.gameEngine.winner ?? 'Game Over',
        widget.gameEngine.winMessage ?? 'Game Ended',
      );
      return;
    }

    // Show Reveal Dialog instead of SnackBar
    _showVoteRevealDialog(eliminatedPlayer);
  }

  void _showVoteRevealDialog(Player player) {
    final isDealer = player.role.alliance == 'The Dealers';
    final color = isDealer
        ? ClubBlackoutTheme.neonGreen
        : ClubBlackoutTheme.neonRed;
    final title = isDealer ? "GOTCHA!" : "TRAGEDY!";
    final message = isDealer
        ? "The group successfully eliminated a DEALER!"
        : "The group made a terrible mistake... An INNOCENT was killed.";
    final icon = isDealer
        ? Icons.check_circle_outline
        : Icons.warning_amber_rounded;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 80, color: color),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Hyperwave',
                  fontSize: 48,
                  color: color,
                  shadows: ClubBlackoutTheme.textGlow(color),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "${player.name} was voted out.",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _advanceStep();
                },
                style: ClubBlackoutTheme.neonButtonStyle(color),
                child: const Text("CONTINUE"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _skipVotingPhase() {
    // Host override: skip the vote entirely and move on.
    widget.gameEngine.logAction(
      'Vote Skipped',
      'Host skipped the elimination vote for this day phase.',
    );
    _completeDay();
  }

  @override
  Widget build(BuildContext context) {
    final timerColor = _getTimerColor();

    final steps = _buildDaySteps();
    final visibleCount = _currentStep + 1;

    // Ability detection
    final hasLightweight = widget.gameEngine.players.any(
      (p) => p.role.id == 'lightweight' && p.isActive,
    );
    final hasMessyBitch = widget.gameEngine.players.any(
      (p) => p.role.id == 'messy_bitch',
    );
    final hasClingerToFree = widget.gameEngine.players.any(
      (p) =>
          p.role.id == 'clinger' &&
          p.isActive &&
          p.clingerPartnerId != null &&
          !p.clingerAttackDogUsed,
    );
    final hasSecondWindConversion = widget.gameEngine.players.any(
      (p) =>
          p.role.id == 'second_wind' &&
          p.secondWindPendingConversion &&
          !p.secondWindConverted,
    );
    final hasSilverFox = widget.gameEngine.players.any(
      (p) => p.role.id == 'silver_fox',
    );
    final hasBouncerRoofiChallenge =
        widget.gameEngine.players.any(
          (p) =>
              p.role.id == 'bouncer' && p.isActive && !p.bouncerAbilityRevoked,
        ) &&
        widget.gameEngine.players.any(
          (p) => p.role.id == 'roofi' && p.isAlive && !p.roofiAbilityRevoked,
        );
    final hasAnyAbility =
        hasLightweight ||
        hasMessyBitch ||
        hasClingerToFree ||
        hasSecondWindConversion ||
        hasSilverFox ||
        hasBouncerRoofiChallenge;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        drawer: GameDrawer(
          gameEngine: widget.gameEngine,
          selectedIndex: widget.selectedNavIndex,
          onNavigate: widget.onNavigate ?? (_) {},
          onGameLogTap: widget.onGameLogTap,
        ),
        appBar: AppBar(
          backgroundColor: Colors.black.withOpacity(0.5),
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 26),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Open menu',
            ),
          ),
          title: Row(
            children: [
              Icon(
                Icons.wb_sunny,
                color: ClubBlackoutTheme.neonOrange,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'DAY ${widget.gameEngine.dayCount}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: ClubBlackoutTheme.neonOrange,
                  letterSpacing: 2,
                  shadows: ClubBlackoutTheme.textGlow(
                    ClubBlackoutTheme.neonOrange,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: timerColor.withOpacity(
                      0.1 + (_pulseController.value * 0.1),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: timerColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: timerColor.withOpacity(
                          0.3 + (_pulseController.value * 0.2),
                        ),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer, color: timerColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(_remainingSeconds),
                        style: TextStyle(
                          fontSize: 20,
                          color: timerColor,
                          fontWeight: FontWeight.bold,
                          shadows: ClubBlackoutTheme.textGlow(timerColor),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Image.asset(
                "Backgrounds/Club Blackout App Background.png",
                fit: BoxFit.cover,
                errorBuilder: (c, o, s) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black,
                        const Color(0xFF2e1a1a),
                        Colors.black,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Content
            SafeArea(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 24, bottom: 200),
                itemCount: visibleCount,
                itemBuilder: (context, index) {
                  _stepKeys.putIfAbsent(index, () => GlobalKey());
                  final key = _stepKeys[index]!;

                  return Container(key: key, child: steps[index]);
                },
              ),
            ),

            // Bottom action bar
            Positioned(
              bottom: 24,
              left: 16, // more edge hugging for mobile
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button (conditionally visible)
                  if (_currentStep > 0)
                    IconButton.filled(
                      onPressed: _regressStep,
                      icon: const Icon(Icons.arrow_back),
                      style: IconButton.styleFrom(
                        backgroundColor: ClubBlackoutTheme.neonBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(
                          12,
                        ), // smaller tap target padding
                      ),
                    )
                  else
                    const SizedBox(width: 48), // Balancing spacer
                  // Ability FAB button (center-ish or dynamic spacer)
                  if (hasAnyAbility)
                    FloatingActionButton(
                      heroTag:
                          'day_ability_fab', // Unique tag to avoid hero conflicts
                      onPressed: () => setState(
                        () => _abilityFabExpanded = !_abilityFabExpanded,
                      ),
                      backgroundColor: ClubBlackoutTheme.neonPurple,
                      mini:
                          true, // Smaller on mobile? or keep standard but be aware of space
                      child: Icon(
                        _abilityFabExpanded
                            ? Icons.close
                            : Icons.settings_remote,
                        size: 20,
                      ),
                    ),

                  // Next / Complete Button
                  // Use Flexible/Expanded to prevent overflow against the other buttons
                  if (!_isOnVotingStep())
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: FilledButton(
                          onPressed: _advanceStep,
                          style:
                              ClubBlackoutTheme.neonButtonStyle(
                                ClubBlackoutTheme.neonOrange,
                              ).copyWith(
                                padding: MaterialStateProperty.all(
                                  const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                          child: Text(
                            _currentStep >= steps.length - 1
                                ? 'COMPLETE'
                                : 'NEXT',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    )
                  else
                    const Spacer(), // Just fill space if button is hidden
                ],
              ),
            ),

            // FAB Menu overlay
            if (_abilityFabExpanded) _buildAbilityFabMenu(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDaySteps() {
    List<Widget> steps = [];

    // Step 0: Night Events (MORNING REPORT)
    steps.add(_buildEventsCard());

    // Optional: Medic Revive - Night Deaths
    if (_canMedicReviveNightDeaths()) {
      steps.add(_buildMedicReviveCard(isPostVote: false));
    }

    // Next: Voting
    steps.add(_buildVotingCard());

    // Optional: Medic Revive - Just Eliminated Player
    if (_eliminatedPlayerId != null && _canMedicReviveEliminated()) {
      steps.add(_buildMedicReviveCard(isPostVote: true));
    }

    return steps;
  }

  Widget _buildEventsCard() {
    final isActive = _isOnEventsStep();
    final summaryLines = _lastNightSummaryLines;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ClubBlackoutTheme.neonBlue.withOpacity(isActive ? 0.8 : 0.3),
          width: isActive ? 3 : 2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: ClubBlackoutTheme.neonBlue.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withOpacity(0.9),
                  const Color(0xFF1a1a2e).withOpacity(0.8),
                  ClubBlackoutTheme.neonBlue.withOpacity(0.1),
                ],
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.event_note,
                      color: ClubBlackoutTheme.neonBlue,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "MORNING REPORT",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: ClubBlackoutTheme.neonBlue,
                        letterSpacing: 1.5,
                        shadows: ClubBlackoutTheme.textGlow(
                          ClubBlackoutTheme.neonBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Events list
                if (summaryLines.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'A quiet night...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                else
                  ...summaryLines.map((line) => _buildSummaryLine(line)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryLine(String line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 8, color: Colors.white70),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              line,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicReviveCard({required bool isPostVote}) {
    final stepIndex = isPostVote ? (_canMedicReviveNightDeaths() ? 4 : 3) : 2;
    final isActive = _currentStep == stepIndex;

    // Get the appropriate list of dead players
    final List<Player> deadPlayers;
    final String title;
    final String description;

    if (isPostVote && _eliminatedPlayerId != null) {
      // Post-vote: Only show the just-eliminated player
      deadPlayers = widget.gameEngine.players
          .where((p) => p.id == _eliminatedPlayerId)
          .toList();
      title = 'MEDIC: REVIVE ELIMINATED PLAYER';
      description =
          'The player was just voted out. You can bring them back to life immediately. This ability can only be used ONCE per game.';
    } else {
      // Pre-vote: Show players who died last night
      final currentDay = widget.gameEngine.dayCount;
      deadPlayers = widget.gameEngine.players
          .where(
            (p) =>
                !p.isAlive &&
                p.deathDay != null &&
                p.deathDay == currentDay - 1, // Only last night's deaths
          )
          .toList();
      title = 'MEDIC: REVIVE PLAYER';
      description =
          'Select a player who died LAST NIGHT to bring back to life. This ability can only be used ONCE per game and only on players who died in the most recent night phase.';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ClubBlackoutTheme.neonGreen.withOpacity(isActive ? 0.8 : 0.3),
          width: isActive ? 3 : 2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: ClubBlackoutTheme.neonGreen.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withOpacity(0.9),
                  const Color(0xFF0a1a0a).withOpacity(0.8),
                  ClubBlackoutTheme.neonGreen.withOpacity(0.1),
                ],
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.medical_services,
                      color: ClubBlackoutTheme.neonGreen,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: ClubBlackoutTheme.neonGreen,
                          letterSpacing: 1.5,
                          shadows: ClubBlackoutTheme.textGlow(
                            ClubBlackoutTheme.neonGreen,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                ...deadPlayers.map(
                  (player) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _revivePlayer(player),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ClubBlackoutTheme.neonGreen.withOpacity(
                                0.5,
                              ),
                            ),
                            gradient: LinearGradient(
                              colors: [
                                ClubBlackoutTheme.neonGreen.withOpacity(0.15),
                                ClubBlackoutTheme.neonGreen.withOpacity(0.05),
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person,
                                color: ClubBlackoutTheme.neonGreen,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  player.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                player.role.name,
                                style: TextStyle(
                                  color: ClubBlackoutTheme.neonGreen
                                      .withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _revivePlayer(Player player) {
    final medic = widget.gameEngine.players.firstWhere(
      (p) => p.role.id == 'medic' && p.isAlive,
    );

    player.isAlive = true;
    player.deathDay = null; // Clear death day when revived
    medic.hasReviveToken = true;

    widget.gameEngine.logAction(
      'Medic Revive',
      '${medic.name} revived ${player.name} during the day!',
    );

    setState(() {
      _advanceStep(); // Move to voting after revive
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.medical_services, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '🚑 ${player.name} has been REVIVED!',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: ClubBlackoutTheme.neonGreen,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildVotingCard() {
    final stepIndex = _canMedicReviveNightDeaths() ? 3 : 2;
    final isActive = _currentStep == stepIndex;
    final alivePlayers = sortedPlayersByDisplayName(
      widget.gameEngine.players
          .where((p) => p.isAlive && p.role.id != 'host')
          .toList(),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ClubBlackoutTheme.neonRed.withOpacity(isActive ? 0.8 : 0.3),
          width: isActive ? 3 : 2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: ClubBlackoutTheme.neonRed.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withOpacity(0.9),
                  const Color(0xFF1a0a0a).withOpacity(0.8),
                  ClubBlackoutTheme.neonRed.withOpacity(0.1),
                ],
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.how_to_vote,
                      color: ClubBlackoutTheme.neonRed,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ELIMINATION VOTE',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: ClubBlackoutTheme.neonRed,
                          letterSpacing: 1.5,
                          shadows: ClubBlackoutTheme.textGlow(
                            ClubBlackoutTheme.neonRed,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Players discuss and vote to eliminate someone from the game. Host facilitates discussion.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Cast votes for each player:',
                  style: TextStyle(
                    color: ClubBlackoutTheme.neonRed,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                ...alivePlayers.map((player) {
                  final votes = _voteCounts[player.id] ?? 0;
                  final isSilenced =
                      player.silencedDay != null &&
                      player.silencedDay == widget.gameEngine.dayCount;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Opacity(
                      opacity: isSilenced ? 0.5 : 1.0,
                      child: Container(
                        // Wrapped in Container for Better styling
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: PlayerTile(
                                player: player,
                                gameEngine: widget.gameEngine,
                                voteCount: votes,
                                isCompact:
                                    false, // Use full HostPlayerStatusCard for detailed chips
                                onTap:
                                    null, // Disable tap on tile itself to avoid confusion
                              ),
                            ),
                            const SizedBox(width: 8), // Gap
                            if (!isSilenced) ...[
                              IconButton(
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: ClubBlackoutTheme.neonRed,
                                  size: 24,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _voteCounts[player.id] = (votes > 0)
                                        ? votes - 1
                                        : 0;
                                  });
                                },
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: ClubBlackoutTheme.neonGreen,
                                  size: 24,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _voteCounts[player.id] = votes + 1;
                                  });
                                },
                              ),
                            ] else
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.block, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 16),
                if (isActive)
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      // Confirm vote (only enabled when votes exist)
                      if (_voteCounts.values.any((count) => count > 0))
                        FilledButton.icon(
                          onPressed: _confirmVote,
                          style:
                              ClubBlackoutTheme.neonButtonStyle(
                                ClubBlackoutTheme.neonRed,
                              ).copyWith(
                                padding: MaterialStateProperty.all(
                                  const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                          icon: const Icon(Icons.check_circle, size: 20),
                          label: const Text(
                            'CONFIRM VOTE & ELIMINATE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: _skipVotingPhase,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('SKIP VOTING (NO ELIMINATION)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.5),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _regressStep,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('BACK TO DISCUSSION'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildStatBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // FAB menu for character abilities
  Widget _buildAbilityFabMenu() {
    return Positioned(
      bottom: 100,
      right: 20,
      child: Column(
        children: [
          if (widget.gameEngine.players.any(
                (p) =>
                    p.role.id == 'bouncer' &&
                    p.isActive &&
                    !p.bouncerAbilityRevoked,
              ) &&
              widget.gameEngine.players.any(
                (p) =>
                    p.role.id == 'roofi' && p.isAlive && !p.roofiAbilityRevoked,
              ))
            FloatingActionButton(
              onPressed: _showBouncerRoofiChallenge,
              backgroundColor: ClubBlackoutTheme.neonOrange,
              child: const Icon(Icons.gavel),
            ),
          const SizedBox(height: 10),
          if (widget.gameEngine.players.any(
            (p) => p.role.id == 'lightweight' && p.isActive,
          ))
            FloatingActionButton(
              onPressed: _showTabooList,
              backgroundColor: ClubBlackoutTheme.neonPurple,
              child: const Icon(Icons.block),
            ),
          const SizedBox(height: 10),
          if (widget.gameEngine.players.any(
            (p) => p.role.id == 'messy_bitch' && p.isActive,
          ))
            FloatingActionButton(
              onPressed: _showMessyBitchAbility,
              backgroundColor: ClubBlackoutTheme.neonGreen,
              child: const Icon(Icons.campaign),
            ),
          const SizedBox(height: 10),
          if (widget.gameEngine.players.any(
            (p) =>
                p.role.id == 'clinger' &&
                p.isActive &&
                p.clingerPartnerId != null &&
                !p.clingerAttackDogUsed,
          ))
            FloatingActionButton(
              onPressed: _showAttackDogConversion,
              backgroundColor: const Color(0xFFFFFF00),
              child: const Icon(Icons.pets, color: Colors.black),
            ),
          const SizedBox(height: 10),
          if (widget.gameEngine.players.any(
            (p) =>
                p.role.id == 'second_wind' &&
                p.secondWindPendingConversion &&
                !p.secondWindConverted,
          ))
            FloatingActionButton(
              onPressed: _showSecondWindConversion,
              backgroundColor: ClubBlackoutTheme.neonBlue,
              child: const Icon(Icons.autorenew),
            ),
          const SizedBox(height: 10),
          if (widget.gameEngine.players.any(
            (p) =>
                p.role.id == 'silver_fox' &&
                p.isActive &&
                !p.silverFoxAbilityUsed,
          ))
            FloatingActionButton(
              onPressed: _showSilverFoxAbility,
              backgroundColor: Colors.grey,
              child: const Icon(Icons.auto_awesome),
            ),
        ],
      ),
    );
  }

  // Bouncer vs Roofi challenge
  void _showBouncerRoofiChallenge() {
    try {
      final bouncer = widget.gameEngine.players.firstWhere(
        (p) => p.role.id == 'bouncer' && p.isActive && !p.bouncerAbilityRevoked,
      );
      final alivePlayers = sortedPlayersByDisplayName(
        widget.gameEngine.players.where((p) => p.isActive).toList(),
      );

      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ClubBlackoutTheme.neonOrange, width: 2),
              boxShadow: [
                BoxShadow(
                  color: ClubBlackoutTheme.neonOrange.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.gavel,
                  size: 60,
                  color: ClubBlackoutTheme.neonOrange,
                ),
                const SizedBox(height: 16),
                Text(
                  'BOUNCER VS ROOFI CHALLENGE',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: ClubBlackoutTheme.neonOrange,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Select the player the Bouncer accuses of being the Roofi.',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: ListView(
                    children: alivePlayers
                        .map(
                          (player) => PlayerTile(
                            player: player,
                            gameEngine: widget.gameEngine,
                            isCompact: false, // Show full details
                            onTap: () {
                              Navigator.pop(context);
                              _resolveBouncerRoofiChallenge(bouncer, player);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error showing bouncer vs roofi challenge: $e');
    }
  }

  void _resolveBouncerRoofiChallenge(Player bouncer, Player accused) {
    final isCorrect = accused.role.id == 'roofi';
    setState(() {
      if (isCorrect) {
        accused.roofiAbilityRevoked = true;
        widget.gameEngine.logAction(
          'Roofi Exposed',
          '${bouncer.name} correctly identified ${accused.name} as the Roofi. Roofi ability revoked.',
        );
      } else {
        bouncer.bouncerAbilityRevoked = true;
        widget.gameEngine.logAction(
          'Bouncer Penalized',
          '${bouncer.name} incorrectly accused ${accused.name}. Bouncer loses ID check ability permanently.',
        );
      }
    });

    final color = isCorrect ? ClubBlackoutTheme.neonGreen : Colors.red;
    final icon = isCorrect ? Icons.check_circle : Icons.block;
    final message = isCorrect
        ? 'Correct! ${accused.name} was the Roofi — ability revoked.'
        : 'Wrong guess. ${bouncer.name} loses the ID check permanently.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Taboo List for Lightweight
  void _showTabooList() {
    try {
      final lightweight = widget.gameEngine.players.firstWhere(
        (p) => p.role.id == 'lightweight' && p.isActive,
      );

      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ClubBlackoutTheme.neonPurple, width: 2),
              boxShadow: [
                BoxShadow(
                  color: ClubBlackoutTheme.neonPurple.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.block,
                  size: 50,
                  color: ClubBlackoutTheme.neonPurple,
                ),
                const SizedBox(height: 16),
                Text(
                  'TABOO LIST',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: ClubBlackoutTheme.neonPurple,
                    shadows: ClubBlackoutTheme.textGlow(
                      ClubBlackoutTheme.neonPurple,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lightweight.name,
                  style: const TextStyle(fontSize: 18, color: Colors.white70),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 300,
                  child: SizedBox(
                    height: 300,
                    child: ListView(
                      children: lightweight.tabooNames.map((word) {
                        try {
                          final target = widget.gameEngine.players.firstWhere(
                            (p) => p.name == word,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: PlayerTile(
                              player: target,
                              gameEngine: widget.gameEngine,
                              isCompact: false, // detailed tile with status
                            ),
                          );
                        } catch (e) {
                          return Card(
                            color: ClubBlackoutTheme.neonPurple.withOpacity(
                              0.1,
                            ),
                            child: ListTile(
                              title: Text(
                                word,
                                style: TextStyle(
                                  color: ClubBlackoutTheme.neonPurple,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          );
                        }
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: ClubBlackoutTheme.neonButtonStyle(
                    ClubBlackoutTheme.neonPurple,
                  ),
                  child: const Text('CLOSE'),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error showing taboo list: $e");
    }
  }

  // Messy Bitch rumor mill
  void _showMessyBitchAbility() {
    final rumorPlayers = widget.gameEngine.players
        .where((p) => p.hasRumour)
        .toList();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ClubBlackoutTheme.neonGreen, width: 2),
            boxShadow: [
              BoxShadow(
                color: ClubBlackoutTheme.neonGreen.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.campaign,
                size: 50,
                color: ClubBlackoutTheme.neonGreen,
              ),
              const SizedBox(height: 16),
              Text(
                'RUMOUR MILL',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: ClubBlackoutTheme.neonGreen,
                  shadows: ClubBlackoutTheme.textGlow(
                    ClubBlackoutTheme.neonGreen,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (rumorPlayers.isEmpty)
                const Text(
                  'No rumors spreading yet...',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                )
              else
                SizedBox(
                  height: 300,
                  child: ListView(
                    children: rumorPlayers
                        .map(
                          (player) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: PlayerTile(
                              player: player,
                              gameEngine: widget.gameEngine,
                              isCompact:
                                  false, // Show full status chips including RUMOUR
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: ClubBlackoutTheme.neonButtonStyle(
                  ClubBlackoutTheme.neonGreen,
                ),
                child: const Text('CLOSE'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Attack Dog conversion for Clinger
  void _showAttackDogConversion() {
    try {
      final clinger = widget.gameEngine.players.firstWhere(
        (p) =>
            p.role.id == 'clinger' &&
            p.isActive &&
            p.clingerPartnerId != null &&
            !p.clingerAttackDogUsed,
      );

      final obsession = widget.gameEngine.players.firstWhere(
        (p) => p.id == clinger.clingerPartnerId,
      );

      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFFF00), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFFF00).withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pets, size: 60, color: Color(0xFFFFFF00)),
                const SizedBox(height: 16),
                const Text(
                  'ATTACK DOG CONVERSION',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFFF00),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Did ${obsession.name} call ${clinger.name} a "controller"?',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _convertToAttackDog(clinger);
                      },
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(
                          const Color(0xFFFFFF00).withOpacity(0.2),
                        ),
                        foregroundColor: MaterialStateProperty.all(
                          const Color(0xFFFFFF00),
                        ),
                        side: MaterialStateProperty.all(
                          const BorderSide(
                            color: Color(0xFFFFFF00),
                            width: 1.5,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('YES, CONVERT'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error showing attack dog conversion: $e");
    }
  }

  void _convertToAttackDog(Player clinger) {
    clinger.clingerFreedAsAttackDog = true;
    widget.gameEngine.logAction(
      'Attack Dog Conversion',
      '${clinger.name} has been freed from their obsession and is now an attack dog!',
    );

    final killTargets = sortedPlayersByDisplayName(
      widget.gameEngine.players
          .where((p) => p.isActive && p.id != clinger.id && !p.joinsNextNight)
          .toList(),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFFF00), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFFF00).withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.gpp_bad, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                '${clinger.name} IS NOW AN ATTACK DOG',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFFF00),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 300,
                child: ListView(
                  children: killTargets
                      .map(
                        (player) => PlayerTile(
                          player: player,
                          gameEngine: widget.gameEngine,
                          onTap: () {
                            Navigator.pop(context);
                            _executeAttackDogKill(clinger, player);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _executeAttackDogKill(Player clinger, Player victim) {
    setState(() {
      clinger.clingerAttackDogUsed = true;
      victim.kill(widget.gameEngine.dayCount);
      widget.gameEngine.logAction(
        'Attack Dog Kill',
        '${clinger.name} (Attack Dog) killed ${victim.name}!',
      );
    });
  }

  // Second Wind conversion
  void _showSecondWindConversion() {
    try {
      final secondWind = widget.gameEngine.players.firstWhere(
        (p) =>
            p.role.id == 'second_wind' &&
            p.secondWindPendingConversion &&
            !p.secondWindConverted,
      );

      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ClubBlackoutTheme.neonBlue, width: 2),
              boxShadow: [
                BoxShadow(
                  color: ClubBlackoutTheme.neonBlue.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.autorenew,
                  size: 60,
                  color: ClubBlackoutTheme.neonBlue,
                ),
                const SizedBox(height: 16),
                const Text(
                  'SECOND WIND CONVERSION',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '${secondWind.name} survived an elimination! Convert to criminal?',
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _executeSecondWindConversion(secondWind);
                      },
                      style: ClubBlackoutTheme.neonButtonStyle(
                        ClubBlackoutTheme.neonBlue,
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('CONVERT'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error showing second wind conversion: $e");
    }
  }

  void _executeSecondWindConversion(Player secondWind) {
    setState(() {
      secondWind.secondWindConverted = true;
      secondWind.secondWindPendingConversion = false;
      widget.gameEngine.logAction(
        'Second Wind Conversion',
        '${secondWind.name} has converted to the criminal alliance!',
      );
    });
  }

  // Silver Fox ability
  void _showSilverFoxAbility() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 50, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'SILVER FOX ABILITY',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Silver Fox ability info will appear here',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(
                    Colors.grey.withOpacity(0.2),
                  ),
                  foregroundColor: MaterialStateProperty.all(Colors.grey),
                ),
                child: const Text('CLOSE'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
