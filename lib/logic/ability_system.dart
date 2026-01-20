import '../models/player.dart';

/// Defines when an ability can be triggered
enum AbilityTrigger {
  nightAction, // During night phase, player's turn
  dayAction, // During day phase
  onDeath, // When the player dies
  onOtherDeath, // When another player dies
  onVoted, // When player is voted for
  onVoteOther, // When player votes for someone
  onProtected, // When player is protected
  onAttacked, // When player is targeted for kill
  onReveal, // When player's role is revealed
  passive, // Always active (e.g., extra lives)
  startup, // At game start (e.g., Creep choice, Medic choice)
}

/// Defines the type of ability effect
enum AbilityEffect {
  kill, // Kill a player
  protect, // Protect from death
  block, // Block someone's ability
  silence, // Prevent speaking/voting
  reveal, // Reveal role information
  swap, // Swap roles or positions
  inherit, // Take another's role
  mark, // Mark for future effect
  redirect, // Change target of ability
  copy, // Copy an ability
  heal, // Remove status/restore life
  spread, // Spread effect (e.g., rumours)
  transform, // Change alliance or role permanently
  investigate, // Learn information
  modify, // Modify a property of a player (generic)
}

/// Represents a game ability with triggers and effects
class Ability {
  final String id;
  final String name;
  final String description;
  final AbilityTrigger trigger;
  final AbilityEffect effect;
  final int priority; // Lower = earlier in night phase
  final bool requiresTarget;
  final int maxTargets;
  final int minTargets;
  final bool isOneTime; // Can only be used once
  final bool isPassive; // Doesn't need player action
  final String? condition; // Optional condition for activation

  const Ability({
    required this.id,
    required this.name,
    required this.description,
    required this.trigger,
    required this.effect,
    this.priority = 5,
    this.requiresTarget = false,
    this.maxTargets = 1,
    this.minTargets = 0,
    this.isOneTime = false,
    this.isPassive = false,
    this.condition,
  });
}

/// Represents an ability instance that has been activated
class ActiveAbility {
  final String abilityId;
  final String sourcePlayerId;
  final List<String> targetPlayerIds;
  final AbilityTrigger trigger;
  final AbilityEffect effect;
  final int priority;
  final Map<String, dynamic> metadata;

  ActiveAbility({
    required this.abilityId,
    required this.sourcePlayerId,
    this.targetPlayerIds = const [],
    required this.trigger,
    required this.effect,
    required this.priority,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'abilityId': abilityId,
    'sourcePlayerId': sourcePlayerId,
    'targetPlayerIds': targetPlayerIds,
    'trigger': trigger.name,
    'effect': effect.name,
    'priority': priority,
    'metadata': metadata,
  };

  factory ActiveAbility.fromJson(Map<String, dynamic> json) => ActiveAbility(
    abilityId: json['abilityId'] as String,
    sourcePlayerId: json['sourcePlayerId'] as String,
    targetPlayerIds: (json['targetPlayerIds'] as List?)?.cast<String>() ?? [],
    trigger: AbilityTrigger.values.firstWhere(
      (e) => e.name == json['trigger'],
      orElse: () => AbilityTrigger.nightAction,
    ),
    effect: AbilityEffect.values.firstWhere(
      (e) => e.name == json['effect'],
      orElse: () => AbilityEffect.kill,
    ),
    priority: json['priority'] as int,
    metadata: json['metadata'] as Map<String, dynamic>? ?? {},
  );
}

/// Manages ability resolution and interactions
class AbilityResolver {
  final List<ActiveAbility> _abilityQueue = [];
  final Map<String, Set<String>> _protections = {}; // Protected players
  final Map<String, Set<String>> _blocks = {}; // Blocked players
  final Map<String, List<String>> _redirects = {}; // Redirected targets

  /// Callback for when an ability is queued (e.g. for logging)
  void Function(ActiveAbility)? onAbilityQueued;

