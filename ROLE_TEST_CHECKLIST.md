# ROLE TEST CHECKLIST - Club Blackout Android Game

**Purpose:** Prioritized test checklist for Club Blackout roles, based on implementation audit and current gaps.

**Status Legend:**
- ✅ Fully Implemented & Testable
- ⚠️ Partially Implemented (has gaps)
- ❌ Not Implemented
- 🧪 Test Exists
- 📋 Test Needed

---

## HIGH PRIORITY - CRITICAL GAPS (Test When Implemented)

### ❌ THE LIGHTWEIGHT
**Status:** Not Implemented  
**Test Priority:** HIGH  
**Suggested Tests:**
- [ ] 📋 Taboo name is assigned after each night
- [ ] 📋 Speaking a taboo name causes instant death
- [ ] 📋 Multiple taboo names accumulate over nights
- [ ] 📋 Other players can speak taboo names without dying
- [ ] 📋 Lightweight survives when avoiding all taboo names

### ❌ THE WHORE (Vote Deflection)
**Status:** Critical Gap - Ability Missing  
**Test Priority:** HIGH  
**Suggested Tests:**
- [ ] 🧪 Whore deflection saves a Dealer from being voted out (exists in whore_test.dart)
- [ ] 🧪 Whore deflection saves the Whore from being voted out (exists in whore_test.dart)
- [ ] 📋 Whore cannot deflect if not targeting a Dealer/self
- [ ] 📋 Deflection target dies instead of original target
- [ ] 📋 Deflection logs appear in game log

---

## MEDIUM PRIORITY - MAJOR GAPS

### ⚠️ THE CLINGER (Vote Sync & Attack Dog)
**Status:** Partially Implemented  
**Test Priority:** MEDIUM  
**Suggested Tests:**
- [ ] 📋 Clinger must vote exactly as obsession partner does
- [ ] 📋 Clinger dies when obsession partner dies
- [ ] 📋 "Controller" keyword spoken by obsession frees Clinger
- [ ] 📋 Freed Clinger gains Attack Dog ability
- [ ] 📋 Attack Dog kill ability works once and only once
- [ ] 📋 Clinger cannot use Attack Dog if never freed

### ⚠️ THE SECOND WIND (Dealer Conversion)
**Status:** Partially Implemented  
**Test Priority:** MEDIUM  
**Suggested Tests:**
- [ ] 📋 Second Wind triggers conversion option when killed
- [ ] 📋 Dealers can accept conversion (Second Wind revives as Dealer)
- [ ] 📋 Dealers can reject conversion (Second Wind stays dead)
- [ ] 📋 No other deaths occur on night of successful conversion
- [ ] 📋 Converted Second Wind has Dealer abilities and alliance
- [ ] 📋 Rejection allows normal murder to proceed

### ⚠️ THE BOUNCER (Roofi Power Steal)
**Status:** ID Check Works, Power Steal Missing  
**Test Priority:** MEDIUM  
**Suggested Tests:**
- [ ] 📋 Bouncer can challenge Roofi
- [ ] 📋 Correct challenge: Bouncer gains Roofi's silence ability, Roofi loses it
- [ ] 📋 Incorrect challenge: Bouncer loses ID check ability forever
- [ ] 📋 Bouncer retains both abilities if challenge succeeds
- [ ] 📋 Challenge can only happen once

### ⚠️ THE ALLY CAT (Meow Communication)
**Status:** Nine Lives Works, Meow Missing  
**Test Priority:** MEDIUM  
**Suggested Tests:**
- [ ] 📋 Ally Cat wakes when Bouncer checks IDs
- [ ] 📋 Ally Cat can only communicate via "Meow"
- [ ] 📋 Non-meow communication is blocked/flagged
- [ ] 📋 Ally Cat survives 9 kill attempts (nine lives)
- [ ] 📋 Ally Cat dies on 10th kill

---

## LOW PRIORITY - MINOR GAPS

