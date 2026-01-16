// ignore_for_file: use_build_context_synchronously, unnecessary_null_comparison, invalid_null_aware_operator, prefer_interpolation_to_compose_strings

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/rendering.dart';
import 'dart:math';
import 'package:club_blackout/ui/widgets/role_card_widget.dart';
import '../../logic/game_engine.dart';
import '../../logic/game_state.dart';
import '../../logic/ability_system.dart';
import '../../models/script_step.dart';
import '../../models/player.dart';
import '../../models/role.dart';
import '../styles.dart';
import '../utils/player_sort.dart';
import '../widgets/game_drawer.dart';
import '../widgets/day_scene_dialog.dart';
import '../widgets/interactive_script_card.dart';
import '../widgets/phase_card.dart';
import '../widgets/player_tile.dart';
import '../widgets/role_reveal_widget.dart';

class GameScreen extends StatefulWidget {
  final GameEngine gameEngine;

  const GameScreen({super.key, required this.gameEngine});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _stepKeys = {};
  int _lastScriptIndex = 0;
  final Set<String> _currentSelection = {};
  final Map<String, int> _voteCounts = {};
  bool _rumourMillExpanded = false;
  bool _abilityFabExpanded = false;
  final Set<String> _shownAbilityNotifications =
      {}; // Track shown notifications
  final Map<String, bool> _abilityLastState =
      {}; // Track last seen activation state
  bool _abilityNotificationsPrimed =
      false; // Avoid firing snacks before first activation edge
  Timer? _scrollDebounceTimer;

  @override
  void initState() {
    super.initState();
    _lastScriptIndex = widget.gameEngine.currentScriptIndex;

    widget.gameEngine.onPhaseChanged = (oldPhase, newPhase) {
      if (mounted) {
        setState(() {});
        _scrollToStep(widget.gameEngine.currentScriptIndex);
      }
    };

    widget.gameEngine.onClingerDoubleDeath = (clingerName, obsessionName) {
      if (mounted) {
        _showClingerDoubleDeathDialog(clingerName, obsessionName);
      }
    };

    widget.gameEngine.onClubManagerReveal = (target) {
      // Ensure specific target role reveal
      if (mounted) {
        showRoleReveal(
          context,
          target.role,
          target.name,
          subtitle: 'Club Manager Investigation',
        );
      }
    };
  }

