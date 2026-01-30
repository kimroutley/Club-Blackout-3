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

/// Coarse-grained effect type for queued abilities.
///
/// This is primarily used for serialization/test introspection.
enum AbilityEffect {
  kill,
  protect,
  reveal,
  block,
  redirect,
  mark,
  other,
}

/// Represents a game ability with triggers and effects
class Ability {
  final String id;
  final String name;
  final String description;
  final AbilityTrigger trigger;
  final int priority; // Lower = earlier in night phase

  const Ability({
    required this.id,
    required this.name,
    required this.description,
    required this.trigger,
    this.priority = 0,
  });
}

/// Represents an ability instance that has been activated
class ActiveAbility {
  final String abilityId;
  final String sourcePlayerId;
  final List<String> targetPlayerIds;
  final AbilityTrigger? trigger;
  final AbilityEffect? effect;
  final int priority;
  final Map<String, dynamic> metadata;

  const ActiveAbility({
    required this.abilityId,
    required this.sourcePlayerId,
    this.targetPlayerIds = const [],
    this.trigger,
    this.effect,
    this.priority = 0,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'abilityId': abilityId,
        'sourcePlayerId': sourcePlayerId,
        'targetPlayerIds': targetPlayerIds,
        'trigger': trigger?.index,
        'effect': effect?.index,
        'priority': priority,
        'metadata': metadata,
      };

  factory ActiveAbility.fromJson(Map<String, dynamic> json) {
    return ActiveAbility(
      abilityId: json['abilityId'] as String,
      sourcePlayerId: json['sourcePlayerId'] as String,
      targetPlayerIds: (json['targetPlayerIds'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      trigger: (json['trigger'] is int)
          ? AbilityTrigger.values[(json['trigger'] as int)
              .clamp(0, AbilityTrigger.values.length - 1)]
          : null,
      effect: (json['effect'] is int)
          ? AbilityEffect.values[
              (json['effect'] as int).clamp(0, AbilityEffect.values.length - 1)]
          : null,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

/// Result of an ability resolution
class AbilityResult {
  final String abilityId;
  final bool success;
  final List<String> targets;
  final Map<String, dynamic> metadata;

  const AbilityResult({
    required this.abilityId,
    this.success = true,
    this.targets = const [],
    this.metadata = const {},
  });
}

/// Library of all abilities in the game
class AbilityLibrary {
  static final Map<String, List<Ability>> _roleAbilities = {
    'dealer': [
      const Ability(
          id: 'dealer_kill',
          name: 'Hit',
          description: 'Eliminate a guest.',
          trigger: AbilityTrigger.nightAction,
          priority: 50)
    ],
    'medic': [
      const Ability(
          id: 'medic_protect',
          name: 'Triage',
          description: 'Grant immunity tonight.',
          trigger: AbilityTrigger.nightAction,
          priority: 20)
    ],
    'bouncer': [
      const Ability(
          id: 'bouncer_id_check',
          name: 'ID Check',
          description: 'See faction.',
          trigger: AbilityTrigger.nightAction,
          priority: 30)
    ],
    'drama_queen': [
      const Ability(
          id: 'drama_queen_swap',
          name: 'Scene Stealer',
          description: 'Swap roles on death.',
          trigger: AbilityTrigger.onDeath,
          priority: 10)
    ],
    'tea_spiller': [
      const Ability(
          id: 'tea_spiller_reveal',
          name: 'Spill Tea',
          description: 'Expose role on death.',
          trigger: AbilityTrigger.onDeath,
          priority: 5)
    ],
  };

  /// Get abilities for a specific role
  static List<Ability> getAbilitiesForRole(String roleId) =>
      _roleAbilities[roleId] ?? [];
}

/// Manages ability resolution and interactions
class AbilityResolver {
  final List<ActiveAbility> _queue = [];

  /// Add an ability to the queue
  void queueAbility(ActiveAbility ability) => _queue.add(ability);

  /// Clear all queued abilities and effects
  void clear() => _queue.clear();

  // Persistence support
  Map<String, dynamic> toJson() => {
        'queue': _queue.map((a) => a.toJson()).toList(),
      };

  void loadFromJson(Map<String, dynamic> json) {
    _queue.clear();
    final q = json['queue'];
    if (q is List) {
      for (final entry in q) {
        if (entry is Map<String, dynamic>) {
          _queue.add(ActiveAbility.fromJson(entry));
        } else if (entry is Map) {
          _queue.add(ActiveAbility.fromJson(entry.cast<String, dynamic>()));
        }
      }
    }
  }

  /// Process all queued abilities in priority order
  List<AbilityResult> resolveAllAbilities(List<Player> players) {
    _queue.sort((a, b) => a.priority.compareTo(b.priority));
    final List<AbilityResult> results = [];
    final protectedIds = <String>{};
    final deadOnArrival = <String>{};

    for (final ability in _queue) {
      if (ability.abilityId == 'medic_protect' ||
          ability.abilityId == 'sober_send_home') {
        protectedIds.addAll(ability.targetPlayerIds);
        results.add(AbilityResult(
            abilityId: ability.abilityId, targets: ability.targetPlayerIds));
      } else if (ability.abilityId == 'dealer_kill') {
        final kills = <String>[];
        final saved = <String>[];
        for (final tid in ability.targetPlayerIds) {
          if (protectedIds.contains(tid)) {
            saved.add(tid);
          } else {
            kills.add(tid);
            deadOnArrival.add(tid);
          }
        }
        results.add(AbilityResult(
            abilityId: ability.abilityId,
            targets: kills,
            metadata: {'protected': saved}));
      }
    }
    return results;
  }
}
