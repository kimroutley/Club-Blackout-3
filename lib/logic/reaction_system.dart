import '../models/player.dart';
import 'ability_system.dart';

/// Types of game events that can trigger reactions
enum GameEventType {
  playerDied,
  playerVoted,
  playerEliminated,
  nightPhaseStart,
  dayPhaseStart,
  roleRevealed,
  playerProtected,
  playerAttacked,
  abilityUsed,
  gameStart,
  turnEnd,
}

/// Represents a game event that occurred
class GameEvent {
  final GameEventType type;
  final String? sourcePlayerId;
  final String? targetPlayerId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  GameEvent({
    required this.type,
    this.sourcePlayerId,
    this.targetPlayerId,
    this.data = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'type': type.index,
        'sourcePlayerId': sourcePlayerId,
        'targetPlayerId': targetPlayerId,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'];
    final typeIdx =
        rawType is int ? rawType : (rawType is num ? rawType.toInt() : 0);
    final safeIdx = typeIdx.clamp(0, GameEventType.values.length - 1);

    final rawData = json['data'];
    final data = rawData is Map
        ? rawData.cast<String, dynamic>()
        : const <String, dynamic>{};

    DateTime ts;
    final rawTs = json['timestamp'];
    try {
      ts = rawTs is String ? DateTime.parse(rawTs) : DateTime.now();
    } catch (_) {
      ts = DateTime.now();
    }

    return GameEvent(
      type: GameEventType.values[safeIdx],
      sourcePlayerId: json['sourcePlayerId'] as String?,
      targetPlayerId: json['targetPlayerId'] as String?,
      data: data,
      timestamp: ts,
    );
  }
}

/// Manages event-based reactions and ability triggers
class ReactionSystem {
  final List<PendingReaction> _pendingReactions = [];
  final List<GameEvent> _eventHistory = [];

  // Persistence support
  List<Map<String, dynamic>> getHistoryJson() {
    return _eventHistory.map((e) => e.toJson()).toList();
  }

  void loadHistoryFromJson(List<dynamic> jsonList) {
    _eventHistory.clear();
    for (final item in jsonList) {
      if (item is! Map) continue;
      try {
        _eventHistory.add(GameEvent.fromJson(item.cast<String, dynamic>()));
      } catch (_) {
        // Skip invalid history entries to avoid breaking saved games.
      }
    }
  }

  ReactionSystem copy() {
    final copy = ReactionSystem();
    copy._eventHistory.addAll(_eventHistory);
    // _pendingReactions is unused/ephemeral, so ignoring it matches persistence behavior.
    return copy;
  }

  void copyFrom(ReactionSystem other) {
    _eventHistory.clear();
    _eventHistory.addAll(other._eventHistory);
  }

  /// Register a reaction to be processed
  void registerReaction(PendingReaction reaction) {
    _pendingReactions.add(reaction);
  }

  /// Trigger an event and collect all reactions
  List<PendingReaction> triggerEvent(GameEvent event, List<Player> players) {
    _eventHistory.add(event);

    final List<PendingReaction> reactions = [];

    // Check each alive player for reactions to this event
    for (var player in players.where((p) => p.isActive)) {
      final playerReactions = _checkPlayerReactions(player, event, players);
      reactions.addAll(playerReactions);
    }

    return reactions;
  }

  List<PendingReaction> _checkPlayerReactions(
    Player player,
    GameEvent event,
    List<Player> players,
  ) {
    final List<PendingReaction> reactions = [];
    final abilities = AbilityLibrary.getAbilitiesForRole(player.role.id);

    for (var ability in abilities) {
      if (_shouldTriggerAbility(ability, event, player)) {
        reactions.add(
          PendingReaction(
            ability: ability,
            sourcePlayer: player,
            triggeringEvent: event,
          ),
        );
      }
    }

    return reactions;
  }

