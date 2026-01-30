# Role Test Checklist

This document provides a prioritized list of roles that need test coverage and sample test cases for each. The priorities are based on the ROLE_IMPLEMENTATION_AUDIT.md and CODE_QUALITY_IMPROVEMENTS.md analyses.

## Priority Legend
- 🔴 **CRITICAL**: Core mechanic missing or broken; role unplayable
- 🟠 **HIGH**: Major abilities missing; role partially functional
- 🟡 **MEDIUM**: Minor gaps or needs verification
- 🟢 **LOW**: Fully implemented; needs test coverage only

---

## 🔴 CRITICAL PRIORITY ROLES

### 1. THE WHORE - Vote Deflection Mechanic
**Status:** CRITICAL GAP - Core ability missing  
**Missing:** Vote deflection script, ability resolver, game engine logic

**Required Tests:**
```dart
test('Whore deflects vote from Dealer to chosen target', () {
  // Setup: Whore selects deflection target during night
  // Action: Dealer gets voted out during day
  // Expected: Vote redirects to deflection target; Dealer survives
});

test('Whore deflects vote from self to chosen target', () {
  // Setup: Whore selects deflection target during night
  // Action: Whore gets voted out during day
  // Expected: Vote redirects to deflection target; Whore survives
});

test('Whore deflection fails if target is already dead', () {
  // Setup: Whore selects deflection target who dies before day vote
  // Action: Vote happens on Dealer or Whore
  // Expected: Deflection fails; original target is voted out
});
```

---

### 2. THE LIGHTWEIGHT - Taboo Name Mechanic
**Status:** CRITICAL GAP - Entire role non-functional  
**Missing:** Taboo name assignment, validation, death trigger

**Required Tests:**
```dart
test('Lightweight receives taboo name each night', () {
  // Setup: Lightweight alive
  // Action: Night phase ends
  // Expected: Host assigns new taboo name; stored in player.tabooNames
});

test('Lightweight dies when speaking taboo name', () {
  // Setup: Lightweight has taboo name 'Alice'
  // Action: Lightweight says 'Alice' during day phase
  // Expected: Lightweight dies immediately
});

test('Taboo names accumulate over multiple nights', () {
  // Setup: Lightweight survives 3 nights
  // Action: Check tabooNames list
  // Expected: Contains 3 unique taboo names
});
```

---

### 3. THE SECOND WIND - Conversion Mechanic
**Status:** MAJOR GAP - Unique conversion mechanic unimplemented  
**Missing:** Dealer decision script, conversion logic, resurrection

**Required Tests:**
```dart
test('Second Wind triggers conversion vote when killed', () {
  // Setup: Dealers kill Second Wind
  // Action: Night resolution
  // Expected: Dealers presented with conversion choice
});

test('Second Wind converts to Dealer when accepted', () {
  // Setup: Second Wind killed, Dealers vote YES
  // Action: Apply conversion
  // Expected: Second Wind revives as Dealer; no other deaths that night
});

test('Second Wind dies when Dealers reject conversion', () {
  // Setup: Second Wind killed, Dealers vote NO
  // Action: Apply rejection
  // Expected: Second Wind stays dead; normal night resolution continues
});
```

---

## 🟠 HIGH PRIORITY ROLES

### 4. THE CLINGER - Vote Sync & Liberation
**Status:** MAJOR GAP - Multiple abilities missing  
**Missing:** Vote forcing, 'controller' trigger, Attack Dog ability

**Required Tests:**
```dart
test('Clinger votes exactly as obsession partner votes', () {
  // Setup: Clinger obsessed with Partner
  // Action: Partner votes for Player A; Clinger attempts to vote for Player B
  // Expected: Clinger's vote forced to Player A (same as Partner)
});

test('Clinger freed when called "controller" by obsession', () {
  // Setup: Clinger obsessed with Partner
  // Action: Partner says "controller" during day phase
  // Expected: Clinger freed; gains Attack Dog ability
});

test('Freed Clinger can kill one player as Attack Dog', () {
  // Setup: Clinger freed as Attack Dog
  // Action: Night phase; Clinger selects target
  // Expected: Target dies; Clinger ability is consumed (one-time use)
});

test('Clinger dies when obsession partner dies (before liberation)', () {
  // Setup: Clinger obsessed with Partner; not yet freed
  // Action: Partner dies
  // Expected: Clinger dies of heartbreak simultaneously
});
```

