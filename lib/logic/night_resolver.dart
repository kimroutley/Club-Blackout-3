import '../models/player.dart';

/// Represents a night action submitted by a role
class NightAction {
  final String actorId;
  final String roleId;
  final String actionType; // 'protect', 'send_home', 'kill', 'silence', etc.
  final String? targetId;
  final int priority;

  NightAction({
    required this.actorId,
    required this.roleId,
    required this.actionType,
    this.targetId,
    required this.priority,
  });
}

/// Deterministic night resolution system
/// 
/// Phases (in order):
/// 1. send_home (Sober) - priority 1
/// 2. roofi - priority 3
/// 3. medic - priority 1-2
/// 4. bouncer - priority 2
/// 5. dealers - priority 5
/// 6. finalize - apply all deaths
///
/// Dealer kill selection: most-targeted; tie-breaker: lexicographic order of target id
/// If Sober sends a Dealer home, cancel dealer kills for that night
class NightResolver {
  /// Resolve night actions and determine who dies
  /// 
  /// Mutates Player.isAlive appropriately and returns Set<String> of death ids.
  /// GameEngine should run reaction systems after calling this resolver.
  Set<String> resolve(List<Player> players, List<NightAction> actions) {
    final Set<String> deaths = {};
    final Set<String> protected = {};
    final Set<String> sentHome = {};
    
    // Sort actions by priority (lower priority number = earlier execution)
    final sortedActions = List<NightAction>.from(actions)
      ..sort((a, b) => a.priority.compareTo(b.priority));
    
    // Phase 1: Sober send_home (priority 1)
    for (var action in sortedActions) {
      if (action.actionType == 'send_home' && action.targetId != null) {
        sentHome.add(action.targetId!);
        protected.add(action.targetId!); // Sent home = protected from death
      }
    }
    
    // Phase 2: Roofi silence (priority 3) - no death impact, just tracking
    // (silencing is handled separately in game state)
    
    // Phase 3: Medic protection (priority 1-2)
    for (var action in sortedActions) {
      if (action.actionType == 'protect' && action.targetId != null) {
        protected.add(action.targetId!);
      }
    }
    
    // Phase 4: Bouncer ID check (priority 2) - no death impact
    // (ID checking is handled separately in game state)
    
    // Phase 5: Dealer kills (priority 5)
    // Check if any Dealer was sent home - if so, cancel all dealer kills
    final dealersSentHome = players.where((p) => 
      p.role.id == 'dealer' && sentHome.contains(p.id)
    ).isNotEmpty;
    
    if (!dealersSentHome) {
      // Collect all dealer kill actions
      final dealerKills = sortedActions.where((a) => 
        a.actionType == 'kill' && a.roleId == 'dealer' && a.targetId != null
      ).toList();
      
      if (dealerKills.isNotEmpty) {
        // Count targets
        final Map<String, int> targetCounts = {};
        for (var kill in dealerKills) {
          targetCounts[kill.targetId!] = (targetCounts[kill.targetId!] ?? 0) + 1;
        }
        
        // Find most-targeted
        int maxCount = 0;
        for (var count in targetCounts.values) {
          if (count > maxCount) maxCount = count;
        }
        
        // Get all targets with max count
        final mostTargeted = targetCounts.entries
          .where((e) => e.value == maxCount)
          .map((e) => e.key)
          .toList();
        
        // Tie-breaker: lexicographic order
        mostTargeted.sort();
        final chosenTarget = mostTargeted.first;
        
        // Apply kill if not protected
        if (!protected.contains(chosenTarget)) {
          final victim = players.firstWhere((p) => p.id == chosenTarget);
          
          // Check Minor protection
          if (victim.role.id == 'minor' && !victim.minorHasBeenIDd) {
            victim.minorHasBeenIDd = true;
            // Kill fails, but Minor is now vulnerable
          } else {
            victim.isAlive = false;
            deaths.add(chosenTarget);
          }
        }
      }
    }
    
    // Phase 6: Other kills (non-dealer)
    for (var action in sortedActions) {
      if (action.actionType == 'kill' && action.roleId != 'dealer' && action.targetId != null) {
        if (!protected.contains(action.targetId!)) {
          final victim = players.firstWhere((p) => p.id == action.targetId!);
          victim.isAlive = false;
          deaths.add(action.targetId!);
        }
      }
    }
    
    return deaths;
  }
  
  /// Check victory conditions
  /// Returns 'dealers' if dealers reach parity, 'party_animals' if no dealers left, null otherwise
  String? checkVictory(List<Player> players) {
    final alivePlayers = players.where((p) => p.isAlive).toList();
    final aliveDealers = alivePlayers.where((p) => 
      p.role.id == 'dealer' || (p.role.id == 'whore' && p.isAlive)
    ).length;
    final aliveNonDealers = alivePlayers.length - aliveDealers;
    
    // Dealers win at parity
    if (aliveDealers > 0 && aliveDealers >= aliveNonDealers) {
      return 'dealers';
    }
    
    // Party Animals win if no dealers left
    if (aliveDealers == 0) {
      return 'party_animals';
    }
    
    return null;
  }
}