  /// Add an ability to the queue
  void queueAbility(ActiveAbility ability) {
    _abilityQueue.add(ability);
    onAbilityQueued?.call(ability);
  }

  /// Serialize the queue for game saving
  Map<String, dynamic> toJson() => {
    'queue': _abilityQueue.map((a) => a.toJson()).toList(),
  };

  /// Load a saved queue
  void loadFromJson(Map<String, dynamic> json) {
    clear();
    if (json['queue'] != null) {
      final list = json['queue'] as List;
      _abilityQueue.addAll(list.map((e) => ActiveAbility.fromJson(e)));
    }
  }

  /// Clear all queued abilities and effects
  void clear() {
    _abilityQueue.clear();
    _protections.clear();
    _blocks.clear();
    _redirects.clear();
  }

  /// Remove a queued ability that matches the criteria
  void cancelAbility(
    String abilityId, {
    String? sourcePlayerId,
    String? targetPlayerId,
  }) {
    _abilityQueue.removeWhere((ability) {
      bool matchId = ability.abilityId == abilityId;
      bool matchSource =
          sourcePlayerId == null || ability.sourcePlayerId == sourcePlayerId;
      bool matchTarget =
          targetPlayerId == null ||
          ability.targetPlayerIds.contains(targetPlayerId);

      return matchId && matchSource && matchTarget;
    });
  }

  /// Process all queued abilities in priority order
  List<AbilityResult> resolveAllAbilities(List<Player> players) {
    List<AbilityResult> results = [];

    // Sort by priority (lower first)
    _abilityQueue.sort((a, b) => a.priority.compareTo(b.priority));

    for (var ability in _abilityQueue) {
      final result = _resolveAbility(ability, players);
      results.add(result);
    }

    return results;
  }

  AbilityResult _resolveAbility(ActiveAbility ability, List<Player> players) {
    // Check if source is blocked
    if (_isBlocked(ability.sourcePlayerId)) {
      return AbilityResult(
        abilityId: ability.abilityId,
        success: false,
        message: "Ability was blocked",
      );
    }

    // Apply redirects to targets
    final actualTargets = _getActualTargets(ability.targetPlayerIds);

    // Resolve based on effect type
    switch (ability.effect) {
      case AbilityEffect.protect:
        return _resolveProtect(ability, actualTargets, players);

      case AbilityEffect.kill:
        return _resolveKill(ability, actualTargets, players);

      case AbilityEffect.block:
        return _resolveBlock(ability, actualTargets);

      case AbilityEffect.redirect:
        return _resolveRedirect(ability, actualTargets);

      case AbilityEffect.silence:
        return _resolveSilence(ability, actualTargets, players);

      case AbilityEffect.mark:
        return _resolveMark(ability, actualTargets);

      case AbilityEffect.spread:
        return _resolveSpread(ability, actualTargets, players);

      case AbilityEffect.investigate:
        return _resolveInvestigate(ability, actualTargets, players);

      case AbilityEffect.reveal:
        return _resolveReveal(ability, actualTargets, players);

      default:
        return AbilityResult(
          abilityId: ability.abilityId,
          success: true,
          message: "Ability triggered: ${ability.abilityId}",
          targets: actualTargets,
        );
    }
  }

  bool _isBlocked(String playerId) {
    return _blocks.values.any((blocked) => blocked.contains(playerId));
  }

  List<String> _getActualTargets(List<String> originalTargets) {
    List<String> result = [];
    for (var target in originalTargets) {
      result.add(_redirects[target]?.first ?? target);
    }
    return result;
  }

