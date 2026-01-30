import 'dart:math';

import '../models/script_step.dart';
import 'game_engine.dart';

class MonteCarloWinOddsResult {
  final int runs;
  final int completed;
  final int seed;

  /// Winner token -> count. Tokens match [GameEndResult.winner].
  final Map<String, int> wins;

  /// Winner token -> probability (0..1), normalized across [completed].
  final Map<String, double> odds;

  /// Human-readable note about what was simulated.
  final String note;

  const MonteCarloWinOddsResult({
    required this.runs,
    required this.completed,
    required this.seed,
    required this.wins,
    required this.odds,
    required this.note,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'runsRequested': runs,
        'runsCompleted': completed,
        'seed': seed,
        'wins': wins,
        'odds': odds,
        'note': note,
      };
}

class MonteCarloSimulator {
  /// Runs a Monte Carlo simulation starting from the given engine state.
  ///
  /// Implementation notes:
  /// - Clones engine state via [GameEngine.exportSaveBlobMap] + [GameEngine.importSaveBlobMap].
  /// - Auto-selects random valid-ish targets for script steps.
  /// - Resolves day voting using [GameEngine.voteOutPlayer] so special rules apply.
  /// - Auto-resolves pending reactions (Predator retaliation, Drama Queen swap).
  static Future<MonteCarloWinOddsResult> simulateWinOdds(
    GameEngine base, {
    int runs = 250,
    int? seed,
    int maxStepsPerRun = 25000,
    void Function(int completedRuns, int totalRuns)? onProgress,
  }) async {
    final endAlready = base.checkGameEnd();
    if (endAlready != null) {
      return MonteCarloWinOddsResult(
        runs: runs,
        completed: 0,
        seed: seed ?? 0,
        wins: const <String, int>{},
        odds: const <String, double>{},
        note: 'Game is already over; no simulations were run.',
      );
    }

    final effectiveSeed = seed ?? DateTime.now().millisecondsSinceEpoch;
    final rng = Random(effectiveSeed);

    final baseMap = base.exportSaveBlobMap(includeLog: false);

    final wins = <String, int>{};
    var completed = 0;

    for (var i = 0; i < runs; i++) {
      final sim = GameEngine(
        roleRepository: base.roleRepository,
        loadNameHistory: false,
        silent: true,
      );
      await sim.importSaveBlobMap(baseMap, notify: false);

      final winner = _playToEnd(sim, rng, maxStepsPerRun: maxStepsPerRun);
      if (winner != null) {
        wins[winner] = (wins[winner] ?? 0) + 1;
        completed++;
      }

      if (onProgress != null) {
        onProgress(i + 1, runs);
      }

      // Yield to the UI every ~25 runs.
      if ((i + 1) % 25 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    final odds = <String, double>{};
    if (completed > 0) {
      for (final e in wins.entries) {
        odds[e.key] = (e.value / completed).clamp(0.0, 1.0);
      }
    }

    return MonteCarloWinOddsResult(
      runs: runs,
      completed: completed,
      seed: effectiveSeed,
      wins: wins,
      odds: odds,
      note: 'Monte Carlo simulation from the current engine state. Random actions + votes; includes special vote rules (Whore/Predator) and pending reactions (Drama Queen/Predator).',
    );
  }

  static String? _playToEnd(
    GameEngine engine,
    Random rng, {
    required int maxStepsPerRun,
  }) {
    // Defensive: avoid infinite loops in case scripts stall.
    for (var steps = 0; steps < maxStepsPerRun; steps++) {
      final end = engine.checkGameEnd();
      if (end != null) return end.winner;

      final step = engine.currentScriptStep;
      if (step == null) {
        engine.advanceScript();
        _autoResolvePendingReactions(engine, rng);
        continue;
      }

      switch (step.actionType) {
        case ScriptActionType.none:
        case ScriptActionType.showInfo:
        case ScriptActionType.info:
        case ScriptActionType.showTimer:
        case ScriptActionType.phaseTransition:
        case ScriptActionType.discussion:
          engine.handleScriptAction(step, const <String>[]);
          engine.advanceScript();
          _autoResolvePendingReactions(engine, rng);
          break;

        case ScriptActionType.showDayScene:
          _simulateDayVote(engine, rng);
          engine.advanceScript();
          _autoResolvePendingReactions(engine, rng);
          break;

        case ScriptActionType.optional:
          // 50/50: act vs skip. (Most optional behaviors are modeled as toggleOption today.)
          if (rng.nextBool()) {
            engine.handleScriptAction(step, const <String>[]);
          } else {
            engine.handleScriptAction(step, const <String>[]);
          }
          engine.advanceScript();
          _autoResolvePendingReactions(engine, rng);
          break;

        case ScriptActionType.toggleOption:
          final option = _pickOption(step, rng);
          if (option != null) {
            engine.handleScriptOption(step, option);
          } else {
            engine.handleScriptAction(step, const <String>[]);
          }
          engine.advanceScript();
          _autoResolvePendingReactions(engine, rng);
          break;

        case ScriptActionType.binaryChoice:
          engine.handleScriptAction(step, <String>[rng.nextBool() ? 'yes' : 'no']);
          engine.advanceScript();
          _autoResolvePendingReactions(engine, rng);
          break;

        case ScriptActionType.selectPlayer:
          final target = _pickTargetId(engine, step, rng);
          if (target != null) {
            engine.handleScriptAction(step, <String>[target]);
          } else {
            engine.handleScriptAction(step, const <String>[]);
          }
          engine.advanceScript();
          _autoResolvePendingReactions(engine, rng);
          break;

        case ScriptActionType.selectTwoPlayers:
          final targets = _pickTwoTargetIds(engine, step, rng);
          if (targets.length == 2) {
            engine.handleScriptAction(step, targets);
          } else {
            engine.handleScriptAction(step, const <String>[]);
          }
          engine.advanceScript();
          _autoResolvePendingReactions(engine, rng);
          break;
      }
    }

    // If we hit max steps, count it as null (dropped run).
    return null;
  }

  static void _simulateDayVote(GameEngine engine, Random rng) {
    final voters = engine.players
        .where((p) => p.isAlive && p.isEnabled && p.role.id != 'host')
        .where((p) => !p.soberSentHome)
        .toList(growable: false);

    final targets = engine.players
        .where((p) => p.isAlive && p.isEnabled && p.role.id != 'host')
        .toList(growable: false);

    if (voters.isEmpty || targets.isEmpty) {
      return;
    }

    // Cast random votes.
    for (final voter in voters) {
      final target = targets[rng.nextInt(targets.length)];
      engine.recordVote(voterId: voter.id, targetId: target.id);
    }

    final tallies = <String, int>{};
    for (final entry in engine.eligibleDayVotesByTarget.entries) {
      tallies[entry.key] = entry.value.length;
    }

    String? votedOutId;
    if (tallies.isNotEmpty) {
      var best = -1;
      final leaders = <String>[];
      for (final e in tallies.entries) {
        if (e.value > best) {
          best = e.value;
          leaders
            ..clear()
            ..add(e.key);
        } else if (e.value == best) {
          leaders.add(e.key);
        }
      }
      votedOutId = leaders.isNotEmpty ? leaders[rng.nextInt(leaders.length)] : null;
    }

    // Fallback to a random alive target if tally was empty.
    votedOutId ??= targets[rng.nextInt(targets.length)].id;

    engine.voteOutPlayer(votedOutId);

    // If Predator died by vote, retaliation becomes pending and must be resolved.
    _autoResolvePendingReactions(engine, rng);
  }

  static void _autoResolvePendingReactions(GameEngine engine, Random rng) {
    // Drama Queen swap.
    if (engine.dramaQueenSwapPending) {
      final aId = engine.dramaQueenMarkedAId;
      final bId = engine.dramaQueenMarkedBId;

      final alive = engine.players
          .where((p) => p.isAlive && p.isEnabled && p.role.id != 'host')
          .toList(growable: false);

      if (alive.length >= 2) {
        final a = aId != null
            ? alive.where((p) => p.id == aId).firstOrNull
            : null;
        final b = bId != null
            ? alive.where((p) => p.id == bId).firstOrNull
            : null;

        if (a != null && b != null && a.id != b.id) {
          engine.completeDramaQueenSwap(a, b);
        } else {
          final i = rng.nextInt(alive.length);
          var j = rng.nextInt(alive.length);
          if (j == i) j = (j + 1) % alive.length;
          engine.completeDramaQueenSwap(alive[i], alive[j]);
        }
      }
    }

    // Predator retaliation.
    final predatorId = engine.pendingPredatorId;
    if (predatorId != null) {
      final alive = engine.players
          .where((p) => p.isAlive && p.isEnabled && p.role.id != 'host')
          .toList(growable: false);

      if (alive.isEmpty) {
        engine.completePredatorRetaliation('');
        return;
      }

      final eligibleIds = engine.pendingPredatorEligibleVoterIds;
      final eligible = eligibleIds.isNotEmpty
          ? alive.where((p) => eligibleIds.contains(p.id)).toList(growable: false)
          : alive.where((p) => p.id != predatorId).toList(growable: false);

      if (eligible.isNotEmpty) {
        final preferred = engine.pendingPredatorPreferredTargetId;
        final pick = preferred != null && eligible.any((p) => p.id == preferred)
            ? preferred
            : eligible[rng.nextInt(eligible.length)].id;
        engine.completePredatorRetaliation(pick);
      } else {
        // Fall back to any alive non-predator.
        final fallback = alive.where((p) => p.id != predatorId).toList();
        if (fallback.isNotEmpty) {
          engine.completePredatorRetaliation(fallback[rng.nextInt(fallback.length)].id);
        }
      }
    }
  }

  static String? _pickOption(ScriptStep step, Random rng) {
    final roleId = step.roleId;
    if (roleId == null) return null;

    switch (roleId) {
      case 'medic':
        // Setup choice.
        return rng.nextBool() ? 'PROTECT' : 'REVIVE';
      case 'wallflower':
        // Weighted: mostly skip.
        final roll = rng.nextDouble();
        if (roll < 0.55) return 'SKIP';
        if (roll < 0.90) return 'PEEK';
        return 'STARE';
      default:
        return null;
    }
  }

  static String? _pickTargetId(GameEngine engine, ScriptStep step, Random rng) {
    final roleId = step.roleId;

    final candidates = engine.players
        .where((p) => p.isAlive && p.isEnabled && p.role.id != 'host')
        .toList();

    if (candidates.isEmpty) return null;

    // Role-specific filtering to reduce rejected selections.
    if (roleId == 'whore') {
      final whore = engine.players.where((p) => p.isAlive && p.isEnabled && p.role.id == 'whore').firstOrNull;
      candidates.removeWhere((p) => whore != null && p.id == whore.id);
      candidates.removeWhere((p) => p.role.id == 'dealer' || p.alliance.toLowerCase().contains('dealer'));
    }

    return candidates.isNotEmpty ? candidates[rng.nextInt(candidates.length)].id : null;
  }

  static List<String> _pickTwoTargetIds(GameEngine engine, ScriptStep step, Random rng) {
    final candidates = engine.players
        .where((p) => p.isAlive && p.isEnabled && p.role.id != 'host')
        .map((p) => p.id)
        .toList();

    if (candidates.length < 2) return const <String>[];

    final i = rng.nextInt(candidates.length);
    var j = rng.nextInt(candidates.length);
    if (j == i) j = (j + 1) % candidates.length;

    return <String>[candidates[i], candidates[j]];
  }
}