  bool _shouldTriggerAbility(Ability ability, GameEvent event, Player player) {
    // Check if the ability trigger matches the event type
    switch (ability.trigger) {
      case AbilityTrigger.onDeath:
        return event.type == GameEventType.playerDied &&
            event.sourcePlayerId == player.id;

      case AbilityTrigger.onOtherDeath:
        return event.type == GameEventType.playerDied &&
            event.sourcePlayerId != player.id;

      case AbilityTrigger.onVoted:
        return event.type == GameEventType.playerVoted &&
            event.targetPlayerId == player.id;

      case AbilityTrigger.onVoteOther:
        return event.type == GameEventType.playerVoted &&
            event.sourcePlayerId == player.id;

      case AbilityTrigger.onProtected:
        return event.type == GameEventType.playerProtected &&
            event.targetPlayerId == player.id;

      case AbilityTrigger.onAttacked:
        return event.type == GameEventType.playerAttacked &&
            event.targetPlayerId == player.id;

      case AbilityTrigger.onReveal:
        return event.type == GameEventType.roleRevealed &&
            event.targetPlayerId == player.id;

      case AbilityTrigger.nightAction:
        return event.type == GameEventType.nightPhaseStart;

      case AbilityTrigger.dayAction:
        return event.type == GameEventType.dayPhaseStart;

      case AbilityTrigger.startup:
        return event.type == GameEventType.gameStart;

      case AbilityTrigger.passive:
        return false; // Passive abilities don't trigger from events
    }
  }

  /// Get all pending reactions
  List<PendingReaction> getPendingReactions() {
    return List.unmodifiable(_pendingReactions);
  }

  /// Clear a specific reaction
  void clearReaction(PendingReaction reaction) {
    _pendingReactions.remove(reaction);
  }

  /// Clear all pending reactions
  void clearAllReactions() {
    _pendingReactions.clear();
  }

  /// Get event history
  List<GameEvent> getEventHistory() {
    return List.unmodifiable(_eventHistory);
  }

  /// Clear event history
  void clearHistory() {
    _eventHistory.clear();
  }
}

/// Represents a reaction waiting to be resolved
class PendingReaction {
  final Ability ability;
  final Player sourcePlayer;
  final GameEvent triggeringEvent;
  List<String> targetPlayerIds;
  bool isResolved;

  PendingReaction({
    required this.ability,
    required this.sourcePlayer,
    required this.triggeringEvent,
    this.targetPlayerIds = const [],
    this.isResolved = false,
  });

  PendingReaction copy() {
    return PendingReaction(
      ability: ability,
      sourcePlayer: sourcePlayer,
      triggeringEvent: triggeringEvent,
      targetPlayerIds: List<String>.from(targetPlayerIds),
      isResolved: isResolved,
    );
  }
}

/// Manages complex ability interactions and chains
class AbilityChainResolver {
  final List<AbilityChainLink> _chain = [];

  /// Add an ability to the resolution chain
  void addToChain(ActiveAbility ability, {int insertAtPriority = -1}) {
    final link = AbilityChainLink(
      ability: ability,
      priority: insertAtPriority >= 0 ? insertAtPriority : ability.priority,
    );
    _chain.add(link);
    _chain.sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// Resolve the entire chain in priority order
  List<AbilityResult> resolveChain(
    List<Player> players,
    AbilityResolver resolver,
  ) {
    List<AbilityResult> results = [];

    for (var link in _chain) {
      if (!link.isCancelled) {
        resolver.queueAbility(link.ability);
      }
    }

    results = resolver.resolveAllAbilities(players);
    _chain.clear();

    return results;
  }

  /// Cancel a specific ability in the chain
  void cancelAbility(String abilityId) {
    for (var link in _chain) {
      if (link.ability.abilityId == abilityId) {
        link.isCancelled = true;
      }
    }
  }

  /// Get the current chain
  List<AbilityChainLink> getChain() {
    return List.unmodifiable(_chain);
  }

  /// Clear the chain
  void clear() {
    _chain.clear();
  }
}

/// Represents a link in the ability resolution chain
class AbilityChainLink {
  final ActiveAbility ability;
  final int priority;
  bool isCancelled;

  AbilityChainLink({
    required this.ability,
    required this.priority,
    this.isCancelled = false,
  });
}

/// Tracks status effects and their durations
class StatusEffectManager {
  final Map<String, List<StatusEffect>> _playerEffects = {};

  // Persistence support
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    _playerEffects.forEach((playerId, effects) {
      data[playerId] = effects.map((e) => e.toJson()).toList();
    });
    return data;
  }