  AbilityResult _resolveProtect(
    ActiveAbility ability,
    List<String> targets,
    List<Player> players,
  ) {
    for (var targetId in targets) {
      _protections.putIfAbsent(ability.sourcePlayerId, () => {}).add(targetId);

      // Special logic for Sober: If Dealer is sent home, block all murders
      if (ability.abilityId == 'sober_send_home') {
        final target = players.firstWhere(
          (p) => p.id == targetId,
          orElse: () => players.first,
        );
        if (target.id == targetId && target.role.id == 'dealer') {
          // Find all dealers and block them
          final dealers = players.where((p) => p.role.id == 'dealer');
          for (var dealer in dealers) {
            // Block the dealer.
            // _blocks maps Blocker ID -> Set of Blocked IDs.
            // So we add dealer.id to the set of players blocked by Sober (ability.sourcePlayerId).
            _blocks
                .putIfAbsent(ability.sourcePlayerId, () => {})
                .add(dealer.id);
          }
        }
      }
    }
    return AbilityResult(
      abilityId: ability.abilityId,
      success: true,
      message: "Protection applied",
      targets: targets,
    );
  }

  AbilityResult _resolveKill(
    ActiveAbility ability,
    List<String> targets,
    List<Player> players,
  ) {
    List<String> killed = [];
    List<String> protected = [];
    List<String> minorProtected = [];
    List<String> livesLost = []; // Players who lost a life but didn't die

    for (var targetId in targets) {
      // Check if protected
      bool isProtected = _protections.values.any(
        (set) => set.contains(targetId),
      );

      if (isProtected) {
        protected.add(targetId);
      } else {
        final player = players.firstWhere(
          (p) => p.id == targetId,
          orElse: () => players.first,
        );
        if (player.id == targetId) {
          if (!player.isActive) {
            continue;
          }
          // Check for Minor protection
          if (player.role.id == 'minor' && !player.minorHasBeenIDd) {
            minorProtected.add(targetId);
            // Minor survives.
          } else {
            // Predetermine outcome based on lives, but primarily report intent to GameEngine
            // GameEngine.processDeath will handle the actual state updates and "absorb" logic.
            // Assumption: Any player with > 1 life will absorb the hit unless Ability specifically ignores it.
            // Since we can't easily check 'isDealerAttempt' here, we assume standard behavior.
            if (player.lives > 1) {
              livesLost.add(targetId);
            } else {
              killed.add(targetId);
            }
          }
        }
      }
    }

    String message = "";
    if (killed.isNotEmpty) message += "${killed.length} killed";
    if (protected.isNotEmpty) {
      message += message.isEmpty
          ? '${protected.length} protected'
          : ', ${protected.length} protected';
    }
    if (minorProtected.isNotEmpty) {
      message += message.isEmpty
          ? '${minorProtected.length} Minor protected'
          : ', ${minorProtected.length} Minor protected';
    }
    if (livesLost.isNotEmpty) {
      message += message.isEmpty
          ? '${livesLost.length} lost a life'
          : ', ${livesLost.length} lost a life';
    }
    if (message.isEmpty) message = "No kills";

    return AbilityResult(
      abilityId: ability.abilityId,
      success: killed.isNotEmpty || livesLost.isNotEmpty,
      message: message,
      targets: killed,
      metadata: {
        'protected': protected,
        'minor_protected': minorProtected,
        'lives_lost': livesLost,
      },
    );
  }

  AbilityResult _resolveBlock(ActiveAbility ability, List<String> targets) {
    for (var target in targets) {
      _blocks.putIfAbsent(ability.sourcePlayerId, () => {}).add(target);
    }
    return AbilityResult(
      abilityId: ability.abilityId,
      success: true,
      message: "Block applied",
      targets: targets,
    );
  }