---

### 5. THE BOUNCER - Roofi Challenge Mechanic
**Status:** PARTIAL - ID check works; Roofi challenge missing  
**Missing:** Roofi power-stealing logic

**Required Tests:**
```dart
test('Bouncer successfully steals Roofi ability on correct challenge', () {
  // Setup: Bouncer challenges Roofi; Roofi is actual Roofi
  // Action: Challenge resolves
  // Expected: Bouncer gains Roofi's silence ability; Roofi loses it
});

test('Bouncer loses ID check ability on incorrect Roofi challenge', () {
  // Setup: Bouncer challenges non-Roofi player as Roofi
  // Action: Challenge resolves
  // Expected: Bouncer loses ID check ability permanently
});

test('Bouncer retains ID check when not challenging Roofi', () {
  // Setup: Bouncer checks IDs normally
  // Action: Multiple nights of ID checks
  // Expected: Bouncer continues checking IDs with no penalty
});
```

**Suggested Test Cases**:
- [ ] Clinger dies when obsession partner dies
- [ ] Clinger must vote exactly as partner votes (vote sync)
- [ ] Clinger is freed when called "controller" by obsession
- [ ] Freed Clinger can use Attack Dog ability to kill one player
- [ ] Attack Dog ability is one-time use only
- [ ] Clinger cannot use Attack Dog before being freed

## 🟡 MEDIUM PRIORITY ROLES

### 6. THE ALLY CAT - Meow Communication
**Status:** MINOR GAP - Nine Lives works; meow mechanic missing  
**Missing:** Meow-only communication validation

**Required Tests:**
```dart
test('Ally Cat wakes with Bouncer during ID check', () {
  // Setup: Bouncer checks ID; Ally Cat is alive
  // Action: Night phase ID check step
  // Expected: Ally Cat opens eyes; observes Bouncer's check
});

test('Ally Cat can only communicate via meow during night', () {
  // Setup: Ally Cat awake during Bouncer check
  // Action: Ally Cat attempts to speak (not meow)
  // Expected: Invalid communication (enforcement may be manual/UI-based)
});

test('Ally Cat loses a life when attacked', () {
  // Setup: Ally Cat with 9 lives
  // Action: Dealers kill Ally Cat
  // Expected: Ally Cat loses 1 life; survives (8 lives remaining)
});
```

**Suggested Test Cases**:
- [ ] Ally Cat starts with 9 lives
- [ ] Ally Cat survives 9 kill attempts
- [ ] Ally Cat dies on 10th kill attempt
- [ ] Ally Cat wakes with Bouncer during ID checks
- [ ] Ally Cat can only communicate via "meow" during certain phases
- [ ] Non-meow communication from Ally Cat is blocked/invalid

### 7. THE CREEP - Role Inheritance
**Status:** MINOR GAP - Likely works; needs verification  
**Missing:** Test coverage

**Required Tests:**
```dart
test('Creep chooses mimic target on Night 0', () {
  // Setup: Creep selects target
  // Action: Night 0 resolution
  // Expected: Creep alliance matches target alliance
});

test('Creep inherits role when mimic target dies', () {
  // Setup: Creep mimicking Party Animal
  // Action: Party Animal dies
  // Expected: Creep becomes Party Animal (role + alliance)
});

test('Creep can inherit Dealer role', () {
  // Setup: Creep mimicking Dealer
  // Action: Dealer dies
  // Expected: Creep becomes Dealer; joins Dealer team
});
```

---

### 8. THE DRAMA QUEEN - Role Swap Timing
**Status:** MINOR GAP - Swap mechanic unclear  
**Missing:** Documentation of swap timing

**Required Tests:**
```dart
test('Drama Queen swaps two roles when voted out', () {
  // Setup: Drama Queen selects Player A and Player B during night
  // Action: Drama Queen voted out and dies
  // Expected: Player A gets Player B's role; Player B gets Player A's role
});

test('Drama Queen swap persists for rest of game', () {
  // Setup: Drama Queen swaps Medic and Dealer
  // Action: Game continues multiple nights
  // Expected: Swapped roles remain permanent
});
```