### 🟡 THE CREEP (Inheritance Verification)
**Status:** Likely Works, Needs Testing  
**Test Priority:** LOW  
**Suggested Tests:**
- [ ] 📋 Creep selects target on Night 0
- [ ] 📋 Creep views target's role card
- [ ] 📋 Creep alliance matches target alliance
- [ ] 📋 When target dies, Creep inherits exact role
- [ ] 📋 Creep abilities change to inherited role's abilities
- [ ] 📋 Inheritance persists for rest of game

### 🟡 THE DRAMA QUEEN (Swap Timing/Visibility)
**Status:** Likely Works, Needs Clarification  
**Test Priority:** LOW  
**Suggested Tests:**
- [ ] 📋 Drama Queen triggered when voted out and dies
- [ ] 📋 Drama Queen selects two players to swap
- [ ] 📋 Swapped players receive each other's role cards
- [ ] 📋 Drama Queen can view swapped roles
- [ ] 📋 Swap persists for remainder of game
- [ ] 📋 Swap announcement timing is correct

---

## FULLY IMPLEMENTED ROLES - REGRESSION TESTS

### ✅ THE DEALER
**Test Priority:** HIGH (Core Role)  
**Suggested Tests:**
- [ ] 📋 Dealers wake together at night
- [ ] 📋 Dealers agree on kill target (consensus/majority)
- [ ] 📋 Kill is executed at end of night
- [ ] 📋 Wallflower can witness murder
- [ ] 📋 Multiple dealers targeting different players (tie-breaker logic)

### ✅ THE MEDIC
**Test Priority:** HIGH (Core Protection)  
**Suggested Tests:**
- [ ] 📋 Medic chooses PROTECT or REVIVE on Night 0
- [ ] 📋 PROTECT mode: protects chosen player each night
- [ ] 📋 REVIVE mode: can resurrect one dead player once per game
- [ ] 📋 Protected player survives Dealer kill
- [ ] 📋 Revive token is consumed after use
- [ ] 📋 Cannot change mode after Night 0

### ✅ THE BOUNCER (ID Check)
**Test Priority:** MEDIUM  
**Suggested Tests:**
- [ ] 📋 Bouncer selects player to ID check
- [ ] 📋 Host nods if Dealer, shakes if not
- [ ] 📋 Minor loses protection after being IDd by Bouncer
- [ ] 📋 Ally Cat can witness ID checks

### ✅ THE SOBER
**Test Priority:** MEDIUM  
**Suggested Tests:**
- [ ] 📋 Sober can send one player home (once per game)
- [ ] 📋 Sent-home player is protected from death that night
- [ ] 📋 If Dealer is sent home, no murders occur that night
- [ ] 📋 Ability is consumed after use
- [ ] 📋 Cannot use ability twice

### ✅ THE MINOR
**Test Priority:** MEDIUM  
**Suggested Tests:**
- [ ] 📋 Minor cannot die on first kill attempt
- [ ] 📋 First kill marks Minor as IDd
- [ ] 📋 Second kill succeeds
- [ ] 📋 Bouncer ID check also marks Minor as IDd

### ✅ THE SEASONED DRINKER
**Test Priority:** LOW  
**Suggested Tests:**
- [ ] 📋 Lives equal to number of Dealers
- [ ] 📋 Survives multiple kill attempts
- [ ] 📋 Dies when lives reach zero

### ✅ THE ROOFI
**Test Priority:** MEDIUM  
**Suggested Tests:**
- [ ] 📋 Roofi silences one player each night
- [ ] 📋 Silenced player cannot speak during day phase
- [ ] 📋 Silenced Dealer is also paralyzed next night
- [ ] 📋 Status effect persists for full day

### ✅ THE WALLFLOWER
**Test Priority:** LOW  
**Suggested Tests:**
- [ ] 📋 Wallflower can choose to witness murders
- [ ] 📋 Sees who Dealers target
- [ ] 📋 Can provide hints without explicit reveal