  AbilityResult _resolveRedirect(ActiveAbility ability, List<String> targets) {
    if (targets.isEmpty) {
      return AbilityResult(
        abilityId: ability.abilityId,
        success: false,
        message: "No redirect target",
      );
    }
    // Redirect metadata MUST contain 'from' player IDs to be meaningful
    // Or we assume the ability.targetPlayerIds contains [OldTarget, NewTarget]
    // But standard input is usually just NewTarget.
    // If the logic is "Redirect attacks on X to Y", we need to know X.
    // For now, let's assume the metadata contains 'redirectFrom' list,
    // OR we interpret targets as [To].
    // If we want to support "Whore redirects All Dealers to Target",
    // the GameEngine must provide the mapping.

    // Implementation: GameEngine passes 'redirectFrom' in metadata.
    final fromIds = List<String>.from(ability.metadata['redirectFrom'] ?? []);
    final toId = targets.first;

    for (var fromId in fromIds) {
      _redirects.putIfAbsent(fromId, () => []).add(toId);
    }

    return AbilityResult(
      abilityId: ability.abilityId,
      success: true,
      message: "Redirect applied",
      targets: targets,
      metadata: {'redirected_from': fromIds, 'redirected_to': toId},
    );
  }

  AbilityResult _resolveSilence(
    ActiveAbility ability,
    List<String> targets,
    List<Player> players,
  ) {
    for (var targetId in targets) {
      final player = players.firstWhere(
        (p) => p.id == targetId,
        orElse: () => players.first,
      );
      if (player.id == targetId) {
        if (!player.isActive) {
          continue;
        }
        player.applyStatus('silenced');
      }
    }
    return AbilityResult(
      abilityId: ability.abilityId,
      success: true,
      message: "Silence applied",
      targets: targets,
    );
  }

  AbilityResult _resolveMark(ActiveAbility ability, List<String> targets) {
    return AbilityResult(
      abilityId: ability.abilityId,
      success: true,
      message: "Mark applied",
      targets: targets,
      metadata: ability.metadata,
    );
  }

  AbilityResult _resolveSpread(
    ActiveAbility ability,
    List<String> targets,
    List<Player> players,
  ) {
    for (var targetId in targets) {
      final player = players.firstWhere(
        (p) => p.id == targetId,
        orElse: () => players.first,
      );
      if (player.id == targetId) {
        if (!player.isActive) {
          continue;
        }
        player.hasRumour = true;
      }
    }
    return AbilityResult(
      abilityId: ability.abilityId,
      success: true,
      message: "Rumour spread",
      targets: targets,
    );
  }

  AbilityResult _resolveInvestigate(
    ActiveAbility ability,
    List<String> targets,
    List<Player> players,
  ) {
    // For abilities like Club Manager viewing a role or Wallflower watching
    // We return the info in metadata
    final targetId = targets.firstOrNull;

    // Handle cases like Wallflower which may not require a specific target
    if (targetId == null) {
      if (ability.abilityId == 'wallflower_witness') {
        return AbilityResult(
          abilityId: ability.abilityId,
          success: true,
          message: "Witnessed murder",
          targets: [],
          // Wallflower logic is mostly handled in GameEngine logs, but consistent result helps.
        );
      }

      return AbilityResult(
        abilityId: ability.abilityId,
        success: false,
        message: "No target",
      );
    }

    final target = players.firstWhere(
      (p) => p.id == targetId,
      orElse: () => players.first,
    );
    if (target.id != targetId) {
      return AbilityResult(
        abilityId: ability.abilityId,
        success: false,
        message: "Target not found",
      );
    }

    return AbilityResult(
      abilityId: ability.abilityId,
      success: true,
      message: "Investigated ${target.name}",
      targets: targets,
      metadata: {
        'role': target.role.name,
        'roleId': target.role.id,
        'alliance': target.role.alliance,
      },
    );
  }

  AbilityResult _resolveReveal(
    ActiveAbility ability,
    List<String> targets,
    List<Player> players,
  ) {
    // For abilities like Silver Fox or Tea Spiller
    // The actual revealing logic (UI update) happens elsewhere based on this result
    return AbilityResult(
      abilityId: ability.abilityId,
      success: true,
      message: "Revealed targets",
      targets: targets,
    );
  }
}

/// Result of an ability resolution
class AbilityResult {
  final String abilityId;
  final bool success;
  final String message;
  final List<String> targets;
  final Map<String, dynamic> metadata;

