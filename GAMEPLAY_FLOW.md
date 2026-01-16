# Club Blackout - Gameplay Flow Reference

## Game Setup

1. **Player Addition** (`addPlayer`)
   - Assign random or specific roles
   - Initialize player stats (lives, alliance, etc.)
   - Track name history

2. **Game Start** (`startGame`)
   - Assign roles if not manually set
   - Trigger game start event
   - Build intro + night 0 script
   - Initialize ability systems

## Night Phase Flow

### 1. Night Begins
```
Event: nightPhaseStart
- Status effects update
- Night script builds based on alive roles with nightPriority > 0
```

### 2. Players Wake in Priority Order
```
Priority 1: Creep (Night 0 only) - chooses mimic target
Priority 2: Medic/Bouncer - protects one player
Priority 4: Roofi - silences one player
Priority 5: Dealers - choose kill target
Priority 6: Messy Bitch - spreads rumour
Priority 7+: Other special roles
```

### 3. Abilities Queue
- Each action calls `handleScriptAction`
- Abilities added to `abilityResolver`
- Targets stored in `nightActions` map

### 4. Night Resolution (`_resolveNightPhase`)

**Order of Operations:**
```dart
1. Process all queued abilities by priority
   ├─ Protections applied first (priority 2)
   ├─ Status effects applied (priority 4)
   └─ Kills processed last (priority 5)

2. Check kill vs protection
   ├─ If protected: "saved" announcement
   └─ If not: player dies

3. For each death:
   ├─ Trigger death event
   ├─ Check for death reactions
   │  ├─ Drama Queen: swap marked players
   │  └─ Tea Spiller: reveal marked player
   ├─ Process Creep inheritance
   └─ Update dead player list

4. Generate morning announcement
5. Clear night actions
6. Build day script
```

## Day Phase Flow

### 1. Morning Announcement
```
- Deaths from night reported
- Special events announced
- Discussion begins
```

### 2. Discussion & Voting
```
- Silenced players cannot speak (Roofi effect)
- Players discuss and accuse
- Vote taken (external to engine)
```

### 3. Vote Resolution (`voteOutPlayer`)

**Order of Operations:**
```dart
1. Trigger vote event
   └─ Check for vote reactions

2. If Predator voted out:
   ├─ Get marked retaliation target
   ├─ Kill retaliation target
   └─ Log revenge

3. Trigger death event for voted player
   └─ Process death reactions

4. Kill voted player
5. Check game end condition
```

### 4. Phase Transition
```
- Update to night phase
- Build next night script
- Continue loop
```

## Ability Resolution Examples

### Example 1: Protected Kill
```
Night Actions:
  Medic protects Player A
  Dealers target Player A

Resolution (priority order):
  [2] Medic protection → Player A is protected
  [5] Dealer kill → Blocked by protection
  
Result: "Someone was attacked but saved!"
```

### Example 2: Death Chain
```
Dealer kills Drama Queen (who marked A & B)

Resolution:
  [5] Dealer kill → Drama Queen dies
  [Event] Death triggers
  [1] Drama Queen reaction → A and B swap roles
  
Result: Drama Queen dies, A becomes B's role, B becomes A's role
```

### Example 3: Predator Revenge
```
Day Vote: Predator voted out (marked Player C)

Resolution:
  [Event] Vote event triggers
  [1] Predator retaliation → Player C dies
  [Event] Predator death event
  
Result: Both Predator and Player C die
```

### Example 4: Messy Bitch Victory
```
Night Actions:
  Messy Bitch spreads rumour to last player

Resolution:
  [6] Rumour spread → Last player gets rumour
  [Check] All alive players have rumours
  [Win] Messy Bitch victory announced
```

## Special Mechanics

### Creep Inheritance
```
Setup (Night 0):
  Creep chooses mimic target
  Creep alliance = target alliance

When target dies:
  Creep role = target role
  Creep fully inherits abilities
  Creep keeps new role rest of game
```

### Multi-Life Players
```
Seasoned Drinker: 2 lives
Ally Cat: 9 lives

When attacked:
  lives -= 1
  If lives > 0: survives
  If lives <= 0: dies
```

### Status Effects
```
Silenced (Roofi):
  Duration: 1 day phase
  Effect: Cannot speak or vote
  Applied: Night phase
  Active: Next day phase
```

## Win Conditions

### Checked After Each Day Vote

**Dealer Victory:**
```
Dealers alive >= Party Animals alive
"The Dealers have taken over the club!"
```

**Party Animal Victory:**
```
All Dealers dead && Party Animals alive
"The Party Animals saved the club!"
```

**Messy Bitch Solo Victory:**
```
All alive players have rumours (checked each night)
"[Name] won by spreading all the rumours!"
Note: Can win alongside either team
```

**Draw:**
```
All players dead
"Everyone died! No one wins."
```

## Key Methods Reference

### Game Control
- `startGame()` - Initialize game
- `advanceScript()` - Next script step
- `regressScript()` - Undo script step

### Player Management
- `addPlayer(name, role)` - Add player
- `removePlayer(id)` - Remove player
- `updatePlayerRole(id, role)` - Change role
- `voteOutPlayer(id)` - Day vote elimination

### Phase Management
- `_loadNextPhaseScript()` - Transition phases
- `_resolveNightPhase()` - Process night abilities
- `checkGameEnd()` - Check win conditions

### Ability System
- `handleScriptAction(step, targets)` - Queue ability
- `abilityResolver.resolveAllAbilities()` - Execute abilities
- `reactionSystem.triggerEvent()` - Trigger reactions

### Logging
- `logAction(title, description)` - Add to game log
- `checkMessyBitchWin()` - Check MB victory

### Persistence
- `saveGame()` - Save state
- `loadGame()` - Restore state
- `resetGame()` - Clear all

## Debugging Tips

### Check Ability Queue
```dart
print(abilityResolver._abilityQueue.length); // How many queued
print(abilityResolver._protections);         // Active protections
```

### Check Events
```dart
print(reactionSystem.getEventHistory());     // All events
print(reactionSystem.getPendingReactions()); // Pending reactions
```

### Check Player State
```dart
print(player.lives);           // Remaining lives
print(player.isAlive);         // Life status
print(player.statusEffects);   // Active effects
print(player.alliance);        // Current team
```

### Check Game State
```dart
print(currentPhase);           // Current phase
print(nightActions);           // Night selections
print(deadPlayerIds);          // Who's dead
print(dayCount);               // Current day
```
