import '../models/player.dart';

/// Represents a night action taken by a player
class NightAction {
  final String playerId;
  final String actionType; // 'kill', 'protect', 'send_home', 'silence'
  final String? targetId;
  
  const NightAction({
    required this.playerId,
    required this.actionType,
    this.targetId,
  });
}

/// Deterministic night resolver that processes night actions in a specific order
/// and returns the set of deaths while mutating Player.isAlive
class NightResolver {
  /// Process night actions in deterministic phase order:
  /// send_home → roofi → medic → bouncer → dealers → finalize
  /// 
  /// Returns a set of player IDs who died this night
  /// Mutates Player.isAlive for killed players
  Set<String> resolve(List<Player> players, List<NightAction> actions) {
    final deaths = <String>{};
    final protections = <String>{};
    final sentHome = <String>{};
    final silenced = <String>{};
    
    // Phase 1: Send Home (Sober) - priority 1
    final sendHomeActions = actions.where((a) => a.actionType == 'send_home').toList();
    for (final action in sendHomeActions) {
      if (action.targetId != null) {
        sentHome.add(action.targetId!);
      }
    }
    
    // Phase 2: Roofi (silence) - priority 3
    final silenceActions = actions.where((a) => a.actionType == 'silence').toList();
    for (final action in silenceActions) {
      if (action.targetId != null) {
        silenced.add(action.targetId!);
      }
    }
    
    // Phase 3: Medic (protect) - priority 2 (runs after send_home in code but priority 2)
    final protectActions = actions.where((a) => a.actionType == 'protect').toList();
    for (final action in protectActions) {
      if (action.targetId != null) {
        protections.add(action.targetId!);
      }
    }
    
    // Phase 4: Bouncer (investigative, no death impact) - priority 2
    // Bouncer actions don't affect deaths
    
    // Phase 5: Dealers (kill) - priority 5
    // Determine dealer kills by vote count, with lexicographic tie-breaking
    final killActions = actions.where((a) => a.actionType == 'kill').toList();
    
    // Check if any Dealer was sent home - if so, cancel all dealer kills
    final dealersSentHome = sentHome.any((targetId) {
      try {
        final player = players.firstWhere((p) => p.id == targetId);
        return player.role.alliance == 'The Dealers';
      } catch (e) {
        return false;
      }
    });
    
    if (!dealersSentHome && killActions.isNotEmpty) {
      // Count votes for each target
      final voteCounts = <String, int>{};
      for (final action in killActions) {
        if (action.targetId != null) {
          voteCounts[action.targetId!] = (voteCounts[action.targetId!] ?? 0) + 1;
        }
      }
      
      if (voteCounts.isNotEmpty) {
        // Find maximum vote count
        final maxVotes = voteCounts.values.reduce((a, b) => a > b ? a : b);
        
        // Get all targets with max votes
        final topTargets = voteCounts.entries
            .where((e) => e.value == maxVotes)
            .map((e) => e.key)
            .toList();
        
        // If tie, use lexicographic order (alphabetical by player name)
        if (topTargets.length > 1) {
          // Sort by player name lexicographically
          topTargets.sort((a, b) {
            try {
              final playerA = players.firstWhere((p) => p.id == a);
              final playerB = players.firstWhere((p) => p.id == b);
              return playerA.name.compareTo(playerB.name);
            } catch (e) {
              return 0;
            }
          });
        }
        
        final targetId = topTargets.first;
        
        // Check if target is protected or sent home
        if (!protections.contains(targetId) && !sentHome.contains(targetId)) {
          deaths.add(targetId);
        }
      }
    }
    
    // Phase 6: Finalize - mutate Player.isAlive
    for (final playerId in deaths) {
      final player = players.firstWhere((p) => p.id == playerId);
      player.isAlive = false;
    }
    
    return deaths;
  }
}