  @override
  void dispose() {
    _scrollDebounceTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToStep(int index, {double alignment = 0.0, bool gentle = false}) {
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 70), () {
      if (!mounted) return;
      final key = _stepKeys[index];
      final ctx = key?.currentContext;
      if (ctx != null && _scrollController.hasClients) {
        final box = ctx.findRenderObject();
        final viewport = box != null ? RenderAbstractViewport.of(box) : null;
        if (box is RenderBox && viewport != null) {
          final offset = viewport.getOffsetToReveal(box, alignment).offset;
          final current = _scrollController.offset;
          final distance = (offset - current).abs();
          final clampedOffset = offset.clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          );
          final duration = Duration(milliseconds: gentle ? 200 : 280);
          if (distance < 200) {
            _scrollController.animateTo(
              clampedOffset,
              duration: duration,
              curve: Curves.easeOutCubic,
            );
          } else {
            _scrollController.animateTo(
              clampedOffset,
              duration: duration,
              curve: Curves.easeInOut,
            );
          }
          return;
        }
      }

      // Fallback if no context yet
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final fallbackKey = _stepKeys[index];
        final fallbackCtx = fallbackKey?.currentContext;
        if (fallbackCtx != null) {
          Scrollable.ensureVisible(
            fallbackCtx,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            alignment: alignment,
          );
        } else if (index == widget.gameEngine.scriptQueue.length - 1) {
          _scrollToBottom(durationMs: gentle ? 220 : 320);
        }
      });
    });
  }

  void _prewarmNextStepScroll() {
    final nextIndex = widget.gameEngine.currentScriptIndex + 1;
    final steps = widget.gameEngine.scriptQueue;
    if (nextIndex >= steps.length) return;
    _stepKeys.putIfAbsent(nextIndex, () => GlobalKey());
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToStep(nextIndex, alignment: 0.1, gentle: true);
    });
  }

  void _scrollToBottom({int durationMs = 500}) {
    if (_scrollController.hasClients) {
      // Add extra offset to really push it up if possible
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: durationMs),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _checkScroll() {
    if (widget.gameEngine.currentScriptIndex != _lastScriptIndex) {
      final newIndex = widget.gameEngine.currentScriptIndex;
      _lastScriptIndex = newIndex;
      // Force scroll on both forward and backward navigation
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => _scrollToStep(newIndex),
      );
    }
  }

  void _advanceScript() {
    final step = widget.gameEngine.currentScriptStep;
    if (step != null &&
        (step.actionType == ScriptActionType.selectPlayer ||
            step.actionType == ScriptActionType.selectTwoPlayers)) {
      if (step.id == 'day_vote' && _voteCounts.isNotEmpty) {
        final votedPlayers = _voteCounts.entries
            .where((e) => e.value >= 2)
            .toList();
        if (votedPlayers.isNotEmpty) {
          votedPlayers.sort((a, b) => b.value.compareTo(a.value));
          final mostVoted = votedPlayers.first;
          final maxVotes = mostVoted.value;
          final topVoters = votedPlayers
              .where((e) => e.value == maxVotes)
              .toList();

          if (topVoters.length > 1) {
            // Tie handled silently (logged via engine if needed)
            widget.gameEngine.logAction(
              "Voting",
              "Vote tie! No one is eliminated.",
            );

            _voteCounts.clear();
            widget.gameEngine.advanceScript();
            setState(() => _currentSelection.clear());
            _scrollToBottom();
            _prewarmNextStepScroll();
            return;
          }
          final playerId = mostVoted.key;
          final player = widget.gameEngine.players.firstWhere(
            (p) => p.id == playerId,
          );
          final wasDealer = widget.gameEngine.voteOutPlayer(playerId);
          _voteCounts.clear();
          Player? victim = player;

          // Check if victim survived (e.g. Second Wind)
          // If they are alive and have pending conversion, it's Second Wind.
          final bool survivedVote =
              victim.isAlive && victim.secondWindPendingConversion;

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: survivedVote
                      ? Colors.amber
                      : (wasDealer
                            ? ClubBlackoutTheme.neonGreen.withOpacity(0.6)
                            : ClubBlackoutTheme.neonRed.withOpacity(0.6)),
                  width: 2,
                ),
              ),
              title: Row(
                children: [
                  Icon(
                    survivedVote
                        ? Icons.auto_awesome
                        : (wasDealer ? Icons.check_circle : Icons.cancel),
                    color: survivedVote
                        ? Colors.amber
                        : (wasDealer
                              ? ClubBlackoutTheme.neonGreen
                              : ClubBlackoutTheme.neonRed),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'VOTE RESULT',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (survivedVote) ...[
                    const Text(
                      "SECOND WIND!",
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "${victim?.name ?? 'The target'} refuses to die!",
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "The Dealers must decide their fate.",
                      style: TextStyle(color: Colors.amber),
                    ),
                  ] else ...[
                    Text(
                      player.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      wasDealer
                          ? 'The group has successfully eliminated a Dealer!'
                          : 'The Party Animals have lost an innocent member.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],

                  // ADDED: Reactive Role Notification (Only if they actually died)
                  if (!survivedVote &&
                      victim != null &&
                      (victim.role.id == 'tea_spiller' ||
                          victim.role.id == 'predator' ||
                          victim.role.id == 'drama_queen')) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        border: Border.all(color: Colors.amber),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.amber,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "REACTIVE ROLE",
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "This player was a ${victim?.role.name ?? 'mystery role'}.\nOpen the Action Menu (FAB) immediately to trigger their retaliation ability!",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (widget.gameEngine.checkWinConditions()) {
                      final winner = widget.gameEngine.winner;
                      final message = widget.gameEngine.winMessage;
                      _showGameEndDialog(winner!, message!);
                    } else {
                      widget.gameEngine.advanceScript();
                      setState(() => _currentSelection.clear());
                      _scrollToBottom();
                      _prewarmNextStepScroll();
                    }
                  },
                  style: ClubBlackoutTheme.neonButtonStyle(
                    wasDealer
                        ? ClubBlackoutTheme.neonGreen
                        : ClubBlackoutTheme.neonRed,
                  ),
                  child: const Text('CONTINUE'),
                ),
              ],
            ),
          );
          return;
        }
      }

      _executeNightAction(step);
    }

    widget.gameEngine.advanceScript();
    setState(() {
      _currentSelection.clear();
    });
    _scrollToBottom();
    _prewarmNextStepScroll();
  }

  void _executeNightAction(ScriptStep step) {
    if (_currentSelection.isEmpty) return;

    if (step.actionType == ScriptActionType.selectTwoPlayers) {
      widget.gameEngine.nightActions[step.id] = _currentSelection.toList();
    } else {
      widget.gameEngine.nightActions[step.id] = _currentSelection.first;

      // Bouncer ID check - show result dialog
      if (step.roleId == 'bouncer' &&
          step.actionType == ScriptActionType.selectPlayer) {
        final targetId = _currentSelection.first;
        final target = widget.gameEngine.players.firstWhere(
          (p) => p.id == targetId,
        );

        if (target.role.id == 'minor' && !target.minorHasBeenIDd) {
          target.minorHasBeenIDd = true;
          widget.gameEngine.logAction(
            'Bouncer Check',
            'Bouncer checked The Minor (${target.name}). Minor loses immunity.',
          );
        }

        // Dealer or criminal alliance = nod (yes)
        final isDealerAlly =
            target.role.alliance == 'criminal' || target.role.id == 'dealer';
        _showBouncerConfirmation(target, isDealerAlly);
      } else if (step.id == 'creep_act') {
        final targetId = _currentSelection.first;
        final target = widget.gameEngine.players.firstWhere(
          (p) => p.id == targetId,
        );
        _showCreepConfirmation(target);
      } else if (step.id == 'clinger_obsession') {
        final targetId = _currentSelection.first;
        final target = widget.gameEngine.players.firstWhere(
          (p) => p.id == targetId,
        );
        _showClingerConfirmation(target);
      } else if (step.id == 'sober_act') {
        final targetId = _currentSelection.first;
        final target = widget.gameEngine.players.firstWhere(
          (p) => p.id == targetId,
        );
        target.soberSentHome = true;
        target.soberAbilityUsed = true;
        widget.gameEngine.logAction(
          'Sober',
          '${target.name} was sent home and will not participate tonight',
        );

        // Rebuild script immediately to remove the target's turn
        widget.gameEngine.rebuildNightScript();
      } else if (step.roleId == 'club_manager') {
        final targetId = _currentSelection.first;
        final target = widget.gameEngine.players.firstWhere(
          (p) => p.id == targetId,
        );
        widget.gameEngine.logAction(
          'Club Manager',
          'Club Manager viewed ${target.name}\'s role.',
        );
        // Show reveal immediately
        showRoleReveal(
          context,
          target.role,
          target.name,
          subtitle: 'Club Manager Investigation',
        );
      }
    }
  }

  void _onPlayerSelected(String id) {
    final step = widget.gameEngine.currentScriptStep;
    if (step == null) return;

    setState(() {
      if (step.actionType == ScriptActionType.selectTwoPlayers) {
        if (_currentSelection.contains(id)) {
          _currentSelection.remove(id);
        } else if (_currentSelection.length < 2) {
          _currentSelection.add(id);
        }
      } else {
        _currentSelection.clear();
        _currentSelection.add(id);
      }
    });
  }

  void _showBouncerConfirmation(Player target, bool isDealerAlly) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDealerAlly
                ? ClubBlackoutTheme.neonGreen
                : ClubBlackoutTheme.neonRed,
            width: 3,
          ),
        ),
        backgroundColor: Colors.black,
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(22),
            boxShadow: ClubBlackoutTheme.boxGlow(
              isDealerAlly
                  ? ClubBlackoutTheme.neonGreen
                  : ClubBlackoutTheme.neonRed,
              intensity: 2.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDealerAlly ? Icons.check_circle : Icons.cancel,
                color: isDealerAlly
                    ? ClubBlackoutTheme.neonGreen
                    : ClubBlackoutTheme.neonRed,
                size: 60,
                shadows: ClubBlackoutTheme.iconGlow(
                  isDealerAlly
                      ? ClubBlackoutTheme.neonGreen
                      : ClubBlackoutTheme.neonRed,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isDealerAlly ? 'DEALER CONFIRMED' : 'NOT A DEALER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Hyperwave',
                  fontSize: 32,
                  color: isDealerAlly
                      ? ClubBlackoutTheme.neonGreen
                      : ClubBlackoutTheme.neonRed,
                  shadows: ClubBlackoutTheme.textGlow(
                    isDealerAlly
                        ? ClubBlackoutTheme.neonGreen
                        : ClubBlackoutTheme.neonRed,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                target.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isDealerAlly
                    ? 'Is a Dealer or an ally of the Dealers.'
                    : 'Is not a known associate of the Dealers.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              if (target.role.id == 'minor') ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    border: Border.all(color: Colors.redAccent),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.redAccent,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "MINOR ID CHECKED",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Immunity stripped! The Minor is now vulnerable to Dealer attacks.",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: isDealerAlly
                      ? ClubBlackoutTheme.neonGreen
                      : ClubBlackoutTheme.neonRed,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.all(16),
                  shape: const CircleBorder(),
                ),
                child: const Icon(Icons.check, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreepConfirmation(Player target) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RoleCardWidget(role: target.role, playerName: target.name),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: target.role.color,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.all(16),
                  shape: const CircleBorder(),
                ),
                child: const Icon(Icons.check, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClingerConfirmation(Player target) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RoleCardWidget(role: target.role, playerName: target.name),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ClubBlackoutTheme.neonPink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ClubBlackoutTheme.neonPink.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'You are now bound to this player. You will vote exactly as they vote. If they die, you die.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: ClubBlackoutTheme.neonPink,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.all(16),
                  shape: const CircleBorder(),
                ),
                child: const Icon(Icons.check, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGameEndDialog(String winner, String message) {
    widget.gameEngine.currentPhase = GamePhase.endGame;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: winner.toLowerCase() == 'criminals'
                ? ClubBlackoutTheme.neonRed
                : ClubBlackoutTheme.neonGreen,
            width: 3,
          ),
        ),
        title: Text(
          winner.toUpperCase() + " WIN!",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Hyperwave',
            fontSize: 42,
            color: winner.toLowerCase() == 'criminals'
                ? ClubBlackoutTheme.neonRed
                : ClubBlackoutTheme.neonGreen,
            shadows: ClubBlackoutTheme.textGlow(
              winner.toLowerCase() == 'criminals'
                  ? ClubBlackoutTheme.neonRed
                  : ClubBlackoutTheme.neonGreen,
            ),
          ),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 18),
        ),
        actions: [
          Center(
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Leave game screen
              },
              style: ClubBlackoutTheme.neonButtonStyle(
                winner.toLowerCase() == 'criminals'
                    ? ClubBlackoutTheme.neonRed
                    : ClubBlackoutTheme.neonGreen,
              ),
              child: const Text("RETURN TO LOBBY"),
            ),
          ),
        ],
      ),
    );
  }

  void _showClingerDoubleDeathDialog(String clingerName, String obsessionName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.orange, width: 2),
        ),
        title: const Text(
          "DOUBLE DEATH!",
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "$clingerName's obsession, $obsessionName, has died. As a Clinger, $clingerName dies with them!",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: ClubBlackoutTheme.neonButtonStyle(Colors.orange),
            child: const Text("I UNDERSTAND"),
          ),
        ],
      ),
    );
  }

  void _showMessyBitchVictoryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE6E6FA), width: 3),
        ),
        title: const Text(
          "MESSY BITCH WINS!",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Hyperwave',
            fontSize: 32,
            color: Color(0xFFE6E6FA),
          ),
        ),
        content: const Text(
          "Every single alive player has a rumour. The Messy Bitch has successfully ruined the party!",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
        actions: [
          Center(
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ClubBlackoutTheme.neonButtonStyle(const Color(0xFFE6E6FA)),
              child: const Text("RETURN TO LOBBY"),
            ),
          ),
        ],
      ),
    );
  }

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
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 20),
                if (lightweight.tabooNames.isEmpty)
                  const Text(
                    'No taboo names assigned yet.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white54,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: SingleChildScrollView(
                      child: Column(
                        children: lightweight.tabooNames
                            .map(
                              (name) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: ClubBlackoutTheme.neonPurple
                                        .withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                  gradient: LinearGradient(
                                    colors: [
                                      ClubBlackoutTheme.neonPurple.withOpacity(
                                        0.2,
                                      ),
                                      ClubBlackoutTheme.neonPurple.withOpacity(
                                        0.05,
                                      ),
                                    ],
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.cancel,
                                      size: 20,
                                      color: ClubBlackoutTheme.neonPurple,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                const Text(
                  '⚠️ The Lightweight dies if they speak any of these names!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: ClubBlackoutTheme.neonPurple,
                    foregroundColor: Colors.black,
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

  void _showMedicReviveDialog() {
    try {
      final medic = widget.gameEngine.players.firstWhere(
        (p) =>
            p.role.id == 'medic' &&
            p.isActive &&
            p.medicChoice == 'REVIVE' &&
            !p.hasReviveToken,
      );

      final validTargets = sortedPlayersByDisplayName(
        widget.gameEngine.deadPlayerIds
            .map(
              (id) => widget.gameEngine.players.firstWhere(
                (p) => p.id == id && p.role.id != 'second_wind',
              ),
            )
            .toList(), // Can revive anyone except maybe Second Wind if pending? Or specifically dealers? Usually anyone.
      );

      if (validTargets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No dead players to revive yet.')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
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
                  Icons.medical_services,
                  size: 60,
                  color: ClubBlackoutTheme.neonGreen,
                ),
                const SizedBox(height: 16),
                Text(
                  'MEDIC REVIVE',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: ClubBlackoutTheme.neonGreen,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use your ONE-TIME ability to bring a player back from the dead!',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: Column(
                      children: validTargets.map((player) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _useMedicRevive(medic, player);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: ClubBlackoutTheme.neonGreen
                                      .withOpacity(0.5),
                                  width: 1.5,
                                ),
                                gradient: LinearGradient(
                                  colors: [
                                    ClubBlackoutTheme.neonGreen.withOpacity(
                                      0.2,
                                    ),
                                    ClubBlackoutTheme.neonGreen.withOpacity(
                                      0.05,
                                    ),
                                  ],
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    player.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.add_circle,
                                    color: Colors.white70,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                IconButton.filled(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(backgroundColor: Colors.white12),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error showing Medic revive: $e");
    }
  }

  void _useMedicRevive(Player medic, Player target) {
    setState(() {
      medic.hasReviveToken = true; // Mark as used
      target.isAlive = true;
      target.lives = 1;
      widget.gameEngine.deadPlayerIds.remove(target.id);
    });

    widget.gameEngine.logAction(
      'Medic Revive',
      'Medic used their one-time ability to revive ${target.name}!',
    );
    widget.gameEngine.abilityResolver.queueAbility(
      ActiveAbility(
        abilityId: 'medic_revive',
        sourcePlayerId: medic.id,
        targetPlayerIds: [target.id],
        trigger: AbilityTrigger.dayAction,
        effect: AbilityEffect.heal,
        priority: 1,
      ),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: ClubBlackoutTheme.neonGreen, width: 2),
        ),
        title: Icon(
          Icons.check_circle,
          color: ClubBlackoutTheme.neonGreen,
          size: 50,
        ),
        content: Text(
          "${target.name} has been revived!",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          Center(
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Icon(Icons.check),
            ),
          ),
        ],
      ),
    );
  }

  void _showSoberAbility() {
    try {
      final sober = widget.gameEngine.players.firstWhere(
        (p) => p.role.id == 'sober' && p.isActive && !p.soberAbilityUsed,
      );

      final validTargets = sortedPlayersByDisplayName(
        widget.gameEngine.players
            .where((p) => p.isActive && p.id != sober.id)
            .toList(),
      );

      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blueAccent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.no_drinks, size: 60, color: Colors.blueAccent),
                const SizedBox(height: 16),
                const Text(
                  'SOBER SEND-HOME',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose one player to send home for the night. They cannot be killed or use abilities toniught.',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: Column(
                      children: validTargets.map((player) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _useSoberAbility(sober, player);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.blueAccent.withOpacity(0.5),
                                  width: 1.5,
                                ),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blueAccent.withOpacity(0.2),
                                    Colors.blueAccent.withOpacity(0.05),
                                  ],
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    player.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward,
                                    color: Colors.white70,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                IconButton.filled(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(backgroundColor: Colors.white12),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error showing Sober ability: $e");
    }
  }

  void _useSoberAbility(Player sober, Player target) {
    setState(() {
      sober.soberAbilityUsed = true;
      target.soberSentHome = true;
    });

    widget.gameEngine.logAction(
      'Sober Ability',
      'Sober sent ${target.name} home! They are safe/blocked tonight.',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.blueAccent, width: 2),
        ),
        title: const Icon(
          Icons.check_circle,
          color: Colors.blueAccent,
          size: 50,
        ),
        content: Text(
          "${target.name} has been sent home.",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          Center(
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Icon(Icons.check),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  void _showSilverFoxAbility() {
    try {
      final silverFox = widget.gameEngine.players.firstWhere(
        (p) =>
            p.role.id == 'silver_fox' && p.isActive && !p.silverFoxAbilityUsed,
      );

      final validTargets = sortedPlayersByDisplayName(
        widget.gameEngine.players
            .where((p) => p.isActive && p.id != silverFox.id)
            .toList(),
      );

      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
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
                  Icons.visibility,
                  size: 60,
                  color: ClubBlackoutTheme.neonBlue,
                ),
                const SizedBox(height: 16),
                Text(
                  'SILVER FOX REVEAL',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: ClubBlackoutTheme.neonBlue,
                    shadows: [
                      Shadow(color: ClubBlackoutTheme.neonBlue, blurRadius: 10),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose one player to ply with alcohol! They must reveal their role card to the group immediately.',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: const Text(
                    "ONE TIME USE ONLY",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  padding: const EdgeInsets.all(2), // Outer padding for scroll
                  child: SingleChildScrollView(
                    child: Column(
                      children: validTargets.map((player) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _useSilverFoxAbility(silverFox, player);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.white.withOpacity(0.05),
                                border: Border.all(
                                  color: ClubBlackoutTheme.neonBlue.withOpacity(
                                    0.3,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    player.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Icon(
                                    Icons.wine_bar,
                                    color: ClubBlackoutTheme.neonBlue
                                        .withOpacity(0.7),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "CANCEL",
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error showing Silver Fox ability: $e");
    }
  }

  void _useSilverFoxAbility(Player silverFox, Player target) {
    silverFox.silverFoxAbilityUsed = true;

    widget.gameEngine.abilityResolver.queueAbility(
      ActiveAbility(
        abilityId: 'silver_fox_reveal',
        sourcePlayerId: silverFox.id,
        targetPlayerIds: [target.id],
        trigger: AbilityTrigger.dayAction,
        effect: AbilityEffect.reveal,
        priority: 1,
      ),
    );

    widget.gameEngine.logAction(
      'Silver Fox Reveal',
      'Silver Fox forced ${target.name} to reveal their role: ${target.role.name}!',
    );

    _showRoleReveal(target, 'Silver Fox Revealed');

    setState(() {});
  }

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
        barrierDismissible: false,
        builder: (context) => Dialog(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFDE3163), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDE3163).withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.autorenew, size: 60, color: Color(0xFFDE3163)),
                const SizedBox(height: 16),
                const Text(
                  'SECOND WIND CONVERSION',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDE3163),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '${secondWind.name} was killed by the Dealers!',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Do the Dealers agree to convert The Second Wind and bring them back to life as a Dealer?',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _refuseSecondWindConversion(secondWind);
                      },
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(
                          Colors.red.withOpacity(0.2),
                        ),
                        foregroundColor: MaterialStateProperty.all(Colors.red),
                        side: MaterialStateProperty.all(
                          const BorderSide(color: Colors.red, width: 1.5),
                        ),
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('REFUSE'),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _acceptSecondWindConversion(secondWind);
                      },
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(
                          const Color(0xFFDE3163).withOpacity(0.2),
                        ),
                        foregroundColor: MaterialStateProperty.all(
                          const Color(0xFFDE3163),
                        ),
                        side: MaterialStateProperty.all(
                          const BorderSide(
                            color: Color(0xFFDE3163),
                            width: 1.5,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('ACCEPT'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error showing Second Wind conversion: $e");
    }
  }

  void _acceptSecondWindConversion(Player secondWind) {
    try {
      final dealerRole = widget.gameEngine.roleRepository.getRoleById('dealer');
      if (dealerRole != null) {
        secondWind.role = dealerRole;
        secondWind.alliance = dealerRole.alliance;
        secondWind.isAlive = true;
        secondWind.secondWindConverted = true;
        secondWind.secondWindPendingConversion = false;
        secondWind.initialize();

        widget.gameEngine.logAction(
          'Second Wind Conversion',
          '${secondWind.name} was converted by the Dealers and is now alive as a Dealer!',
        );

        widget.gameEngine.nightActions.remove('second_wind_victim_id');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${secondWind.name} is now a Dealer! No one dies tonight.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error converting Second Wind: $e");
    }
    setState(() {});
  }

  void _refuseSecondWindConversion(Player secondWind) {
    widget.gameEngine.processDeath(secondWind, cause: 'Refused Conversion');
    secondWind.secondWindPendingConversion = false;

    widget.gameEngine.logAction(
      'Second Wind Rejected',
      'The Dealers refused to convert ${secondWind.name}. They remain dead.',
    );

    setState(() {});
  }

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
    setState(() {});
  }

  void _executeAttackDogKill(Player clinger, Player victim) {
    clinger.clingerAttackDogUsed = true;
    victim.isAlive = false;
    widget.gameEngine.logAction(
      'Attack Dog Kill',
      '${clinger.name} (attack dog) killed ${victim.name}!',
    );
    setState(() {});
  }

  void _showLog() {
    showDialog(
      context: context,
      builder: (context) => _GameLogDialog(gameEngine: widget.gameEngine),
    );
  }

  Future<void> _showLateJoinerDialog() async {
    if (widget.gameEngine.currentPhase == GamePhase.lobby) return;

    final availableRoles = widget.gameEngine.availableRolesForNewPlayer();
    if (availableRoles.isEmpty) return;

    final nameController = TextEditingController();
    Role? selectedRole;
    bool randomRole = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Player For Next Night'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Player Name'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: randomRole,
                    onChanged: (v) => setState(() {
                      randomRole = v ?? false;
                      if (randomRole) selectedRole = null;
                    }),
                  ),
                  const Text('Random role'),
                ],
              ),
              if (!randomRole)
                DropdownMenu<Role>(
                  initialSelection: selectedRole,
                  dropdownMenuEntries: availableRoles
                      .map((r) => DropdownMenuEntry(value: r, label: r.name))
                      .toList(),
                  onSelected: (r) => setState(() => selectedRole = r),
                  width: 300,
                  inputDecorationTheme: InputDecorationTheme(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                  menuStyle: MenuStyle(
                    backgroundColor: WidgetStatePropertyAll(Colors.grey[900]),
                    surfaceTintColor: WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final role = randomRole
                    ? availableRoles[Random().nextInt(availableRoles.length)]
                    : selectedRole;
                if (role == null) return;
                final newPlayer = widget.gameEngine.addPlayerDuringDay(
                  name,
                  role: role,
                );
                Navigator.pop(context);
                _showRoleRevealCard(newPlayer.role, newPlayer.name);
                this.setState(() {});
              },
              child: const Text('ADD'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoleRevealCard(Role role, String playerName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: RoleCardWidget(role: role, playerName: playerName),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: role.color,
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                child: const Text('I UNDERSTAND'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  void _showClingerObsessionRole() {
    try {
      final clinger = widget.gameEngine.players.firstWhere(
        (p) => p.role.id == 'clinger',
      );
      if (clinger.clingerPartnerId == null) {
        widget.gameEngine.advanceScript();
        setState(() {});
        return;
      }
      final obsession = widget.gameEngine.players.firstWhere(
        (p) => p.id == clinger.clingerPartnerId,
      );
      final obsessionRole = obsession.role;

      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'OBSESSION REVEAL',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: obsessionRole.color,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your obsession is: ${obsession.name}',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  'Their Role: ${obsessionRole.name}',
                  style: TextStyle(color: obsessionRole.color),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.gameEngine.advanceScript();
                    setState(() {});
                  },
                  child: const Text('I UNDERSTAND'),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      widget.gameEngine.advanceScript();
      setState(() {});
    }
  }

  // ignore: unused_element
  void _showCreepTargetRole() {
    try {
      final creep = widget.gameEngine.players.firstWhere(
        (p) => p.role.id == 'creep',
      );
      if (creep.creepTargetId == null) {
        widget.gameEngine.advanceScript();
        setState(() {});
        return;
      }
      final target = widget.gameEngine.players.firstWhere(
        (p) => p.id == creep.creepTargetId,
      );
      final targetRole = target.role;

      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'CREEP TARGET',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'You are mimicking: ${target.name}',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  'Their Role: ${targetRole.name}',
                  style: TextStyle(color: targetRole.color),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.gameEngine.advanceScript();
                    setState(() {});
                  },
                  child: const Text('I UNDERSTAND'),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      widget.gameEngine.advanceScript();
      setState(() {});
    }
  }

  void _showRoleReveal(Player target, String actionTitle) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                target.role.name,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: target.role.color,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CONTINUE'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleOptionGrid(ScriptStep step) {
    List<String> options = [];
    String title = '';
    Color optionColor = ClubBlackoutTheme.neonBlue;

    if (step.id == 'medic_setup_choice') {
      options = ['PROTECT', 'REVIVE'];
      title = 'Choose Your Mode (PERMANENT)';
      optionColor = ClubBlackoutTheme.neonGreen;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: optionColor,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = _currentSelection.contains(option);
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _currentSelection.clear();
                      _currentSelection.add(option);
                    });
                    _advanceScript();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? optionColor : Colors.white24,
                        width: isSelected ? 3 : 2,
                      ),
                      color: isSelected
                          ? optionColor.withOpacity(0.2)
                          : Colors.black.withOpacity(0.3),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: optionColor.withOpacity(0.5),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? optionColor : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  void _skipToNextPhase() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SKIP TO NEXT PHASE?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.gameEngine.skipToNextPhase();
              setState(() => _currentSelection.clear());
            },
            child: const Text('SKIP'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.gameEngine,
      builder: (context, child) {
        _checkScroll();
        _checkAbilityNotifications(); // Check for new ability availability

        if (widget.gameEngine.messyBitchVictoryPending) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            widget.gameEngine.clearMessyBitchVictoryPending();
            _showMessyBitchVictoryDialog();
          });
        }

        final steps = widget.gameEngine.scriptQueue;
        final safeIndex = widget.gameEngine.currentScriptIndex.clamp(
          0,
          steps.length,
        );
        final isWaiting = safeIndex >= steps.length;
        final visibleCount = safeIndex + (isWaiting ? 0 : 1);

        ScriptStep? currentStep;
        if (!isWaiting && steps.isNotEmpty) {
          currentStep = steps[safeIndex];
        }

        final hasMessyBitch = widget.gameEngine.players.any(
          (p) => p.role.id == 'messy_bitch',
        );
        final hasLightweight = widget.gameEngine.players.any(
          (p) => p.role.id == 'lightweight' && p.isActive,
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
        final hasSilverFox = false; // Silver Fox disabled
        final hasTeaSpiller = widget.gameEngine.players.any(
          (p) => p.role.id == 'tea_spiller',
        );
        final hasPredator = widget.gameEngine.players.any(
          (p) => p.role.id == 'predator',
        );
        final hasDramaQueen = widget.gameEngine.dramaQueenSwapPending;
        final hasMedic = widget.gameEngine.players.any(
          (p) =>
              p.role.id == 'medic' &&
              p.isActive &&
              p.medicChoice == 'REVIVE' &&
              !p.hasReviveToken,
        );
        final hasSober = widget.gameEngine.players.any(
          (p) => p.role.id == 'sober' && p.isActive && !p.soberAbilityUsed,
        );
        final hasBouncer = widget.gameEngine.players.any(
          (p) =>
              p.role.id == 'bouncer' && p.isActive && !p.bouncerAbilityRevoked,
        );

        final hasAnyAbility =
            hasMessyBitch ||
            hasLightweight ||
            hasClingerToFree ||
            hasSecondWindConversion ||
            hasSilverFox ||
            hasTeaSpiller ||
            hasPredator ||
            hasDramaQueen ||
            hasMedic ||
            hasSober ||
            hasBouncer;

        return Scaffold(
          drawer: GameDrawer(
            gameEngine: widget.gameEngine,
            onGameLogTap: _showLog,
            onNavigate: (index) {
              Navigator.pop(context); // Close drawer
              // For GameScreen, we probably want to leave and go to home?
              if (index == 0) {
                Navigator.pop(context);
              }
            },
          ),
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Builder(
              builder: (BuildContext context) {
                return IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                  tooltip: 'Game Menu',
                );
              },
            ),
            title: const Text('CLUB BLACKOUT'),
            centerTitle: true,
            actions: [
              if (!isWaiting &&
                  currentStep != null &&
                  widget.gameEngine.currentPhase == GamePhase.day)
                IconButton(
                  onPressed: _showLateJoinerDialog,
                  icon: const Icon(Icons.person_add),
                ),
            ],
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  "Backgrounds/Club Blackout App Background.png",
                  fit: BoxFit.cover,
                  errorBuilder: (c, o, s) => Container(color: Colors.black),
                ),
              ),
              if (steps.isNotEmpty && !isWaiting)
                Positioned.fill(
                  child: SafeArea(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 120, bottom: 200),
                      itemCount: visibleCount,
                      itemBuilder: (context, index) {
                        final step = steps[index];
                        final isLast = index == visibleCount - 1;

                        // Ensure GlobalKey exists for this index
                        _stepKeys.putIfAbsent(index, () => GlobalKey());
                        final key = _stepKeys[index]!;

                        // Day Phase Integration
                        if (step.id.startsWith('day_start_discussion')) {
                          return _buildDayPhaseLauncher(step);
                        }
                        if (step.id == 'day_vote') {
                          // Automatically handled by the DaySceneDialog logic
                          return const SizedBox.shrink();
                        }

                        if (step.actionType ==
                            ScriptActionType.phaseTransition) {
                          return PhaseCard(
                            key: key,
                            phaseName: step.isNight
                                ? 'PARTY TIME!'
                                : 'THE CLUB HAS CLOSED',
                            phaseColor: step.isNight
                                ? ClubBlackoutTheme.neonPurple
                                : ClubBlackoutTheme.neonOrange,
                            phaseIcon: step.isNight
                                ? Icons.nightlight_round
                                : Icons.wb_sunny,
                            isActive: isLast,
                          );
                        }

                        final role = widget.gameEngine.roleRepository
                            .getRoleById(step.roleId ?? '');

                        // Find the player with this role
                        Player? player;
                        if (role != null) {
                          try {
                            player = widget.gameEngine.players.firstWhere(
                              (p) =>
                                  p.role.id == role.id &&
                                  p.isActive &&
                                  !p.soberSentHome,
                            );
                          } catch (_) {}
                        }

                        return Column(
                          key: key,
                          children: [
                            InteractiveScriptCard(
                              step: step,
                              isActive: isLast,
                              stepColor:
                                  role?.color ?? ClubBlackoutTheme.neonOrange,
                              role: role,
                              playerName: player?.name,
                            ),
                            if (isLast && step.id == 'day_vote')
                              _buildVotingGrid(step),
                            if (isLast &&
                                (step.actionType ==
                                        ScriptActionType.selectPlayer ||
                                    step.actionType ==
                                        ScriptActionType.selectTwoPlayers) &&
                                step.id != 'day_vote')
                              _buildPlayerSelectionGrid(step),
                            if (isLast &&
                                step.actionType ==
                                    ScriptActionType.toggleOption)
                              _buildToggleOptionGrid(step),
                            if (isLast &&
                                step.actionType ==
                                    ScriptActionType.binaryChoice)
                              _buildBinaryChoice(step),
                          ],
                        );
                      },
                    ),
                  ),
                )
              else if (isWaiting)
                const Center(
                  child: Text(
                    "Phase Complete",
                    style: TextStyle(fontSize: 32, color: Colors.white),
                  ),
                ),

              if (!isWaiting && currentStep != null)
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: _buildFloatingActionBar(currentStep),
                ),

              if (isWaiting)
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FilledButton(
                      onPressed: _advanceScript,
                      child: const Text("CONTINUE"),
                    ),
                  ),
                ),

              if (_abilityFabExpanded) _buildAbilityFabMenu(),
              // Dedicated FAB toggle anchored bottom-right so it is always reachable (day or night)
              if (!isWaiting && hasAnyAbility)
                Positioned(
                  bottom: 100,
                  right: 20,
                  child: hasSecondWindConversion
                      ? _PulsingFab(
                          onPressed: () => setState(
                            () => _abilityFabExpanded = !_abilityFabExpanded,
                          ),
                          isExpanded: _abilityFabExpanded,
                        )
                      : FloatingActionButton(
                          heroTag: 'ability_toggle',
                          backgroundColor: ClubBlackoutTheme.neonPurple,
                          onPressed: () => setState(
                            () => _abilityFabExpanded = !_abilityFabExpanded,
                          ),
                          child: Icon(
                            _abilityFabExpanded
                                ? Icons.close
                                : Icons.settings_remote,
                          ),
                        ),
                ),
              if (_rumourMillExpanded)
                Positioned.fill(child: _buildRumourMillPanel()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingActionBar(ScriptStep step) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton.filled(
          onPressed: widget.gameEngine.regressScript,
          icon: const Icon(Icons.arrow_back),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white12,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
          ),
        ),
        FilledButton(
          onPressed: _advanceScript,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.all(16),
            shape: const CircleBorder(),
          ),
          child: const Icon(Icons.arrow_forward), // Icon only
        ),
      ],
    );
  }

  Widget _buildVotingGrid(ScriptStep step) {
    // Exclude players sent home by Sober from the voting list
    final players = sortedPlayersByDisplayName(
      widget.gameEngine.players
          .where((p) => p.isAlive && p.role.id != 'host' && !p.soberSentHome)
          .toList(),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: players.map((player) {
          final votes = _voteCounts[player.id] ?? 0;
          return Row(
            children: [
              Expanded(
                child: PlayerTile(
                  player: player,
                  voteCount: votes,
                  onTap: () =>
                      setState(() => _voteCounts[player.id] = votes + 1),
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.white54),
                    onPressed: () =>
                        setState(() => _voteCounts[player.id] = votes + 1),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.white24,
                    ),
                    onPressed: () => setState(
                      () => _voteCounts[player.id] = max(0, votes - 1),
                    ),
                  ),
                ],
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlayerSelectionGrid(ScriptStep step) {
    // Exclude players sent home by Sober from selection
    final players = sortedPlayersByDisplayName(
      widget.gameEngine.players
          .where((p) => p.isAlive && p.role.id != 'host' && !p.soberSentHome)
          .toList(),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.1,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: players.length,
        itemBuilder: (context, index) {
          final p = players[index];
          final isSelected = _currentSelection.contains(p.id);
          return PlayerTile(
            player: p,
            isSelected: isSelected,
            onTap: () => _onPlayerSelected(p.id),
            isCompact: true,
          );
        },
      ),
    );
  }

  Widget _buildBinaryChoice(ScriptStep step) {
    if (step.id == 'second_wind_decision') {
      final secondWind = widget.gameEngine.players.firstWhere(
        (p) => p.role.id == 'second_wind',
      );
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  widget.gameEngine.logAction(
                    'Second Wind Decision',
                    'Dealers chose NOT to convert. Second Wind dies.',
                  );
                  _refuseSecondWindConversion(secondWind);
                  widget.gameEngine.advanceScript();
                  _scrollToBottom();
                },
                icon: const Icon(Icons.close),
                label: const Text("NO (KILL)"),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.2),
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  widget.gameEngine.logAction(
                    'Second Wind Decision',
                    'Dealers chose to convert ${secondWind.name}.',
                  );
                  _acceptSecondWindConversion(secondWind);
                  widget.gameEngine.advanceScript();
                  _scrollToBottom();
                },
                icon: const Icon(Icons.check),
                label: const Text("YES (CONVERT)"),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(
                    0xFFDE3163,
                  ).withOpacity(0.2), // Second Wind Pink
                  foregroundColor: const Color(0xFFDE3163),
                  side: const BorderSide(color: Color(0xFFDE3163), width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _checkAbilityNotifications() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final abilities = <Map<String, dynamic>>[
        {
          'id_base': 'messy_bitch_ready',
          'condition': widget.gameEngine.players.any(
            (p) => p.role.id == 'messy_bitch' && p.isActive,
          ),
          'msg': "Messy Bitch: Rumour Mill is active! Open FAB to view.",
        },
        {
          'id_base': 'clinger_attack_ready',
          'condition': widget.gameEngine.players.any(
            (p) =>
                p.role.id == 'clinger' &&
                p.isActive &&
                p.clingerPartnerId != null &&
                !p.clingerAttackDogUsed,
          ),
          'msg': "Clinger Notification: Attack Dog ability available!",
        },
        {
          'id_base': 'second_wind_ready',
          'condition': widget.gameEngine.players.any(
            (p) =>
                p.role.id == 'second_wind' &&
                p.secondWindPendingConversion &&
                !p.secondWindConverted,
          ),
          'msg': "Second Wind Notification: Conversion opportunity available!",
        },
        {
          'id_base': 'silver_fox_ready',
          'condition': false,
          'msg': "Silver Fox disabled.",
        },
        {
          'id_base': 'tea_spiller_ready',
          'condition': widget.gameEngine.players.any(
            (p) =>
                p.role.id == 'tea_spiller' &&
                widget.gameEngine.deadPlayerIds.contains(p.id),
          ),
          'msg': "Tea Spiller DIED: Check menu for Tea Spilling opportunity.",
        },
        {
          'id_base': 'predator_ready',
          'condition': widget.gameEngine.players.any(
            (p) =>
                p.role.id == 'predator' &&
                widget.gameEngine.deadPlayerIds.contains(p.id),
          ),
          'msg': "Predator DIED: Check menu for Retaliation opportunity.",
        },
        {
          'id_base': 'drama_queen_ready',
          'condition': widget.gameEngine.dramaQueenSwapPending,
          'msg': "Drama Queen died: swap two players now.",
        },
        {
          'id_base': 'medic_ready',
          'condition': widget.gameEngine.players.any(
            (p) =>
                p.role.id == 'medic' &&
                p.isActive &&
                p.medicChoice == 'REVIVE' &&
                !p.hasReviveToken,
          ),
          'msg': "Medic: Revive ability is available.",
        },
        {
          'id_base': 'sober_ready',
          'condition': widget.gameEngine.players.any(
            (p) => p.role.id == 'sober' && p.isActive && !p.soberAbilityUsed,
          ),
          'msg': "The Sober: Send Home ability available.",
        },
        {
          'id_base': 'bouncer_ready',
          'condition': widget.gameEngine.players.any(
            (p) =>
                p.role.id == 'bouncer' &&
                p.isActive &&
                !p.bouncerAbilityRevoked,
          ),
          'msg': "The Bouncer: Confront Roofi ability available.",
        },
      ];

      // Prime on first pass to avoid firing notifications immediately at game start
      if (!_abilityNotificationsPrimed) {
        for (final ab in abilities) {
          final idBase = ab['id_base'] as String;
          final bool condition = ab['condition'] == true;
          _abilityLastState[idBase] = condition;
        }
        _abilityNotificationsPrimed = true;
        return;
      }

      for (final ab in abilities) {
        final bool condition = ab['condition'] == true;
        final String idBase = ab['id_base'] as String;
        final String message = ab['msg'] as String;

        final bool wasActive = _abilityLastState[idBase] ?? false;
        _abilityLastState[idBase] = condition;

        // Notify only on transition from inactive -> active, and only once per activation
        if (condition &&
            !wasActive &&
            !_shownAbilityNotifications.contains(idBase)) {
          _shownAbilityNotifications.add(idBase);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.notification_important,
                    color: ClubBlackoutTheme.neonOrange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(message)),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: ClubBlackoutTheme.neonOrange),
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'OPEN MENU',
                textColor: ClubBlackoutTheme.neonOrange,
                onPressed: () {
                  setState(() {
                    _abilityFabExpanded = true;
                  });
                },
              ),
            ),
          );
        }
      }
    });
  }

  Widget _buildAbilityFabMenu() {
    Widget roleIcon(String roleId) {
      try {
        final p = widget.gameEngine.players.firstWhere(
          (player) => player.role.id == roleId,
        );
        if (p.role.assetPath.isNotEmpty) {
          return ClipOval(
            child: Image.asset(p.role.assetPath, fit: BoxFit.cover),
          );
        }
      } catch (_) {}
      return const Icon(Icons.help);
    }

    return Positioned(
      bottom: 100,
      right: 20,
      child: Column(
        children: [
          // Messy Bitch -> Rumour Mill (Info/Tool) - Active when Alive
          if (widget.gameEngine.players.any(
            (p) => p.role.id == 'messy_bitch' && p.isActive,
          ))
            FloatingActionButton(
              heroTag: 'fab_messy',
              onPressed: () => setState(() => _rumourMillExpanded = true),
              child: roleIcon('messy_bitch'),
            ),
          const SizedBox(height: 12),

          // Clinger -> Attack Dog (Manual Activation) - Active when Linked
          if (widget.gameEngine.players.any(
            (p) =>
                p.role.id == 'clinger' &&
                p.isActive &&
                p.clingerPartnerId != null &&
                !p.clingerAttackDogUsed,
          ))
            FloatingActionButton(
              heroTag: 'fab_clinger',
              onPressed: _showAttackDogConversion,
              child: roleIcon('clinger'),
            ),
          const SizedBox(height: 12),

          // Second Wind -> Conversion (Manual Activation) - Active Pending
          if (widget.gameEngine.players.any(
            (p) =>
                p.role.id == 'second_wind' &&
                p.secondWindPendingConversion &&
                !p.secondWindConverted,
          ))
            FloatingActionButton(
              heroTag: 'fab_secondwind',
              onPressed: _showSecondWindConversion,
              child: roleIcon('second_wind'),
            ),
          const SizedBox(height: 12),

          // Silver Fox disabled (host request)
          const SizedBox(height: 12),

          // Lightweight -> Taboo List (Info) - Active when Alive
          if (widget.gameEngine.players.any(
            (p) => p.role.id == 'lightweight' && p.isActive,
          ))
            FloatingActionButton(
              heroTag: 'fab_lightweight',
              onPressed: _showTabooList,
              child: roleIcon('lightweight'),
            ),
          const SizedBox(height: 12),

          // Tea Spiller -> Reveal (Death Reaction) - ONLY ACTIVE WHEN DEAD
          if (widget.gameEngine.players.any(
            (p) =>
                p.role.id == 'tea_spiller' &&
                widget.gameEngine.deadPlayerIds.contains(p.id),
          ))
            FloatingActionButton(
              heroTag: 'fab_tea_spiller',
              onPressed: _showTeaSpillerRevealDialog,
              child: roleIcon('tea_spiller'),
            ),
          const SizedBox(height: 12),

          // Predator -> Retaliation (Death Reaction) - ONLY ACTIVE WHEN DEAD
          if (widget.gameEngine.players.any(
            (p) =>
                p.role.id == 'predator' &&
                widget.gameEngine.deadPlayerIds.contains(p.id),
          ))
            FloatingActionButton(
              heroTag: 'fab_predator',
              onPressed: _showPredatorRetaliationDialog,
              child: roleIcon('predator'),
            ),
          const SizedBox(height: 12),

          // Drama Queen -> Swap (Death Reaction) - Active while pending
          if (widget.gameEngine.dramaQueenSwapPending)
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: ClubBlackoutTheme.neonBlue.withOpacity(0.7),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: FloatingActionButton(
                heroTag: 'fab_drama_queen',
                backgroundColor: ClubBlackoutTheme.neonBlue,
                foregroundColor: Colors.black,
                onPressed: _showDramaQueenSwapDialog,
                child: roleIcon('drama_queen'),
              ),
            ),
          const SizedBox(height: 12),

          // Medic -> Revive (Manual Activation - if Mode Correct) - Active when Alive
          if (widget.gameEngine.players.any(
            (p) =>
                p.role.id == 'medic' &&
                p.isActive &&
                p.medicChoice == 'REVIVE' &&
                !p.hasReviveToken,
          ))
            FloatingActionButton(
              heroTag: 'fab_medic',
              onPressed: _showMedicReviveDialog,
              child: roleIcon('medic'),
            ),
          const SizedBox(height: 12),

          // Sober -> Send Home (Manual Activation - Day Ability) - Active when Alive
          if (widget.gameEngine.players.any(
            (p) => p.role.id == 'sober' && p.isActive && !p.soberAbilityUsed,
          ))
            FloatingActionButton(
              heroTag: 'fab_sober',
              onPressed: _showSoberAbility,
              child: roleIcon('sober'),
            ),
          const SizedBox(height: 12),

          // Bouncer -> Confront Roofi (Manual Activation)
          if (widget.gameEngine.players.any(
            (p) =>
                p.role.id == 'bouncer' &&
                p.isActive &&
                !p.bouncerAbilityRevoked,
          ))
            FloatingActionButton(
              heroTag: 'fab_bouncer',
              onPressed: _showBouncerConfrontDialog,
              child: roleIcon('bouncer'),
            ),
        ],
      ),
    );
  }

  Widget _buildRumourMillPanel() {
    final messyBitch = widget.gameEngine.players.firstWhere(
      (p) => p.role.id == 'messy_bitch',
    );
    final alivePlayers = widget.gameEngine.players
        .where((p) => p.isActive && p.id != messyBitch.id)
        .toList();
    final heardCount = alivePlayers.where((p) => p.hasRumour).length;
    final totalTargets = alivePlayers.length;

    return Container(
      color: Colors.black.withOpacity(0.95),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Text(
            'RUMOUR MILL',
            style: ClubBlackoutTheme.headingStyle.copyWith(
              color: ClubBlackoutTheme.neonGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$heardCount / $totalTargets Targets Reached',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: totalTargets > 0 ? heardCount / totalTargets : 0,
            backgroundColor: Colors.white10,
            color: ClubBlackoutTheme.neonGreen,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: alivePlayers.length,
              itemBuilder: (context, index) {
                final p = alivePlayers[index];
                final hasHeard = p.hasRumour;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: hasHeard
                        ? ClubBlackoutTheme.neonGreen.withOpacity(0.1)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasHeard
                          ? ClubBlackoutTheme.neonGreen
                          : Colors.white10,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: hasHeard
                            ? ClubBlackoutTheme.neonGreen
                            : Colors.grey,
                        child: Icon(
                          hasHeard ? Icons.campaign : Icons.hearing_disabled,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              hasHeard ? "Has heard the rumour" : "Uninformed",
                              style: TextStyle(
                                color: hasHeard
                                    ? ClubBlackoutTheme.neonGreen
                                    : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasHeard)
                        Icon(
                          Icons.check_circle,
                          color: ClubBlackoutTheme.neonGreen,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ClubBlackoutTheme.neonGreen,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            onPressed: () => setState(() => _rumourMillExpanded = false),
            child: const Text(
              'CLOSE RUMOUR MILL',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showBouncerConfrontDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: ClubBlackoutTheme.neonBlue, width: 2),
        ),
        title: Text(
          'CONFRONT THE ROOFI',
          style: ClubBlackoutTheme.headingStyle.copyWith(
            color: ClubBlackoutTheme.neonBlue,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Suspect someone of being The Roofi? Select them to intervene.",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            const Text(
              "⚠️ RISK: If you are wrong, you lose your I.D. checking ability forever.",
              style: TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              width: double.maxFinite,
              child: ListView(
                children: widget.gameEngine.players
                    .where((p) => p.isActive && p.role.id != 'bouncer')
                    .map(
                      (p) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: p.role.color,
                          child: Text(
                            p.name[0],
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                        title: Text(
                          p.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _processBouncerConfrontation(p);
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  void _processBouncerConfrontation(Player target) {
    bool success = target.role.id == 'roofi';

    setState(() {
      if (success) {
        try {
          final roofi = widget.gameEngine.players.firstWhere(
            (p) => p.role.id == 'roofi' && p.isActive,
          );
          roofi.roofiAbilityRevoked = true; // Revoke Roofi's ability
        } catch (_) {}

        widget.gameEngine.logAction(
          "Bouncer Confrontation",
          "Bouncer correctly identified Roofi (${target.name})!",
        );
        _showBouncerResultDialog(
          "SUCCESS",
          "You caught The Roofi!\nTheir power is neutralized.",
          ClubBlackoutTheme.neonGreen,
        );
      } else {
        try {
          final bouncer = widget.gameEngine.players.firstWhere(
            (p) => p.role.id == 'bouncer',
          );
          bouncer.bouncerAbilityRevoked = true;
        } catch (_) {}

        widget.gameEngine.logAction(
          "Bouncer Confrontation",
          "Bouncer incorrectly suspected ${target.name} as Roofi and lost their ability.",
        );
        _showBouncerResultDialog(
          "FAILURE",
          "That was not The Roofi.\nYou have lost your I.D. checking ability.",
          Colors.red,
        );
      }
    });
  }

  void _showBouncerResultDialog(String title, String body, Color color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: color, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        content: Text(body, style: const TextStyle(color: Colors.white)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: color),
            child: const Text("OK", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showTeaSpillerRevealDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: ClubBlackoutTheme.neonOrange, width: 2),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "TEA SPILLER REVEAL",
                style: ClubBlackoutTheme.headingStyle.copyWith(
                  color: ClubBlackoutTheme.neonOrange,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "The Tea Spiller has died. Select a player to reveal their role.",
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: ListView(
                  children: widget.gameEngine.players
                      .map(
                        (p) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: p.role.color,
                            child: Text(
                              p.name[0],
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                          title: Text(
                            p.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            p.role.name,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                          /* Host sees roles */
                          onTap: () {
                            Navigator.pop(context);
                            widget.gameEngine.logAction(
                              "Tea Spiller Reveal",
                              "Tea Spiller revealed ${p.name} as ${p.role.name}.",
                            );
                            showRoleReveal(
                              context,
                              p.role,
                              p.name,
                              subtitle: "Tea Spilled by the Dead!",
                            );
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

  void _showPredatorRetaliationDialog() {
    // Show list of players to KILL
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey, width: 2),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "PREDATOR RETALIATION",
                style: ClubBlackoutTheme.headingStyle.copyWith(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "The Predator was voted out. Select a player to take down with them.",
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: ListView(
                  children: widget.gameEngine.players
                      .where((p) => p.isAlive)
                      .map(
                        (p) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: p.role.color,
                            child: Text(
                              p.name[0],
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                          title: Text(
                            p.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: const Icon(
                            Icons.dangerous,
                            color: Colors.red,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            // Kill player manually
                            p.die(widget.gameEngine.dayCount);
                            widget.gameEngine.deadPlayerIds.add(p.id);
                            widget.gameEngine.logAction(
                              "Predator Retaliation",
                              "The Predator took ${p.name} down with them!",
                            );

                            // Refresh UI
                            setState(() {});

                            // Show confirmation
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text(
                                  "ELIMINATED",
                                  style: TextStyle(color: Colors.red),
                                ),
                                content: Text(
                                  "${p.name} has been eliminated by The Predator.",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text("OK"),
                                  ),
                                ],
                              ),
                            );
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

  void _showDramaQueenSwapDialog() {
    final alivePlayers = widget.gameEngine.players
        .where((p) => p.isAlive)
        .toList();
    final initialSelected = <String>{};
    if (widget.gameEngine.dramaQueenMarkedAId != null) {
      initialSelected.add(widget.gameEngine.dramaQueenMarkedAId!);
    }
    if (widget.gameEngine.dramaQueenMarkedBId != null) {
      initialSelected.add(widget.gameEngine.dramaQueenMarkedBId!);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final selected = <String>{...initialSelected};
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: ClubBlackoutTheme.neonPurple, width: 2),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "DRAMA QUEEN SWAP",
                      style: ClubBlackoutTheme.headingStyle.copyWith(
                        color: ClubBlackoutTheme.neonPurple,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Drama Queen is dead. Pick two players to swap devices, then confirm.",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 400,
                      child: GridView.builder(
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 0.85,
                            ),
                        itemCount: alivePlayers.length,
                        itemBuilder: (context, index) {
                          final player = alivePlayers[index];
                          final isSelected = selected.contains(player.id);
                          return PlayerTile(
                            player: player,
                            isCompact: true,
                            isSelected: isSelected,
                            onTap: () {
                              setStateDialog(() {
                                if (isSelected) {
                                  selected.remove(player.id);
                                } else if (selected.length < 2) {
                                  selected.add(player.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'CANCEL',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: selected.length == 2
                                ? ClubBlackoutTheme.neonPurple
                                : Colors.white12,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          onPressed: selected.length == 2
                              ? () {
                                  final ids = selected.toList();
                                  final p1 = alivePlayers.firstWhere(
                                    (p) => p.id == ids[0],
                                  );
                                  final p2 = alivePlayers.firstWhere(
                                    (p) => p.id == ids[1],
                                  );

                                  widget.gameEngine.completeDramaQueenSwap(
                                    p1,
                                    p2,
                                  );
                                  Navigator.pop(context);

                                  showDialog(
                                    context: this.context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        side: BorderSide(
                                          color: ClubBlackoutTheme.neonPurple,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: const Text(
                                        "SWAP COMPLETE",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${p1.name} is now ${p1.role.name}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "${p2.name} is now ${p2.role.name}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            "Host instructions:\n1) Ask all players to close their eyes.\n2) Swap the devices/cards.\n3) Give everyone 10 seconds to check their role.\n4) Resume into the next night.",
                                            style: TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text("ACKNOWLEDGE"),
                                        ),
                                      ],
                                    ),
                                  );
                                  setState(() {});
                                }
                              : null,
                          icon: const Icon(Icons.check),
                          label: const Text("CONFIRM SWAP"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDayPhaseLauncher(ScriptStep step) {
    // Determine if this specific step is currently active
    final isActive = widget.gameEngine.currentScriptStep?.id == step.id;

    if (!isActive) {
      return Card(
        color: Colors.white10,
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.wb_sunny, color: Colors.white30),
              const SizedBox(width: 16),
              Text(
                "Day Phase Completed",
                style: TextStyle(color: Colors.white30, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () {
            final navigator = Navigator.of(context);
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => DaySceneDialog(
                gameEngine: widget.gameEngine,
                selectedNavIndex: 0,
                onNavigate: (index) {
                  navigator.pop(); // close dialog
                  if (index == 0) {
                    navigator.pop(); // return to previous screen (home)
                  }
                },
                onGameLogTap: () {
                  navigator.pop(); // close dialog
                  _showLog();
                },
                onComplete: () {
                  // Advance past 'day_discuss'
                  widget.gameEngine.advanceScript();
                  // If next is 'day_vote', advance past that too since dialog handled it
                  if (widget.gameEngine.currentScriptStep?.id == 'day_vote') {
                    widget.gameEngine.advanceScript();
                  }
                  _scrollToBottom();
                },
                onGameEnd: (winner, message) {
                  navigator.pop(); // Close dialog
                  _showGameEndDialog(winner, message);
                },
              ),
            );
          },
          icon: const Icon(Icons.meeting_room, size: 28),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Text("BEGIN DAY PHASE", style: TextStyle(fontSize: 20)),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: ClubBlackoutTheme.neonOrange,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
          ),
        ),
      ),
    );
  }
}

class _GameLogDialog extends StatelessWidget {
  final GameEngine gameEngine;
  const _GameLogDialog({required this.gameEngine});

  @override
  Widget build(BuildContext context) {
    // Material 3 Styled Dialog
    return Dialog(
      backgroundColor: Colors.transparent, // Using container for styling
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: ClubBlackoutTheme.neonBlue.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ClubBlackoutTheme.neonBlue.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    color: ClubBlackoutTheme.neonBlue,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'GAME LOG',
                    style: TextStyle(
                      fontFamily: 'Hyperwave',
                      fontSize: 24,
                      color: ClubBlackoutTheme.neonBlue,
                      shadows: ClubBlackoutTheme.textGlow(
                        ClubBlackoutTheme.neonBlue,
                      ),
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: gameEngine.gameLog.isEmpty
                  ? Center(
                      child: Text(
                        'No events recorded yet.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: gameEngine.gameLog.reversed.length,
                      itemBuilder: (context, index) {
                        final reversedList = gameEngine.gameLog.reversed
                            .toList();
                        final entry = reversedList[index];
                        final ts = entry.timestamp.toLocal();
                        final hh = ts.hour.toString().padLeft(2, '0');
                        final mm = ts.minute.toString().padLeft(2, '0');
                        final ss = ts.second.toString().padLeft(2, '0');
                        final timeLabel = '$hh:$mm:$ss';
                        final headerLine =
                            'Turn ${entry.turn}  ·  ${entry.phase.toUpperCase()}  ·  $timeLabel';
                        final dotted = '···························';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CLUB BLACKOUT RECEIPT',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'RobotoMono',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  headerLine,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontFamily: 'RobotoMono',
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  dotted,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.25),
                                    fontSize: 12,
                                    letterSpacing: 1.5,
                                    fontFamily: 'RobotoMono',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  entry.action.toUpperCase(),
                                  style: TextStyle(
                                    color: ClubBlackoutTheme.neonBlue,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                    fontFamily: 'RobotoMono',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  entry.details,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    height: 1.45,
                                    fontFamily: 'RobotoMono',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  dotted,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.25),
                                    fontSize: 12,
                                    letterSpacing: 1.5,
                                    fontFamily: 'RobotoMono',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      'REF: ${entry.hashCode & 0xFFFF}',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                        fontFamily: 'RobotoMono',
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'KEEP FOR YOUR RECORDS',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 10,
                                        letterSpacing: 1,
                                        fontFamily: 'RobotoMono',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: ClubBlackoutTheme.neonBlue,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'CLOSE LOG',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingFab extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isExpanded;

  const _PulsingFab({required this.onPressed, required this.isExpanded});

  @override
  State<_PulsingFab> createState() => _PulsingFabState();
}

class _PulsingFabState extends State<_PulsingFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFFDE3163,
                ).withOpacity(0.6 + (_animation.value * 0.4)),
                blurRadius: 10 + (_animation.value * 10),
                spreadRadius: 2 + (_animation.value * 4),
              ),
            ],
          ),
          child: FloatingActionButton(
            heroTag: 'ability_toggle_pulsing',
            backgroundColor: const Color(0xFFDE3163), // Second Wind Pink
            foregroundColor: Colors.white, // Ensure icon is visible
            onPressed: widget.onPressed,
            child: Icon(widget.isExpanded ? Icons.close : Icons.autorenew),
          ),
        );
      },
    );
  }
}
