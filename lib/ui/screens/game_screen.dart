// ignore_for_file: use_build_context_synchronously, unnecessary_null_comparison, invalid_null_aware_operator, prefer_interpolation_to_compose_strings

import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../logic/ability_system.dart';
import '../../logic/game_engine.dart';
import '../../models/player.dart';
import '../../models/script_step.dart';
import '../../utils/game_exceptions.dart';
import '../styles.dart';
import '../utils/player_sort.dart';
import '../widgets/club_alert_dialog.dart';
import '../widgets/day_scene_dialog.dart';
import '../widgets/game_drawer.dart';
import '../widgets/interactive_script_card.dart';
import '../widgets/night_phase_player_tile.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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

  bool _autoOpenedDayDialog = false;

  @override
  void initState() {
    super.initState();
    _lastScriptIndex = widget.gameEngine.currentScriptIndex;

    widget.gameEngine.onPhaseChanged = (oldPhase, newPhase) {
      if (mounted) {
        setState(() {});
        _scrollToStep(widget.gameEngine.currentScriptIndex);

        // UX: After the last night action, go straight into Day Phase dialog.
        if (newPhase == GamePhase.day && !_autoOpenedDayDialog) {
          _autoOpenedDayDialog = true;
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _showDaySceneDialog();
          });
        }

        // Reset guard when leaving day.
        if (newPhase != GamePhase.day) {
          _autoOpenedDayDialog = false;
        }
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

  void _showDaySceneDialog() {
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
          // Advance through all remaining day phase steps
          int safety = 0;
          do {
            widget.gameEngine.advanceScript();
            safety++;
          } while (safety < 10 &&
              widget.gameEngine.currentPhase == GamePhase.day &&
              widget.gameEngine.currentScriptStep != null &&
              widget.gameEngine.currentScriptStep!.isNight == false);
          _scrollToBottom();
        },
        onGameEnd: (winner, message) {
          navigator.pop(); // Close dialog
          _showGameEndDialog(winner, message);
        },
      ),
    );
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

          // Adjustment: Ensure the active card sits below the top AppBar.
          final targetOffset = offset - 110.0;

          final current = _scrollController.offset;
          final distance = (targetOffset - current).abs();
          final clampedOffset = targetOffset.clamp(
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
    try {
      final step = widget.gameEngine.currentScriptStep;
      if (step != null &&
          (step.actionType == ScriptActionType.selectPlayer ||
              step.actionType == ScriptActionType.selectTwoPlayers)) {
        if (step.id == 'day_vote' && _voteCounts.isNotEmpty) {
          final votedPlayers =
              _voteCounts.entries.where((e) => e.value >= 2).toList();
          if (votedPlayers.isNotEmpty) {
            votedPlayers.sort((a, b) => b.value.compareTo(a.value));
            final mostVoted = votedPlayers.first;
            final maxVotes = mostVoted.value;
            final topVoters =
                votedPlayers.where((e) => e.value == maxVotes).toList();

            if (topVoters.length > 1) {
              // Tie handled silently (logged via engine if needed)
              widget.gameEngine.logAction(
                'Voting',
                'Vote tie! No one is eliminated.',
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
            final Player victim = player;

            // Check if victim survived (e.g. Second Wind)
            // If they are alive and have pending conversion, it's Second Wind.
            final bool survivedVote =
                victim.isAlive && victim.secondWindPendingConversion;

            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => ClubAlertDialog(
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
                      'Vote result',
                      style: TextStyle(fontSize: 20),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (survivedVote) ...[
                      const Text(
                        'SECOND WIND!',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${victim.name} refuses to die!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'The Dealers must decide their fate.',
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
                        (victim.role.id == 'tea_spiller' ||
                            victim.role.id == 'predator' ||
                            victim.role.id == 'drama_queen')) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
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
                                  'REACTIVE ROLE',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "This player was a ${victim.role.name}.\nOpen the Action Menu (FAB) immediately to trigger their retaliation ability!",
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
                      try {
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
                      } on GameException catch (e) {
                        _showError(e.message);
                      } catch (e) {
                        _showError(e.toString());
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: wasDealer
                          ? ClubBlackoutTheme.neonGreen
                          : ClubBlackoutTheme.neonRed,
                      foregroundColor: Colors.black,
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
    } on GameException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('An unexpected error occurred: $e');
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => ClubAlertDialog(
        title: const Text('Error', style: TextStyle(color: Colors.redAccent)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _executeNightAction(ScriptStep step) {
    if (_currentSelection.isEmpty) return;

    // 1. Comprehensive Logging for "Game Log" & Host Transparency
    // This ensures every tap of the green tick is recorded.
    final selectedNames = _currentSelection
        .map(
          (id) => widget.gameEngine.players.firstWhere((p) => p.id == id).name,
        )
        .join(', ');

    widget.gameEngine.logAction(
      'Action Confirmed: ${step.title}',
      'Host selected: $selectedNames',
    );

    // 2. Store Action in Engine
    if (step.actionType == ScriptActionType.selectTwoPlayers) {
      widget.gameEngine.nightActions[step.id] = _currentSelection.toList();
    } else {
      widget.gameEngine.nightActions[step.id] = _currentSelection.first;

      final targetId = _currentSelection.first;
      final target = widget.gameEngine.players.firstWhere(
        (p) => p.id == targetId,
      );

      // 3. Specific Role Logic & Host Status Documentation
      if (step.roleId == 'bouncer' &&
          step.actionType == ScriptActionType.selectPlayer) {
        // Add visual status for Host Overview
        if (!target.statusEffects.contains('Checked by Bouncer')) {
          target.statusEffects.add('Checked by Bouncer');
        }

        if (target.role.id == 'minor' && !target.minorHasBeenIDd) {
          target.minorHasBeenIDd = true;
          widget.gameEngine.logAction(
            'Bouncer Mechanic',
            'Bouncer checked The Minor (${target.name}). Minor loses immunity.',
          );
        }

        // Dealer check dialog
        final isDealerAlly =
            target.role.alliance == 'criminal' || target.role.id == 'dealer';
        _showBouncerConfirmation(target, isDealerAlly);
      } else if (step.id == 'creep_act') {
        // Log explicitly for transparency
        widget.gameEngine.logAction(
          'Creep Act',
          'The Creep is mimicking ${target.name} (${target.role.name})',
        );
        if (!target.statusEffects.contains('Mimicked by Creep')) {
          target.statusEffects.add('Mimicked by Creep');
        }
      } else if (step.id == 'clinger_obsession') {
        widget.gameEngine.logAction(
          'Clinger Act',
          'The Clinger is obsessed with ${target.name}',
        );
        // Note: Clinger obsession is usually secret, but Host needs to know.
        if (!target.statusEffects.contains('Clinger Obsession')) {
          target.statusEffects.add('Clinger Obsession');
        }
      } else if (step.id == 'sober_act') {
        target.soberSentHome = true;
        target.soberAbilityUsed = true;

        // Host Overview Status
        if (!target.statusEffects.contains('Sent Home')) {
          target.statusEffects.add('Sent Home');
        }

        widget.gameEngine.logAction(
          'Sober Mechanic',
          '${target.name} was sent home and will removed from script tonight.',
        );

        // Rebuild script immediately to remove the target's turn if they haven't acted
        widget.gameEngine.rebuildNightScript();
      } else if (step.roleId == 'club_manager') {
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
      builder: (context) => ClubAlertDialog(
        title: Text(
          isDealerAlly ? 'DEALER CONFIRMED' : 'NOT A DEALER',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDealerAlly
                ? ClubBlackoutTheme.neonGreen
                : ClubBlackoutTheme.neonRed,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDealerAlly ? Icons.check_circle : Icons.cancel,
              color: isDealerAlly
                  ? ClubBlackoutTheme.neonGreen
                  : ClubBlackoutTheme.neonRed,
              size: 60,
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
                  color: Colors.red.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.redAccent),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MINOR ID CHECKED',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Immunity stripped! The Minor is now vulnerable to Dealer attacks.',
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
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: isDealerAlly
                  ? ClubBlackoutTheme.neonGreen
                  : ClubBlackoutTheme.neonRed,
              foregroundColor: Colors.black,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCreepConfirmation(Player target) {
    showRoleReveal(
      context,
      target.role,
      target.name,
      subtitle: 'Creep Target',
      onComplete: () {}, // Optional callback
    );
  }

  void _showClingerConfirmation(Player target) {
    showRoleReveal(
      context,
      target.role,
      target.name,
      subtitle: 'OBSESSION TARGET',
      body: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ClubBlackoutTheme.neonPink.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ClubBlackoutTheme.neonPink.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: const Text(
          'They are now bound to this player. They must vote exactly as their object of obsession votes. If the obsession dies, the Clinger dies.',
          style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _showGameEndDialog(String winner, String message) {
    widget.gameEngine.currentPhase = GamePhase.endGame;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClubAlertDialog(
        title: Text(
          winner.toUpperCase() + ' WIN!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: winner.toLowerCase() == 'criminals'
                ? ClubBlackoutTheme.neonRed
                : ClubBlackoutTheme.neonGreen,
          ),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 18),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Leave game screen
            },
            style: FilledButton.styleFrom(
              backgroundColor: winner.toLowerCase() == 'criminals'
                  ? ClubBlackoutTheme.neonRed
                  : ClubBlackoutTheme.neonGreen,
              foregroundColor: Colors.black,
            ),
            child: const Text('RETURN TO LOBBY'),
          ),
        ],
      ),
    );
  }

  void _showClingerDoubleDeathDialog(String clingerName, String obsessionName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClubAlertDialog(
        title: const Text(
          'DOUBLE DEATH!',
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "$clingerName's obsession, $obsessionName, has died. As a Clinger, $clingerName dies with them!",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('CLOSE'),
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
        builder: (context) => ClubAlertDialog(
          title: const Text(
            'Taboo list',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: ClubBlackoutTheme.neonPurple,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                Column(
                  children: lightweight.tabooNames
                      .map(
                        (name) => ListTile(
                          leading: const Icon(
                            Icons.cancel,
                            color: ClubBlackoutTheme.neonPurple,
                          ),
                          title: Text(name),
                        ),
                      )
                      .toList(),
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
            ],
          ),
          actions: [
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
      );
    } catch (e) {
      debugPrint('Error showing taboo list: $e');
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
        builder: (context) => ClubAlertDialog(
          title: const Text(
            'Medic revive',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: ClubBlackoutTheme.neonGreen,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Use your ONE-TIME ability to bring a player back from the dead!',
                style: TextStyle(fontSize: 14, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 300,
                child: ListView(
                  children: validTargets
                      .map(
                        (player) => ListTile(
                          title: Text(player.name),
                          trailing: const Icon(Icons.add_circle),
                          onTap: () {
                            Navigator.pop(context);
                            _useMedicRevive(medic, player);
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
              child: const Text('CANCEL'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error showing Medic revive: $e');
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
        effect: AbilityEffect.other,
        priority: 1,
      ),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClubAlertDialog(
        title: const Icon(
          Icons.check_circle,
          color: ClubBlackoutTheme.neonGreen,
          size: 50,
        ),
        content: Text(
          '${target.name} has been revived!',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  void _showSilverFoxAbility() {
    // ... existing implementation ...
  }

  // ignore: unused_element
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
        builder: (context) => ClubAlertDialog(
          title: const Text(
            'Second Wind conversion',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFDE3163),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${secondWind.name} was killed by the Dealers!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Do the Dealers agree to convert The Second Wind and bring them back to life as a Dealer?',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _refuseSecondWindConversion(secondWind);
              },
              child: const Text('REFUSE'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _acceptSecondWindConversion(secondWind);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDE3163),
                foregroundColor: Colors.white,
              ),
              child: const Text('ACCEPT'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error showing Second Wind conversion: $e');
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
      debugPrint('Error converting Second Wind: $e');
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
        builder: (context) => ClubAlertDialog(
          title: const Text(
            'Attack Dog conversion',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFFF00),
            ),
          ),
          content: Text(
            'Did ${obsession.name} call ${clinger.name} a "controller"?',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _convertToAttackDog(clinger);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFFF00),
                foregroundColor: Colors.black,
              ),
              child: const Text('YES, CONVERT'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error showing attack dog conversion: $e');
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
      builder: (context) => ClubAlertDialog(
        title: Text(
          '${clinger.name} IS NOW AN ATTACK DOG',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFFF00),
          ),
        ),
        content: SizedBox(
          height: 300,
          child: ListView(
            children: killTargets
                .map(
                  (player) => ListTile(
                    title: Text(player.name),
                    trailing: const Icon(Icons.dangerous, color: Colors.red),
                    onTap: () {
                      Navigator.pop(context);
                      _executeAttackDogKill(clinger, player);
                    },
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
    setState(() {});
  }

  void _executeAttackDogKill(Player clinger, Player victim) {
    clinger.clingerAttackDogUsed = true;
    widget.gameEngine.processDeath(victim, cause: 'attack_dog_kill');
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

  // ignore: unused_element
  void _showClingerObsessionRole() {
    // ... existing ...
  }

  // ignore: unused_element
  void _showCreepTargetRole() {
    // ... existing ...
  }

  void _showRoleReveal(Player target, String actionTitle) {
    showDialog(
      context: context,
      builder: (context) => ClubAlertDialog(
        title: Text(
          actionTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              target.name,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              target.role.name,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: target.role.color,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CONTINUE'),
          ),
        ],
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
              return Card(
                color: isSelected
                    ? optionColor.withValues(alpha: 0.2)
                    : Theme.of(context).colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? optionColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _currentSelection.clear();
                      _currentSelection.add(option);
                    });
                    _advanceScript();
                  },
                  borderRadius: BorderRadius.circular(12),
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
      builder: (context) => ClubAlertDialog(
        title: const Text('Skip to next phase?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.gameEngine.skipToNextPhase();
              setState(() => _currentSelection.clear());
            },
            child: const Text('Skip'),
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

        return Scaffold(
          key: _scaffoldKey,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),
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
            title: const Text('CLUB BLACKOUT',
                style: TextStyle(color: Colors.white)),
            centerTitle: true,
            actions: const [],
          ),
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
          body: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'Backgrounds/Club Blackout App Background.png',
                  fit: BoxFit.cover,
                  errorBuilder: (c, o, s) => Container(color: Colors.black),
                ),
              ),
              if (steps.isNotEmpty && !isWaiting)
                Positioned.fill(
                  child: SafeArea(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 88, bottom: 200),
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
                            phaseName:
                                step.isNight ? 'PARTY TIME!' : 'CLUB IS CLOSED',
                            subtitle: step.id == 'club_closed'
                                ? step.readAloudText
                                : null,
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
                              player: player,
                              gameEngine: widget.gameEngine,
                            ),
                            if (isLast && step.id == 'day_vote')
                              _buildVotingGrid(step),
                            if (isLast &&
                                (step.actionType ==
                                        ScriptActionType.selectPlayer ||
                                    step.actionType ==
                                        ScriptActionType.selectTwoPlayers) &&
                                step.id != 'day_vote')
                              _buildPlayerSelectionList(step),
                            if (isLast &&
                                step.actionType ==
                                    ScriptActionType.toggleOption)
                              _buildToggleOptionGrid(step),
                            if (isLast &&
                                step.actionType ==
                                    ScriptActionType.binaryChoice)
                              _buildBinaryChoice(step),
                            if (isLast &&
                                step.actionType == ScriptActionType.showInfo)
                              _buildShowInfoAction(step),
                          ],
                        );
                      },
                    ),
                  ),
                )
              else if (isWaiting)
                const Center(
                  child: Text(
                    'Phase Complete',
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
                      child: const Text('CONTINUE'),
                    ),
                  ),
                ),
              if (_abilityFabExpanded) _buildAbilityFabMenu(),
              if (_rumourMillExpanded)
                Positioned.fill(child: _buildRumourMillPanel()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingActionBar(ScriptStep step) {
    // Hide forward button during player selection steps
    final isSelectionStep = (step.actionType == ScriptActionType.selectPlayer ||
            step.actionType == ScriptActionType.selectTwoPlayers) &&
        step.id != 'day_vote';

    // Recalculate ability availability for the FAB visibility
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
      (p) => p.role.id == 'bouncer' && p.isActive && !p.bouncerAbilityRevoked,
    );

    final hasAnyAbility = hasMessyBitch ||
        hasLightweight ||
        hasClingerToFree ||
        hasSecondWindConversion ||
        hasTeaSpiller ||
        hasPredator ||
        hasDramaQueen ||
        hasMedic ||
        hasSober ||
        hasBouncer;

    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Back Button
          IconButton.filled(
            onPressed: widget.gameEngine.regressScript,
            icon: const Icon(Icons.arrow_back),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white12,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
            ),
          ),

          // 2. FAB Menu Toggle (Black App Icon with Pink Glow)
          if (hasAnyAbility)
            GestureDetector(
              onTap: () =>
                  setState(() => _abilityFabExpanded = !_abilityFabExpanded),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: _abilityFabExpanded
                      ? [
                          BoxShadow(
                            color: Colors.pinkAccent.withValues(alpha: 0.8),
                            blurRadius: 25,
                            spreadRadius: 4,
                          ),
                          BoxShadow(
                            color: Colors.pink.withValues(alpha: 0.4),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ]
                      : [],
                ),
                child: Image.asset(
                  'Icons/Club Blackout App BLACK icon.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),

          // 3. Forward Button (or Spacer)
          if (!isSelectionStep)
            FilledButton(
              onPressed: _advanceScript,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: const CircleBorder(),
                visualDensity: VisualDensity.compact,
              ),
              child: const Icon(Icons.arrow_forward), // Icon only
            )
          else
            const SizedBox(
              width: 48,
            ), // Balance alignment if forward button is hidden
        ],
      ),
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
                  gameEngine: widget.gameEngine,
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

  Widget _buildPlayerSelectionList(ScriptStep step) {
    // Exclude players sent home by Sober from selection
    final players = sortedPlayersByDisplayName(
      widget.gameEngine.players
          .where((p) => p.isAlive && p.role.id != 'host' && !p.soberSentHome)
          .toList(),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: players.length,
        itemBuilder: (context, index) {
          final p = players[index];
          final isSelected = _currentSelection.contains(p.id);

          String stats = '';
          if (p.role.id == 'clinger' && p.clingerPartnerId != null) {
            final partner = widget.gameEngine.players.firstWhere(
              (pl) => pl.id == p.clingerPartnerId,
              orElse: () => p,
            );
            stats = 'Obsession: ${partner.name}';
          } else if (p.role.id == 'creep' && p.creepTargetId != null) {
            final target = widget.gameEngine.players.firstWhere(
              (pl) => pl.id == p.creepTargetId,
              orElse: () => p,
            );
            stats = 'Mimicking: ${target.role.name}';
          } else if (p.role.id == 'tea_spiller' &&
              p.teaSpillerTargetId != null) {
            final target = widget.gameEngine.players.firstWhere(
              (pl) => pl.id == p.teaSpillerTargetId,
              orElse: () => p,
            );
            stats = 'Target: ${target.name}';
          } else if (p.role.id == 'predator' && p.predatorTargetId != null) {
            final prey = widget.gameEngine.players.firstWhere(
              (pl) => pl.id == p.predatorTargetId,
              orElse: () => p,
            );
            stats = 'Prey: ${prey.name}';
          }

          return NightPhasePlayerTile(
            player: p,
            isSelected: isSelected,
            gameEngine: widget.gameEngine,
            statsText: stats,
            onTap: () {
              // Standard selection toggle
              _onPlayerSelected(p.id);
            },
            onConfirm: () {
              // Validation for 2-player selection
              if (step.actionType == ScriptActionType.selectTwoPlayers) {
                if (_currentSelection.length != 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select exactly 2 players.'),
                      backgroundColor: Colors.redAccent,
                      duration: Duration(seconds: 1),
                    ),
                  );
                  return;
                }
              }
              // Advance script on confirmation
              _advanceScript();
            },
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
                label: const Text('NO (KILL)'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.2),
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
                label: const Text('YES (CONVERT)'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(
                    0xFFDE3163,
                  ).withValues(alpha: 0.2), // Second Wind Pink
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

  Widget _buildShowInfoAction(ScriptStep step) {
    if (step.id != 'clinger_reveal' && step.id != 'creep_reveal') {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: FilledButton.icon(
          onPressed: () => _handleShowInfoAction(step),
          icon: const Icon(Icons.visibility),
          label: const Text('REVEAL INFORMATION'),
          style: ClubBlackoutTheme.neonButtonStyle(Colors.white),
        ),
      ),
    );
  }

  void _handleShowInfoAction(ScriptStep step) {
    if (step.id == 'clinger_reveal') {
      final targetId = widget.gameEngine.nightActions['clinger_obsession'];
      if (targetId != null) {
        final target = widget.gameEngine.players.firstWhere(
          (p) => p.id == targetId,
          orElse: () => widget.gameEngine.players.first,
        );
        _showClingerConfirmation(target);
      }
    } else if (step.id == 'creep_reveal') {
      final targetId = widget.gameEngine.nightActions['creep_act'];
      if (targetId != null) {
        final target = widget.gameEngine.players.firstWhere(
          (p) => p.id == targetId,
          orElse: () => widget.gameEngine.players.first,
        );
        _showCreepConfirmation(target);
      }
    }
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
          'msg': 'Messy Bitch: Rumour Mill is active! Open FAB to view.',
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
          'msg': 'Clinger Notification: Attack Dog ability available!',
        },
        {
          'id_base': 'second_wind_ready',
          'condition': widget.gameEngine.players.any(
            (p) =>
                p.role.id == 'second_wind' &&
                p.secondWindPendingConversion &&
                !p.secondWindConverted,
          ),
          'msg': 'Second Wind Notification: Conversion opportunity available!',
        },
        {
          'id_base': 'silver_fox_ready',
          'condition': false,
          'msg': 'Silver Fox disabled.',
        },
        {
          'id_base': 'tea_spiller_ready',
          'condition': widget.gameEngine.players.any(
            (p) =>
                p.role.id == 'tea_spiller' &&
                widget.gameEngine.deadPlayerIds.contains(p.id),
          ),
          'msg': 'Tea Spiller DIED: Check menu for Tea Spilling opportunity.',
        },
        {
          'id_base': 'predator_ready',
          'condition': widget.gameEngine.players.any(
            (p) =>
                p.role.id == 'predator' &&
                widget.gameEngine.deadPlayerIds.contains(p.id),
          ),
          'msg': 'Predator DIED: Check menu for Retaliation opportunity.',
        },
        {
          'id_base': 'drama_queen_ready',
          'condition': widget.gameEngine.dramaQueenSwapPending,
          'msg': 'Drama Queen died: swap two players now.',
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
          'msg': 'Medic: Revive ability is available.',
        },
        {
          'id_base': 'bouncer_ready',
          'condition': widget.gameEngine.players.any(
            (p) =>
                p.role.id == 'bouncer' &&
                p.isActive &&
                !p.bouncerAbilityRevoked,
          ),
          'msg': 'The Bouncer: Confront Roofi ability available.',
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
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Messy Bitch -> Rumour Mill (Info/Tool) - Active when Alive
            if (widget.gameEngine.players.any(
              (p) => p.role.id == 'messy_bitch' && p.isActive,
            ))
              _buildNeonFabParam(
                roleId: 'messy_bitch',
                onPressed: () => setState(() => _rumourMillExpanded = true),
              ),

            // Clinger -> Attack Dog (Manual Activation) - Active when Linked
            if (widget.gameEngine.players.any(
              (p) =>
                  p.role.id == 'clinger' &&
                  p.isActive &&
                  p.clingerPartnerId != null &&
                  !p.clingerAttackDogUsed,
            ))
              _buildNeonFabParam(
                roleId: 'clinger',
                onPressed: _showAttackDogConversion,
              ),

            // Second Wind -> Conversion (Manual Activation) - Active Pending
            if (widget.gameEngine.players.any(
              (p) =>
                  p.role.id == 'second_wind' &&
                  p.secondWindPendingConversion &&
                  !p.secondWindConverted,
            ))
              _buildNeonFabParam(
                roleId: 'second_wind',
                onPressed: _showSecondWindConversion,
              ),

            // Silver Fox disabled (host request)

            // Lightweight -> Taboo List (Info) - Active when Alive
            if (widget.gameEngine.players.any(
              (p) => p.role.id == 'lightweight' && p.isActive,
            ))
              _buildNeonFabParam(
                roleId: 'lightweight',
                onPressed: _showTabooList,
              ),

            // Tea Spiller -> Reveal (Death Reaction) - ONLY ACTIVE WHEN DEAD
            if (widget.gameEngine.players.any(
              (p) =>
                  p.role.id == 'tea_spiller' &&
                  widget.gameEngine.deadPlayerIds.contains(p.id),
            ))
              _buildNeonFabParam(
                roleId: 'tea_spiller',
                onPressed: _showTeaSpillerRevealDialog,
              ),

            // Predator -> Retaliation (Death Reaction) - ONLY ACTIVE WHEN DEAD
            if (widget.gameEngine.players.any(
              (p) =>
                  p.role.id == 'predator' &&
                  widget.gameEngine.deadPlayerIds.contains(p.id),
            ))
              _buildNeonFabParam(
                roleId: 'predator',
                onPressed: _showPredatorRetaliationDialog,
              ),

            // Drama Queen -> Swap (Death Reaction) - Active while pending
            if (widget.gameEngine.dramaQueenSwapPending)
              _buildNeonFabParam(
                roleId: 'drama_queen',
                onPressed: _showDramaQueenSwapDialog,
              ),

            // Medic -> Revive (Manual Activation - if Mode Correct) - Active when Alive
            if (widget.gameEngine.players.any(
              (p) =>
                  p.role.id == 'medic' &&
                  p.isActive &&
                  p.medicChoice == 'REVIVE' &&
                  !p.hasReviveToken,
            ))
              _buildNeonFabParam(
                roleId: 'medic',
                onPressed: _showMedicReviveDialog,
              ),

            // Bouncer -> Confront Roofi (Manual Activation)
            if (widget.gameEngine.players.any(
              (p) =>
                  p.role.id == 'bouncer' &&
                  p.isActive &&
                  !p.bouncerAbilityRevoked,
            ))
              _buildNeonFabParam(
                roleId: 'bouncer',
                onPressed: _showBouncerConfrontDialog,
              ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildNeonFabParam({
    required String roleId,
    required VoidCallback onPressed,
  }) {
    final player = widget.gameEngine.players.firstWhere(
      (p) => p.role.id == roleId,
      orElse: () => widget.gameEngine.players.first,
    );
    final color = player.role.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: () {
          setState(() => _abilityFabExpanded = false);
          onPressed();
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.6),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(color: color, width: 2),
          ),
          child: ClipOval(
            child: player.role.assetPath.isNotEmpty
                ? Image.asset(player.role.assetPath, fit: BoxFit.cover)
                : Icon(Icons.help, color: color),
          ),
        ),
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
      color: Colors.black.withValues(alpha: 0.95),
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
            style: const TextStyle(color: Colors.white70, fontSize: 16),
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
                        ? ClubBlackoutTheme.neonGreen.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.05),
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
                              hasHeard ? 'Has heard the rumour' : 'Uninformed',
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
                        const Icon(
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
          FilledButton(
            style: FilledButton.styleFrom(
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
      builder: (context) => ClubAlertDialog(
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
              'Does the Bouncer suspect someone? Select their target.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            const Text(
              '⚠️ RISK: If Bouncer is wrong, they lose their I.D. checking ability forever.',
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
    final bool success = target.role.id == 'roofi';

    setState(() {
      if (success) {
        try {
          final roofi = widget.gameEngine.players.firstWhere(
            (p) => p.role.id == 'roofi' && p.isActive,
          );
          roofi.roofiAbilityRevoked = true; // Revoke Roofi's ability
        } catch (_) {}

        widget.gameEngine.logAction(
          'Bouncer Confrontation',
          'Bouncer correctly identified Roofi (${target.name})!',
        );
        _showBouncerResultDialog(
          'SUCCESS',
          'You caught The Roofi!\nTheir power is neutralized.',
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
          'Bouncer Confrontation',
          'Bouncer incorrectly suspected ${target.name} as Roofi and lost their ability.',
        );
        _showBouncerResultDialog(
          'FAILURE',
          'That was not The Roofi.\nYou have lost your I.D. checking ability.',
          Colors.red,
        );
      }
    });
  }

  void _showBouncerResultDialog(String title, String body, Color color) {
    showDialog(
      context: context,
      builder: (context) => ClubAlertDialog(
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        content: Text(body, style: const TextStyle(color: Colors.white)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: color),
            child: const Text('OK', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showTeaSpillerRevealDialog() {
    showDialog(
      context: context,
      builder: (context) => ClubAlertDialog(
        title: Text(
          'TEA SPILLER REVEAL',
          style: ClubBlackoutTheme.headingStyle.copyWith(
            color: ClubBlackoutTheme.neonOrange,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The Tea Spiller has died. Select a player to reveal their role.',
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
                            'Tea Spiller Reveal',
                            'Tea Spiller revealed ${p.name} as ${p.role.name}.',
                          );
                          showRoleReveal(
                            context,
                            p.role,
                            p.name,
                            subtitle: 'Tea Spilled by the Dead!',
                          );
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
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  void _showPredatorRetaliationDialog() {
    // Show list of players to KILL
    showDialog(
      context: context,
      builder: (context) => ClubAlertDialog(
        title: Text(
          'PREDATOR RETALIATION',
          style: ClubBlackoutTheme.headingStyle.copyWith(
            color: Colors.grey,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The Predator was voted out. Select a player to take down with them.',
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
                            'Predator Retaliation',
                            'The Predator took ${p.name} down with them!',
                          );

                          // Refresh UI
                          setState(() {});

                          // Show confirmation
                          showDialog(
                            context: context,
                            builder: (ctx) => ClubAlertDialog(
                              title: const Text(
                                'ELIMINATED',
                                style: TextStyle(color: Colors.red),
                              ),
                              content: Text(
                                '${p.name} has been eliminated by The Predator.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('OK'),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  void _showDramaQueenSwapDialog() {
    final alivePlayers =
        widget.gameEngine.players.where((p) => p.isAlive).toList();
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
            return ClubAlertDialog(
              title: Text(
                'DRAMA QUEEN SWAP',
                style: ClubBlackoutTheme.headingStyle.copyWith(
                  color: ClubBlackoutTheme.neonPurple,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Drama Queen is dead. Pick two players to swap devices, then confirm.',
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
                          gameEngine: widget.gameEngine,
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
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                FilledButton(
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
                            builder: (ctx) => ClubAlertDialog(
                              title: const Text(
                                'SWAP COMPLETE',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${p1.name} is now ${p1.role.name}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${p2.name} is now ${p2.role.name}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Host instructions:\n1) Ask all players to close their eyes.\n2) Swap the devices/cards.\n3) Give everyone 10 seconds to check their role.\n4) Resume into the next night.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('ACKNOWLEDGE'),
                                ),
                              ],
                            ),
                          );
                          setState(() {});
                        }
                      : null,
                  child: const Text('CONFIRM SWAP'),
                ),
              ],
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
      return const Card(
        color: Colors.white10,
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.wb_sunny, color: Colors.white30),
              SizedBox(width: 16),
              Text(
                'Day Phase Completed',
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
                  // Advance through all remaining day phase steps (summary, discussion, vote)
                  // The dialog handles them together as one cohesive day phase
                  int safety = 0;
                  do {
                    widget.gameEngine.advanceScript();
                    safety++;
                  } while (safety < 10 &&
                      widget.gameEngine.currentPhase == GamePhase.day &&
                      widget.gameEngine.currentScriptStep != null &&
                      widget.gameEngine.currentScriptStep!.isNight == false);
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
            child: Text('BEGIN DAY PHASE', style: TextStyle(fontSize: 20)),
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
    return ClubAlertDialog(
      title: Row(
        children: [
          const Icon(
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
      content: SizedBox(
        width: double.maxFinite,
        height: 600,
        child: gameEngine.gameLog.isEmpty
            ? Center(
                child: Text(
                  'No events recorded yet.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: gameEngine.gameLog.reversed.length,
                itemBuilder: (context, index) {
                  final reversedList = gameEngine.gameLog.reversed.toList();
                  final entry = reversedList[index];
                  final ts = entry.timestamp.toLocal();
                  final hh = ts.hour.toString().padLeft(2, '0');
                  final mm = ts.minute.toString().padLeft(2, '0');
                  final ss = ts.second.toString().padLeft(2, '0');
                  final timeLabel = '$hh:$mm:$ss';
                  final headerLine =
                      'Turn ${entry.turn}  ·  ${entry.phase.toUpperCase()}  ·  $timeLabel';
                  const dotted = '···························';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
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
                          const Text(
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
                              color: Colors.white.withValues(alpha: 0.25),
                              fontSize: 12,
                              letterSpacing: 1.5,
                              fontFamily: 'RobotoMono',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            entry.action.toUpperCase(),
                            style: const TextStyle(
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
                              color: Colors.white.withValues(alpha: 0.25),
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
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  fontFamily: 'RobotoMono',
                                ),
                              ),
                              const Spacer(),
                              const Text(
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
      actions: [
        SizedBox(
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
      ],
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
                ).withValues(alpha: 0.6 + (_animation.value * 0.4)),
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