  void loadFromJson(Map<String, dynamic> json) {
    _playerEffects.clear();
    json.forEach((playerId, effectsJson) {
      if (effectsJson is List) {
        final effects =
            effectsJson.map((e) => StatusEffect.fromJson(e)).toList();
        _playerEffects[playerId] = effects;
      }
    });
  }

  StatusEffectManager copy() {
    final copy = StatusEffectManager();
    _playerEffects.forEach((playerId, effects) {
      copy._playerEffects[playerId] = effects.map((e) => e.copy()).toList();
    });
    return copy;
  }

  void copyFrom(StatusEffectManager other) {
    _playerEffects.clear();
    other._playerEffects.forEach((playerId, effects) {
      _playerEffects[playerId] = effects.map((e) => e.copy()).toList();
    });
  }

  /// Apply a status effect to a player
  void applyEffect(String playerId, StatusEffect effect) {
    _playerEffects.putIfAbsent(playerId, () => []).add(effect);
  }

  /// Remove a specific effect
  void removeEffect(String playerId, String effectId) {
    _playerEffects[playerId]?.removeWhere((e) => e.id == effectId);
  }

  /// Get all effects for a player
  List<StatusEffect> getEffects(String playerId) {
    return _playerEffects[playerId] ?? [];
  }

  /// Check if player has a specific effect
  bool hasEffect(String playerId, String effectId) {
    return _playerEffects[playerId]?.any((e) => e.id == effectId) ?? false;
  }

  /// Update all effects (decrement duration, remove expired)
  void updateEffects() {
    for (var effects in _playerEffects.values) {
      for (var effect in effects) {
        if (effect.duration > 0) {
          effect.duration--;
        }
      }
      effects.removeWhere((e) => e.duration <= 0 && !e.isPermanent);
    }
  }

  /// Clear all effects for a player
  void clearPlayerEffects(String playerId) {
    _playerEffects.remove(playerId);
  }

  /// Clear all effects
  void clearAll() {
    _playerEffects.clear();
  }
}

/// Represents a status effect on a player
class StatusEffect {
  final String id;
  final String name;
  final String description;
  int duration; // Turns remaining, -1 for permanent
  final bool isPermanent;
  final Map<String, dynamic> data;

  StatusEffect({
    required this.id,
    required this.name,
    required this.description,
    this.duration = 1,
    this.isPermanent = false,
    this.data = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'duration': duration,
        'isPermanent': isPermanent,
        'data': data,
      };

  StatusEffect copy() {
    return StatusEffect(
      id: id,
      name: name,
      description: description,
      duration: duration,
      isPermanent: isPermanent,
      data: Map<String, dynamic>.from(data),
    );
  }

  factory StatusEffect.fromJson(Map<String, dynamic> json) => StatusEffect(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        duration: json['duration'] as int,
        isPermanent: json['isPermanent'] as bool,
        data: json['data'] as Map<String, dynamic>? ?? {},
      );
}

/// Common status effects
class CommonStatusEffects {
  static StatusEffect createSilenced({int duration = 1}) {
    return StatusEffect(
      id: 'silenced',
      name: 'Silenced',
      description: 'Cannot speak or vote',
      duration: duration,
    );
  }

  static StatusEffect createProtected({int duration = 1}) {
    return StatusEffect(
      id: 'protected',
      name: 'Protected',
      description: 'Protected from death this night',
      duration: duration,
    );
  }

  static StatusEffect createMarked({
    required String markerRole,
    Map<String, dynamic>? data,
  }) {
    return StatusEffect(
      id: 'marked_$markerRole',
      name: 'Marked',
      description: 'Marked by $markerRole',
      duration: -1,
      isPermanent: true,
      data: data ?? {},
    );
  }

  static StatusEffect createPoisoned({int duration = 1}) {
    return StatusEffect(
      id: 'poisoned',
      name: 'Poisoned',
      description: 'Will die at end of phase',
      duration: duration,
    );
  }

  static StatusEffect createBlocked({int duration = 1}) {
    return StatusEffect(
      id: 'blocked',
      name: 'Blocked',
      description: 'Ability is blocked',
      duration: duration,
    );
  }
}