---

## 🟢 LOW PRIORITY ROLES (Need Test Coverage)

### Fully Implemented Roles Needing Tests:

**9. THE DEALER** - Kill mechanic
**10. THE MEDIC** - Protect vs. Revive choice
**11. THE SOBER** - Send home + block kills
**12. THE ROOFI** - Silence player
**13. THE BOUNCER** - ID check
**14. THE MINOR** - ID immunity
**15. THE SEASONED DRINKER** - Multiple lives
**16. THE WALLFLOWER** - Witness murder
**17. THE CLUB MANAGER** - View role
**18. THE SILVER FOX** - Force reveal
**19. THE PREDATOR** - Retaliation kill
**20. THE TEA SPILLER** - Death reveal
**21. THE MESSY BITCH** - Rumor spreading

---

## Sample Test Template

Use this template for creating new role tests:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';
import 'package:club_blackout/logic/night_resolver.dart';

void main() {
  group('RoleName Tests', () {
    test('Role ability description', () {
      // Arrange: Create roles and players
      final role = Role(
        id: 'role_id',
        name: 'Role Name',
        alliance: 'Alliance',
        type: 'type',
        description: 'Description',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#FFFFFF',
      );

      final player = Player(
        id: 'player1',
        name: 'Player Name',
        role: role,
        isAlive: true,
        isEnabled: true,
      );

      // Act: Perform action

      // Assert: Verify expected outcome
      expect(player.isAlive, isTrue);
    });
  });
}
```

---

## Testing Guidelines

1. **Use Existing Models**: Create Player and Role objects using their constructors
2. **Keep Tests Isolated**: No UI dependencies; pure business logic
3. **Test Edge Cases**: Death, revival, multiple lives, immunity
4. **Verify State Changes**: Check player flags, lives, alliance changes
5. **Test Priority Order**: Verify night phase resolution order (Sober → Roofi → Medic → Bouncer → Dealers)

---

## Next Steps

1. Implement missing role mechanics (Whore, Lightweight, Second Wind, Clinger)
2. Add test coverage for critical priority roles first
3. Verify existing implementations with medium priority tests
4. Add comprehensive test suite for all fully implemented roles
5. Run all tests in CI pipeline to catch regressions

---

## Role Test Checklist (Engine-Focused)

### Night action plumbing (must be true for every role)
- [ ] Selecting a target updates both `nightActions[step.id]` and engine canonical keys via `handleScriptAction()`.
- [ ] Morning report reflects the resolved outcome (killed/saved/silenced).

### Second Wind
- [ ] If killed by Dealers: sets `secondWindPendingConversion=true` and does NOT die immediately.
- [ ] If conversion accepted: becomes Dealer, alive, pending flag cleared.
- [ ] If conversion refused: dies; pending cleared; refused flag set.

### Medic
- [ ] Setup choice persists (`PROTECT_DAILY` vs `REVIVE`).
- [ ] Protect prevents Dealer kill.
- [ ] Revive removes from `deadPlayerIds` and restores `isAlive=true`.

### Bouncer / Minor
- [ ] `bouncer_act` sets `idCheckedByBouncer=true`.
- [ ] If target is Minor: `minorHasBeenIDd=true` (immunity toggled off).

### Roofi
- [ ] `roofi_act` sets `silencedDay = day+1`.
- [ ] If target is Dealer: `blockedKillNight = day+1`.

---

## Role Test Checklist (Smoke)

- [ ] `flutter analyze` passes
- [ ] Start game from Lobby -> GameScreen shows script steps
- [ ] Night: Dealer kill recorded to `nightActions['kill']`
- [ ] Night: Medic protect recorded to `nightActions['protect']` when in PROTECT mode
- [ ] Bouncer check updates `idCheckedByBouncer` and `minorHasBeenIDd` for Minor
- [ ] Deaths update `deadPlayerIds` consistently
- [ ] Save/Load restores players + log + phase
