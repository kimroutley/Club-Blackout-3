# Club Blackout - Ability & Reaction System Documentation

## Overview

The game now features a robust ability and reaction system that handles:
- **Night abilities** (dealer kills, medic protects, etc.)
- **Reactive abilities** (triggered by events like deaths or votes)
- **Status effects** (silence, protection, marking)
- **Ability interactions** (protection vs kills, blocks, redirects)
- **Event-driven gameplay** (reactions to deaths, votes, attacks)

## Core Systems

### 1. Ability System (`ability_system.dart`)

#### Components:

**Ability Class**
- Defines a game ability with triggers, effects, and priority
- Properties:
  - `trigger`: When the ability activates (night, death, vote, etc.)
  - `effect`: What the ability does (kill, protect, silence, etc.)
  - `priority`: Order of resolution (lower = earlier)
  - `requiresTarget`: Whether a target is needed
  - `isOneTime`: Can only be used once
  - `isPassive`: Doesn't require player action

**ActiveAbility Class**
- Represents an ability instance that has been queued for execution
- Tracks source player, targets, and metadata

**AbilityResolver Class**
- Processes all queued abilities in priority order
- Handles interactions (protection blocks kills, etc.)
- Returns results for each ability resolution

**AbilityLibrary Class**
- Central repository of all game abilities
- Maps roles to their abilities
- Categorizes abilities by trigger type

#### Ability Triggers:
```dart
- nightAction      // During night phase
- dayAction        // During day phase
- onDeath          // When player dies
- onOtherDeath     // When another dies
- onVoted          // When voted for
- onAttacked       // When targeted for kill
- onProtected      // When protected
- passive          // Always active
- startup          // At game start
```

#### Ability Effects:
```dart
- kill             // Kill a player
- protect          // Protect from death
- block            // Block ability use
- silence          // Prevent speaking/voting
- reveal           // Reveal information
- swap             // Swap roles
- inherit          // Take another's role
- mark             // Mark for future effect
- spread           // Spread effect (rumours)
- heal             // Remove status/restore life
```

### 2. Reaction System (`reaction_system.dart`)

#### Components:

**GameEvent Class**
- Represents something that happened in the game
- Event types: playerDied, playerVoted, nightPhaseStart, etc.

**ReactionSystem Class**
- Manages event-based reactions
- Triggers abilities based on events
- Tracks pending reactions

**PendingReaction Class**
- Represents a reaction waiting to be resolved
- Links ability to triggering event
- Stores targets once selected

**AbilityChainResolver Class**
- Manages complex ability chains
- Allows cancellation and priority modification
- Resolves entire chains in order

**StatusEffectManager Class**
- Tracks status effects on players
- Manages duration and expiration
- Provides effect queries

**StatusEffect Class**
- Represents a temporary or permanent effect
- Examples: silenced, protected, marked, poisoned

### 3. Game Engine Integration

The GameEngine now includes:
```dart
// New properties
final AbilityResolver abilityResolver;
final ReactionSystem reactionSystem;
final StatusEffectManager statusEffectManager;
final AbilityChainResolver chainResolver;

// New methods
void voteOutPlayer(String playerId)      // Handle day votes with reactions
GameEndResult? checkGameEnd()            // Check win conditions
String _resolveNightPhase()              // Process all night abilities
void _processDeathReactions()            // Handle death-triggered abilities
void _handleDramaQueenSwap()             // Drama Queen ability
void _handleTeaSpillerReveal()           // Tea Spiller ability
void _handleCreepInheritance()           // Creep inheritance
```

## Role Abilities Implemented

### Night Action Abilities

**Dealer** - `dealer_kill`
- Priority: 5
- Effect: Kill one player
- Trigger: nightAction
- Can be blocked by Medic/Bouncer protection

**Medic** - `medic_protect`
- Priority: 2 (before kills)
- Effect: Protect one player from death
- Trigger: nightAction
- Also has `medic_revive` (one-time day action)

**Bouncer** - `bouncer_protect`
- Priority: 2
- Effect: Protect and learn alliance
- Trigger: nightAction
- Reveals target's alliance to Bouncer

**Roofi** - `roofi_silence`
- Priority: 4
- Effect: Silence target for next day
- Trigger: nightAction
- Target cannot speak or vote

**Messy Bitch** - `messy_bitch_spread`
- Priority: 6
- Effect: Spread rumour to one player
- Trigger: nightAction
- Wins if all alive players have rumours

**Creep** - `creep_mimic`
- Priority: 1
- Effect: Choose player to inherit from
- Trigger: startup (one-time at game start)
- Inherits role when chosen target dies

### Reactive Abilities (Death-Triggered)

**Drama Queen** - `drama_queen_swap`
- Trigger: onDeath (when Drama Queen dies)
- Effect: Swap two marked players' roles
- Targets selected during night phase

**Tea Spiller** - `tea_spiller_reveal`
- Trigger: onDeath
- Effect: Reveal one player's role to everyone
- Target selected during night phase

**Predator** - `predator_retaliate`
- Trigger: onVoted (when voted out)
- Effect: Kill one marked player
- Target selected during night phase

### Passive Abilities

**Seasoned Drinker** - `seasoned_drinker_lives`
- Effect: Survives one attack (2 lives)
- Passive: Always active