### ✅ THE MESSY BITCH
**Test Priority:** MEDIUM  
**Suggested Tests:**
- [ ] 📋 Spreads rumour to one player each night
- [ ] 📋 Win condition: all living players (except self) have rumour
- [ ] 📋 Special kill ability after win condition met
- [ ] 📋 Neutral survivor (doesn't affect Dealer/PA parity)

### ✅ THE CLUB MANAGER
**Test Priority:** LOW  
**Suggested Tests:**
- [ ] 📋 Views one player's role each night
- [ ] 📋 Information is shown to Club Manager only
- [ ] 📋 Can switch allegiances based on info

### ✅ THE SILVER FOX
**Test Priority:** LOW  
**Suggested Tests:**
- [ ] 📋 Once per game, force player to reveal role
- [ ] 📋 Entire club sees reveal
- [ ] 📋 Ability consumed after use

### ✅ THE PREDATOR
**Test Priority:** MEDIUM  
**Suggested Tests:**
- [ ] 📋 When voted out, selects one voter to kill
- [ ] 📋 Retaliation kill happens immediately
- [ ] 📋 Can only target players who voted for Predator

### ✅ THE TEA SPILLER
**Test Priority:** LOW  
**Suggested Tests:**
- [ ] 📋 When dies, reveals one player's role
- [ ] 📋 Reveal is Dealer or Not Dealer
- [ ] 📋 Information shared with all players

---

## INTEGRATION TESTS

### Night Resolution System
**Test Priority:** CRITICAL  
**Suggested Tests:**
- [x] 🧪 Medic protection prevents Dealer kill (test/night_resolver_test.dart)
- [x] 🧪 Dealer consensus selection (test/night_resolver_test.dart)
- [x] 🧪 Lexicographic tie-breaker (test/night_resolver_test.dart)
- [x] 🧪 Sober cancels dealer kills (test/night_resolver_test.dart)
- [x] 🧪 Minor protection logic (test/night_resolver_test.dart)
- [ ] 📋 Multiple protections on same target
- [ ] 📋 Priority order: Sober → Roofi → Medic → Bouncer → Dealers
- [ ] 📋 Status effects applied correctly

### Victory Conditions
**Test Priority:** CRITICAL  
**Suggested Tests:**
- [x] 🧪 Dealers win at parity (test/night_resolver_victory_test.dart)
- [x] 🧪 Party Animals win when all Dealers dead (test/night_resolver_victory_test.dart)
- [x] 🧪 Whore counts toward Dealer parity (test/night_resolver_victory_test.dart)
- [ ] 📋 Messy Bitch neutral win doesn't trigger parity
- [ ] 📋 Dead players excluded from parity calculation
- [ ] 📋 Victory announced at correct time

### Schema Validation
**Test Priority:** HIGH  
**Suggested Tests:**
- [x] 🧪 roles.json exists (test/roles_schema_test.dart)
- [x] 🧪 Valid JSON structure (test/roles_schema_test.dart)
- [x] 🧪 All roles have id, name, nightPriority (test/roles_schema_test.dart)
- [x] 🧪 Role IDs are unique (test/roles_schema_test.dart)
- [x] 🧪 Night priority values in valid range (test/roles_schema_test.dart)

---

## NOTES FOR TEST IMPLEMENTATION

1. **Use Existing Test Infrastructure:** Follow patterns from `test/whore_test.dart` and existing gameplay tests
2. **Minimal Role Construction:** Tests can use minimal Role objects or load from RoleRepository
3. **Focus on Determinism:** NightResolver provides deterministic resolution for easier testing
4. **GameEngine Integration:** Tests should verify GameEngine properly uses NightResolver and reaction systems
5. **Edge Cases:** Always test tie scenarios, empty lists, and boundary conditions
6. **Parity Math:** Carefully verify dealer vs non-dealer counting in victory tests

---

## TEST COVERAGE GOALS

- **Current Coverage:** ~60% (estimated based on audit)
- **Target Coverage:** 85%+
- **Critical Paths:** 100% (Dealer kills, Medic protection, victory conditions)
- **Edge Cases:** 70%+ (tie-breakers, multi-ability interactions)

---

**Last Updated:** January 16, 2026  
**Based on:** ROLE_IMPLEMENTATION_AUDIT.md comprehensive assessment
