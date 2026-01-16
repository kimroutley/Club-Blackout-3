import '../models/player.dart';

/// Represents a queued night action
class NightAction {
  final String roleId;
  final String sourcePlayerId;
  final String? targetPlayerId;
  final String actionType; // 'send_home', 'silence', 'protect', 'check', 'kill'
  final int priority;

  NightAction({
    required this.roleId,
    required this.sourcePlayerId,
    this.targetPlayerId,
    required this.actionType,
    required this.priority,
  });
}

/// Result of night resolution
class NightResolutionResult {
  final Set<String> deadPlayerIds;
  final Map<String, String> metadata;

  NightResolutionResult({
    required this.deadPlayerIds,
    this.metadata = const {},
  });
}

/// Deterministic night action resolver
/// Processes night actions in explicit priority order to ensure repeatable outcomes
class NightResolver {
  /// Resolve all night actions and return set of player IDs who died
  /// Does not run reactions - GameEngine is expected to run ReactionSystem after
  static NightResolutionResult resolve(
    List<Player> players,
    List<NightAction> actions,
  ) {
    // Sort actions by priority (lower = earlier)
    final sortedActions = List<NightAction>.from(actions)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    // Track state throughout resolution
    final Set<String> protectedPlayerIds = {};
    final Set<String> sentHomePlayerIds = {};
    final Set<String> deadPlayerIds = {};
    final Map<String, String> metadata = {};

    // Phase 1: Send Home (Sober) - priority 1
    for (final action in sortedActions.where((a) => a.actionType == 'send_home')) {
      if (action.targetPlayerId != null) {
        sentHomePlayerIds.add(action.targetPlayerId!);
        protectedPlayerIds.add(action.targetPlayerId!);
        
        // Find target player and check if dealer
        final target = players.firstWhere(
          (p) => p.id == action.targetPlayerId,
          orElse: () => players.first,
        );
        if (target.role.id == 'dealer') {
          metadata['dealer_sent_home'] = 'true';
        }
      }
    }

    // Phase 2: Roofi (silence) - priority 2
    for (final action in sortedActions.where((a) => a.actionType == 'silence')) {
      // Roofi actions don't affect kill resolution, just track for metadata
      if (action.targetPlayerId != null) {
        metadata['silenced_${action.targetPlayerId}'] = 'true';
      }
    }

    // Phase 3: Medic (protect) - priority 3
    for (final action in sortedActions.where((a) => a.actionType == 'protect')) {
      if (action.targetPlayerId != null) {
        protectedPlayerIds.add(action.targetPlayerId!);
      }
    }

    // Phase 4: Bouncer (check) - priority 4
    for (final action in sortedActions.where((a) => a.actionType == 'check')) {
      // Bouncer checks don't affect kill resolution, just track for metadata
      if (action.targetPlayerId != null) {
        metadata['checked_${action.targetPlayerId}'] = 'true';
      }
    }

    // Phase 5: Dealers (kill) - priority 5
    // Check if dealer cancel is triggered (Sober sent a dealer home)
    if (_dealerCancelTriggered(metadata)) {
      metadata['dealer_kill_cancelled'] = 'true';
    } else {
      final killActions = sortedActions.where((a) => a.actionType == 'kill').toList();
      
      if (killActions.isNotEmpty) {
        // Deterministic target selection by vote count, tie broken by lexical order
        final targetId = _chooseDealerKillTarget(killActions);
        
        if (targetId != null) {
          metadata['kill_target'] = targetId;
          
          // Check if target is protected
          if (!protectedPlayerIds.contains(targetId)) {
            // Find the target player
            final target = players.firstWhere(
              (p) => p.id == targetId,
              orElse: () => players.first,
            );
            
            // Check for special protections
            final isDealerAttempt = true;
            
            // Minor protection (if not ID'd by bouncer)
            if (target.role.id == 'minor' && !target.minorHasBeenIDd) {
              metadata['minor_protected_$targetId'] = 'true';
            } 
            // Multi-life roles
            else if (target.lives > 1) {
              metadata['life_lost_$targetId'] = 'true';
              // Lives are decremented by GameEngine after resolution
            } 
            // Ally Cat with lives
            else if (target.role.id == 'ally_cat' && target.lives > 0) {
              metadata['ally_cat_life_lost_$targetId'] = 'true';
            }
            // Second Wind (pending conversion check happens in GameEngine)
            else if (target.role.id == 'second_wind' && 
                     !target.secondWindConverted && 
                     !target.secondWindRefusedConversion) {
              metadata['second_wind_triggered_$targetId'] = 'true';
            }
            // Standard kill
            else {
              deadPlayerIds.add(targetId);
            }
          } else {
            metadata['protected_$targetId'] = 'true';
          }
        }
      }
    }

    // Phase 6: Finalize - no additional actions
    
    return NightResolutionResult(
      deadPlayerIds: deadPlayerIds,
      metadata: metadata,
    );
  }

  /// Helper to implement Sober special rule: if a Dealer was sent home, cancel kills
  static bool _dealerCancelTriggered(Map<String, String> metadata) {
    return metadata['dealer_sent_home'] == 'true';
  }

  /// Choose dealer kill target deterministically by vote count and tie broken by lexical order
  static String? _chooseDealerKillTarget(List<NightAction> killActions) {
    if (killActions.isEmpty) return null;

    // Count votes for each target
    final Map<String, int> voteCount = {};
    for (final action in killActions) {
      if (action.targetPlayerId != null) {
        voteCount[action.targetPlayerId!] = (voteCount[action.targetPlayerId!] ?? 0) + 1;
      }
    }

    if (voteCount.isEmpty) return null;

    // Find max vote count
    final maxVotes = voteCount.values.reduce((a, b) => a > b ? a : b);

    // Get all targets with max votes
    final topTargets = voteCount.entries
        .where((e) => e.value == maxVotes)
        .map((e) => e.key)
        .toList();

    // Sort lexically for deterministic tie-breaking
    topTargets.sort();

    return topTargets.first;
  }
}