**Ally Cat** - `ally_cat_lives`
- Effect: Survives up to 8 attacks (9 lives)
- Passive: Always active

## Usage Examples

### Example 1: Night Resolution

```dart
// Player actions are queued during the night phase
void handleScriptAction(ScriptStep step, List<String> selectedPlayerIds) {
  switch (roleId) {
    case 'dealer':
      abilityResolver.queueAbility(ActiveAbility(
        abilityId: 'dealer_kill',
        sourcePlayerId: dealerPlayer.id,
        targetPlayerIds: [target.id],
        trigger: AbilityTrigger.nightAction,
        effect: AbilityEffect.kill,
        priority: 5,
      ));
      break;
      
    case 'medic':
      abilityResolver.queueAbility(ActiveAbility(
        abilityId: 'medic_protect',
        sourcePlayerId: medicPlayer.id,
        targetPlayerIds: [target.id],
        trigger: AbilityTrigger.nightAction,
        effect: AbilityEffect.protect,
        priority: 2,  // Resolves before kills
      ));
      break;
  }
}

// At end of night, abilities are resolved in priority order
String _resolveNightPhase() {
  final results = abilityResolver.resolveAllAbilities(players);
  
  // Results show what happened:
  // - If Medic protected the Dealer's target: no death
  // - If not protected: player dies
  // - Death triggers reactions (Drama Queen, Tea Spiller, etc.)
}
```

### Example 2: Death Reactions

```dart
// When a player dies, trigger death event
final deathEvent = GameEvent(
  type: GameEventType.playerDied,
  sourcePlayerId: victim.id,
  data: {'cause': 'night_kill'},
);

// System checks all players for reactions
final reactions = reactionSystem.triggerEvent(deathEvent, players);

// If Drama Queen died and marked two players:
_processDeathReactions(victim, reactions);
// -> The two marked players swap roles

// If Tea Spiller died and marked a player:
// -> That player's role is revealed to everyone
```

### Example 3: Vote with Retaliation

```dart
void voteOutPlayer(String playerId) {
  final player = players.firstWhere((p) => p.id == playerId);
  
  // If Predator is voted out and marked someone:
  if (player.role.id == 'predator') {
    final target = nightActions['predator_mark'];
    if (target != null) {
      // Predator takes marked player with them
      killPlayer(target);
      logAction("Predator's Revenge", "...");
    }
  }
  
  // Kill the voted player
  player.die();
}
```

## Ability Priority Order

Lower priority = resolves first:

1. **Priority 1**: Creep selection, Drama Queen swap, Predator retaliation
2. **Priority 2**: Medic/Bouncer protection
3. **Priority 4**: Roofi silence
4. **Priority 5**: Dealer kill
5. **Priority 6**: Messy Bitch rumour spread

This ensures:
- Protection is applied before kills
- Status effects are applied before they're needed
- Death reactions trigger at the right time

## Adding New Abilities

To add a new ability:

1. **Define the ability** in `AbilityLibrary`:
```dart
static const newAbility = Ability(
  id: 'role_ability_name',
  name: 'Display Name',
  description: 'What it does',
  trigger: AbilityTrigger.nightAction,  // When it triggers
  effect: AbilityEffect.kill,            // What it does
  priority: 5,                           // When it resolves
  requiresTarget: true,
  maxTargets: 1,
);
```

2. **Map it to the role** in `getAbilitiesForRole`:
```dart
case 'new_role':
  return [newAbility];
```

3. **Handle it in game engine** `handleScriptAction`:
```dart
case 'new_role':
  abilityResolver.queueAbility(ActiveAbility(
    abilityId: 'role_ability_name',
    sourcePlayerId: player.id,
    targetPlayerIds: [target.id],
    trigger: AbilityTrigger.nightAction,
    effect: AbilityEffect.kill,
    priority: 5,
  ));
  break;
```

4. **Add resolution logic** if needed in `AbilityResolver`.

## Testing the System

The system is designed to be testable:

```dart
// Test ability resolution
final resolver = AbilityResolver();
resolver.queueAbility(killAbility);
resolver.queueAbility(protectAbility);
final results = resolver.resolveAllAbilities(players);
// Verify: protection blocks kill

// Test reactions
final reactionSystem = ReactionSystem();
final deathEvent = GameEvent(type: GameEventType.playerDied, ...);
final reactions = reactionSystem.triggerEvent(deathEvent, players);
// Verify: Drama Queen reaction triggered

// Test status effects
final statusManager = StatusEffectManager();
statusManager.applyEffect(playerId, CommonStatusEffects.createSilenced());
final hasSilence = statusManager.hasEffect(playerId, 'silenced');
// Verify: status applied correctly
```

## Future Enhancements

Potential additions:
- **Ability blocking**: Roles that can block other abilities
- **Ability redirection**: Change target of abilities
- **Ability copying**: Copy another player's ability
- **Delayed abilities**: Trigger after N turns
- **Conditional abilities**: Only work under certain conditions
- **Combo abilities**: Chain multiple effects
- **Investigation abilities**: Learn information about players
- **Alliance-changing abilities**: Switch teams dynamically

## Performance Considerations

- Abilities are processed in batches (all night abilities together)
- Event system only triggers for alive players
- Status effects are cleaned up automatically
- No circular dependencies in ability chains