  AbilityResult({
    required this.abilityId,
    required this.success,
    required this.message,
    this.targets = const [],
    this.metadata = const {},
  });
}

/// Library of all abilities in the game
class AbilityLibrary {
  static const dealerKill = Ability(
    id: 'dealer_kill',
    name: 'Eliminate Target',
    description: 'Choose a player to eliminate during the night',
    trigger: AbilityTrigger.nightAction,
    effect: AbilityEffect.kill,
    priority: 5,
    requiresTarget: true,
    maxTargets: 1,
    minTargets: 1,
  );

  static const medicProtect = Ability(
    id: 'medic_protect',
    name: 'Daily Protection',
    description: 'Protect one player each night from death',
    trigger: AbilityTrigger.nightAction,
    effect: AbilityEffect.protect,
    priority: 2,
    requiresTarget: true,
    maxTargets: 1,
    minTargets: 1,
  );

  static const medicRevive = Ability(
    id: 'medic_revive',
    name: 'Resuscitate Once',
    description: 'Bring one player back from the dead (one time use)',
    trigger: AbilityTrigger.dayAction,
    effect: AbilityEffect.heal,
    priority: 1,
    requiresTarget: true,
    maxTargets: 1,
    minTargets: 1,
    isOneTime: true,
  );

  static const bouncerProtect = Ability(
    id: 'bouncer_protect',
    name: 'ID Check',
    description: 'Protect one player each night and learn their alliance',
    trigger: AbilityTrigger.nightAction,
    effect: AbilityEffect.protect,
    priority: 2,
    requiresTarget: true,
    maxTargets: 1,
    minTargets: 1,
  );

  static const roofiSilence = Ability(
    id: 'roofi_silence',
    name: 'Dose Drink',
    description: 'Silence a player for the next day phase',
    trigger: AbilityTrigger.nightAction,
    effect: AbilityEffect.silence,
    priority: 4,
    requiresTarget: true,
    maxTargets: 1,
    minTargets: 1,
  );

  static const messyBitchSpread = Ability(
    id: 'messy_bitch_spread',
    name: 'Spread Rumour',
    description: 'Spread a rumour to one player each night',
    trigger: AbilityTrigger.nightAction,
    effect: AbilityEffect.spread,
    priority: 6,
    requiresTarget: true,
    maxTargets: 1,
    minTargets: 1,
  );

  static const creepMimic = Ability(
    id: 'creep_mimic',
    name: 'Choose Target',
    description: 'Select a player to mimic at game start',
    trigger: AbilityTrigger.startup,
    effect: AbilityEffect.inherit,
    priority: 1,
    requiresTarget: true,
    maxTargets: 1,
    minTargets: 1,
    isOneTime: true,
  );

  static const dramaQueenSwap = Ability(
    id: 'drama_queen_swap',
    name: 'Final Curtain',
    description: 'When you die, swap the roles of two players',
    trigger: AbilityTrigger.onDeath,
    effect: AbilityEffect.swap,
    priority: 1,
    requiresTarget: true,
    maxTargets: 2,
    minTargets: 2,
  );

  static const teaSpillerReveal = Ability(
    id: 'tea_spiller_reveal',
    name: 'Spill the Tea',
    description: 'When you die, reveal one player\'s role to everyone',
    trigger: AbilityTrigger.onDeath,
    effect: AbilityEffect.reveal,
    priority: 2,
    requiresTarget: true,
    maxTargets: 1,
    minTargets: 1,
  );

  static const predatorRetaliate = Ability(
    id: 'predator_retaliate',
    name: 'Retribution',
    description: 'If voted out during the day, take one player with you',
    trigger: AbilityTrigger.onVoted,
    effect: AbilityEffect.kill,
    priority: 1,
    requiresTarget: true,
    maxTargets: 1,
    minTargets: 1,
  );

  static const seasonedDrinkerPassive = Ability(
    id: 'seasoned_drinker_lives',
    name: 'Extra Life',
    description: 'Can survive one attack',
    trigger: AbilityTrigger.passive,
    effect: AbilityEffect.protect,
    priority: 0,
    isPassive: true,
  );

