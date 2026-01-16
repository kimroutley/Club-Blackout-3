import '../models/player.dart';

/// Represents a single night action by a player
class NightAction {
  final String playerId;
  final String actionType; // 'send_home', 'roofi', 'medic', 'bouncer', 'dealer_kill', etc.
  final String? targetId;
  final Map<String, dynamic> metadata;

  NightAction({
    required this.playerId,
    required this.actionType,
    this.targetId,
    this.metadata = const {},
  });

  @override
  String toString() {
    return 'NightAction(playerId: $playerId, actionType: $actionType, targetId: $targetId, metadata: $metadata)';
  }
}

/// Resolves night actions in a deterministic order
class NightResolver {
  /// Resolve all night actions in deterministic order:
  /// 1. send_home (Sober) - priority 1
  /// 2. roofi - priority 4
  /// 3. medic - priority 2
  /// 4. bouncer - priority 2
  /// 5. dealers - priority 5
  /// 6. finalize - apply all effects
  ///
  /// Mutates Player.isAlive for killed players.
  /// Returns Set<String> of dead player IDs (newly killed this night).
  static Set<String> resolve(List<Player> players, List<NightAction> actions) {
    final playerMap = {for (var p in players) p.id: p};
    final deadThisNight = <String>{};
    
    // Track protections and effects
    final protected = <String>{};
    final silenced = <String, int>{};
    String? soberSentHomeId;
    bool dealerSentHome = false;

    // Sort actions by priority (deterministic)
    final sortedActions = List<NightAction>.from(actions);
    sortedActions.sort((a, b) {
      final priorityA = _getActionPriority(a.actionType);
      final priorityB = _getActionPriority(b.actionType);
      if (priorityA != priorityB) return priorityA.compareTo(priorityB);
      // Tie-break by playerId for determinism
      return a.playerId.compareTo(b.playerId);
    });

    // Phase 1: Send home (Sober)
    for (var action in sortedActions) {
      if (action.actionType == 'send_home' && action.targetId != null) {
        soberSentHomeId = action.targetId;
        final target = playerMap[action.targetId];
        if (target != null) {
          target.soberSentHome = true;
          protected.add(action.targetId!);
          // Check if a dealer was sent home
          if (target.role.alliance == 'The Dealers') {
            dealerSentHome = true;
          }
        }
      }
    }

    // Phase 2: Roofi (silence)
    for (var action in sortedActions) {
      if (action.actionType == 'roofi' && action.targetId != null) {
        final target = playerMap[action.targetId];
        if (target != null && target.isAlive) {
          final currentDay = action.metadata['currentDay'] as int? ?? 0;
          silenced[action.targetId!] = currentDay;
          target.silencedDay = currentDay;
        }
      }
    }

    // Phase 3: Medic (protect)
    for (var action in sortedActions) {
      if (action.actionType == 'medic' && action.targetId != null) {
        final medicChoice = action.metadata['medicChoice'] as String?;
        if (medicChoice == 'PROTECT_DAILY') {
          protected.add(action.targetId!);
        }
        // Note: RESUSCITATE_ONCE is handled separately, not in night resolution
      }
    }

    // Phase 4: Bouncer (ID check - no kill effects)
    for (var action in sortedActions) {
      if (action.actionType == 'bouncer' && action.targetId != null) {
        final target = playerMap[action.targetId];
        if (target != null) {
          target.idCheckedByBouncer = true;
        }
      }
    }

    // Phase 5: Dealers (kills)
    if (!dealerSentHome) {
      // Collect all dealer kill votes
      final dealerKillVotes = <String, int>{};
      for (var action in sortedActions) {
        if (action.actionType == 'dealer_kill' && action.targetId != null) {
          dealerKillVotes[action.targetId!] = 
              (dealerKillVotes[action.targetId!] ?? 0) + 1;
        }
      }

      // Select target: most votes, tie-break by lexicographic order
      if (dealerKillVotes.isNotEmpty) {
        final maxVotes = dealerKillVotes.values.reduce((a, b) => a > b ? a : b);
        final topTargets = dealerKillVotes.entries
            .where((e) => e.value == maxVotes)
            .map((e) => e.key)
            .toList();
        topTargets.sort(); // Lexicographic tie-break
        final selectedTarget = topTargets.first;

        // Apply kill if not protected
        if (!protected.contains(selectedTarget)) {
          final target = playerMap[selectedTarget];
          if (target != null && target.isAlive) {
            // Check Minor protection
            if (target.role.id == 'minor' && !target.minorHasBeenIDd) {
              target.minorHasBeenIDd = true;
              // Kill fails, but Minor is now exposed
            } else {
              // Apply kill
              target.kill();
              if (!target.isAlive) {
                deadThisNight.add(selectedTarget);
              }
            }
          }
        }
      }
    }

    // Phase 6: Finalize - reset temporary flags
    for (var player in players) {
      if (player.soberSentHome) {
        player.soberSentHome = false;
      }
    }

    return deadThisNight;
  }

  /// Get priority for action type (lower = earlier)
  static int _getActionPriority(String actionType) {
    switch (actionType) {
      case 'send_home':
        return 1;
      case 'medic':
        return 2;
      case 'bouncer':
        return 2;
      case 'roofi':
        return 4;
      case 'dealer_kill':
        return 5;
      default:
        return 99; // Unknown actions last
    }
  }
}