  static const allyCatPassive = Ability(
    id: 'ally_cat_lives',
    name: 'Nine Lives',
    description: 'Can survive up to 8 attacks',
    trigger: AbilityTrigger.passive,
    effect: AbilityEffect.protect,
    priority: 0,
    isPassive: true,
  );

  static const wallflowerWitness = Ability(
    id: 'wallflower_witness',
    name: 'Witness Murder',
    description:
        'Can discreetly open eyes during the night to watch the murder',
    trigger: AbilityTrigger.nightAction,
    effect: AbilityEffect.investigate,
    priority: 5,
    requiresTarget:
        false, // It's an observation, but in code might not need a target selection if it's "watch everyone"
    isPassive: true, // Manual action
  );

  static const clubManagerView = Ability(
    id: 'club_manager_view',
    name: 'Sight Card',
    description: 'Look at a fellow player\'s card without others seeing',
    trigger: AbilityTrigger.nightAction,
    effect: AbilityEffect.investigate,
    priority: 3,
    requiresTarget: true,
    maxTargets: 1,
    minTargets: 1,
  );

  static const silverFoxReveal = Ability(
    id: 'silver_fox_reveal',
    name: 'Expose Secrets',
    description: 'Force a player to hold up their role card for 5 seconds',
    trigger: AbilityTrigger.nightAction,
    effect: AbilityEffect.reveal,
    priority: 1,
    requiresTarget: true,
    maxTargets: 1,
    minTargets: 1,
    isOneTime: true,
  );

  static const soberSendHome = Ability(
    id: 'sober_send_home',
    name: 'Drive Home',
    description:
        'Send a player home. If Dealer is sent home, NO murders occur.',
    trigger: AbilityTrigger.nightAction,
    effect: AbilityEffect
        .protect, // Handled specially in resolver logic for Dealers
    priority: 1,
    requiresTarget: true,
    maxTargets: 1,
    minTargets: 1,
    isOneTime: true,
  );

  static const whoreDeflect = Ability(
    id: 'whore_deflect',
    name: 'Deflection',
    description: 'Deflect a vote from a Dealer to another player',
    trigger: AbilityTrigger.dayAction,
    effect: AbilityEffect.redirect,
    priority: 0,
    requiresTarget: true,
    maxTargets: 1,
    minTargets: 1,
  );

  /// Get abilities for a specific role
  static List<Ability> getAbilitiesForRole(String roleId) {
    switch (roleId) {
      case 'dealer':
        return [dealerKill];
      case 'medic':
        return [medicProtect, medicRevive];
      case 'bouncer':
        return [bouncerProtect];
      case 'roofi':
        return [roofiSilence];
      case 'messy_bitch':
        return [messyBitchSpread];
      case 'creep':
        return [creepMimic];
      case 'drama_queen':
        return [dramaQueenSwap];
      case 'tea_spiller':
        return [teaSpillerReveal];
      case 'predator':
        return [predatorRetaliate];
      case 'seasoned_drinker':
        return [seasonedDrinkerPassive];
      case 'ally_cat':
        return [allyCatPassive];
      case 'wallflower':
        return [wallflowerWitness];
      case 'club_manager':
        return [clubManagerView];
      case 'silver_fox':
        return [silverFoxReveal];
      case 'sober':
        return [soberSendHome];
      case 'whore':
        return [whoreDeflect];
      default:
        return [];
    }
  }

  /// Get all night action abilities
  static List<Ability> getNightActionAbilities() {
    return [
      dealerKill,
      medicProtect,
      bouncerProtect,
      roofiSilence,
      messyBitchSpread,
      clubManagerView,
      silverFoxReveal,
      soberSendHome,
    ];
  }

  /// Get all reactive abilities (triggered by events)
  static List<Ability> getReactiveAbilities() {
    return [dramaQueenSwap, teaSpillerReveal, predatorRetaliate];
  }
}
