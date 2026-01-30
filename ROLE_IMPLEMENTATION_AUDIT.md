# ROLE IMPLEMENTATION AUDIT - Club Blackout Android Game

**Date:** January 13, 2026  
**Status:** COMPREHENSIVE ASSESSMENT COMPLETE

---

## EXECUTIVE SUMMARY

A deep-dive analysis of role definitions vs. script implementation vs. game engine resolution reveals **9 critical/major gaps affecting gameplay**. Of the 22 unique roles:

- **13 roles** are fully or substantially implemented ✅
- **9 roles** have significant missing mechanics ⚠️

**Impact:** Several core role mechanics are defined in roles.json but non-functional in gameplay.

---

## ROLE-BY-ROLE IMPLEMENTATION STATUS

### ✅ FULLY IMPLEMENTED ROLES (13)

#### 1. **THE DEALER** - ✅ FULLY IMPLEMENTED
- **Role Definition:** Kill one Party Animal each night via consensus
- **Script Implementation:** `_buildDealerSteps()` - explicit handler
  - dealer_wake, dealer_act (selectPlayer), dealer_sleep
  - Integrated with Whore and Wallflower wake calls
- **Ability Resolution:** YES - `dealerKill` (priority 5, effect: kill)
- **Night Flow:** Dealers wake first (priority 5), agree on target, kill resolved
- **Status:** ✅ Fully functional

---

#### 2. **THE PARTY ANIMAL** - ✅ FULLY IMPLEMENTED
- **Role Definition:** No abilities; survive and vote out Dealers
- **Script Implementation:** NONE (no night actions, nightPriority = 0)
- **Ability Resolution:** NONE (correct - passive role)
- **Status:** ✅ Correctly implemented as passive role

---

#### 3. **THE MEDIC** - ✅ FULLY IMPLEMENTED
- **Role Definition:** Choose PROTECT (daily shield) OR REVIVE (once per game)
- **Script Implementation:** `_buildMedicSteps()` - explicit handler + Night 0 setup
  - medic_setup_choice (toggleOption on Night 0)
  - medic_mode (toggleOption during standard nights)
  - medic_target (selectPlayer with different rules for PROTECT vs REVIVE)
- **Ability Resolution:** YES
  - `medicProtect` (priority 2, effect: protect)
  - `medicRevive` (priority 1, effect: heal)
- **Night Flow:** Medic wakes at priority 2, chooses mode, selects target
- **Status:** ✅ Fully functional with binary choice persistence

---

#### 4. **THE BOUNCER - ID CHECK** - ⚠️ PARTIALLY IMPLEMENTED
- **Role Definition:** 
  - Check I.D.: Investigate players to identify Dealers (nod if Dealer, shake if not)
  - Roofi Powers: Can challenge Roofi to steal their ability
- **Script Implementation:** `_buildBouncerSteps()` - explicit handler + Night 0 setup
  - bouncer_setup_acknowledge (confirms rules about Minor vulnerability)
  - bouncer_act (selectPlayer for ID check)
- **Ability Resolution:** PARTIAL
  - ID checking logic: YES - handled in game_engine.dart `handleScriptAction()`
  - Roofi power-stealing: NO - **MISSING IMPLEMENTATION**
- **Night Flow:** Bouncer wakes at priority 2, selects player to ID, receives feedback
- **Gap:** Bouncer cannot take Roofi's ability. No mechanism exists.
- **Status:** ⚠️ ID check works; Roofi challenge mechanic is unimplemented

---

#### 5. **THE MINOR** - ✅ FULLY IMPLEMENTED
- **Role Definition:** Cannot die unless Bouncer has I.D.'d her (checked identity)
- **Script Implementation:** NONE (passive mechanic)
- **Ability Resolution:** YES - special logic in `_resolveKill()` 
  - If Dealer targets Minor who hasn't been I.D.'d: kill fails, Minor marked as I.D.'d
  - If Dealer targets Minor after I.D.: kill succeeds
- **Game Engine:** `minorHasBeenIDd` flag properly tracked
- **Status:** ✅ Fully functional passive mechanic

---

#### 6. **THE SEASONED DRINKER** - ✅ FULLY IMPLEMENTED
- **Role Definition:** Extra lives equal to number of Dealers; survives multiple kills
- **Script Implementation:** NONE (passive ability)
- **Ability Resolution:** YES - lives automatically set via `setLivesBasedOnDealers()`
- **Game Engine:** Kill logic respects `player.lives` counter
- **Status:** ✅ Fully functional - tested in 27-test suite

---

#### 7. **THE SOBER** - ✅ FULLY IMPLEMENTED
- **Role Definition:** Once per game, send one player home → protected from death; if Dealer sent home, no murders occur
- **Script Implementation:** `_buildRoleSteps()` special case
  - sober_act (selectPlayer)
  - Flag: `soberAbilityUsed` prevents reuse
- **Ability Resolution:** YES - `soberSendHome` (priority 1, effect: protect)
- **Special Rule:** If Dealer target, no kills happen that night (handled in game_engine.dart)
- **Status:** ✅ Fully functional including special "no murders" rule

---

#### 8. **THE WALLFLOWER** - ✅ FULLY IMPLEMENTED
- **Role Definition:** Optionally witness Dealer's murder during night to provide hints without getting caught
- **Script Implementation:** `_buildRoleSteps()` special case + integrated with Dealer wake
  - wallflower_act (optional choice to witness)
  - Wakes with Dealers (priority 5) to see the murder happen
- **Ability Resolution:** YES - information-only; no resolver needed
- **Night Flow:** Dealer target + Murder call → Wallflower may open eyes to see → provides hints next day
- **Status:** ✅ Fully functional

---

#### 9. **THE ROOFI** - ✅ FULLY IMPLEMENTED
- **Role Definition:** Paralyze one player each night; cannot speak/act that round
- **Script Implementation:** `_buildRoleSteps()` special case
  - roofi_act (selectPlayer)
- **Ability Resolution:** YES - `roofiSilence` (priority 4, effect: silence)
- **Game Engine:** Silenced players have status effect applied; voting/speaking blocked
- **Status:** ✅ Fully functional

---

#### 10. **THE CLUB MANAGER** - ✅ FULLY IMPLEMENTED
- **Role Definition:** View one player's role card each night; help whichever side ensures own survival
- **Script Implementation:** `_buildRoleSteps()` special case
  - club_manager_act (selectPlayer to view)
- **Ability Resolution:** YES - information-only ability (no resolver needed)
- **Night Flow:** Club Manager views target's card each night
- **Status:** ✅ Fully functional as informational role

---

#### 11. **THE SILVER FOX** - ✅ FULLY IMPLEMENTED
- **Role Definition:** Once per game, force a player to reveal role at night; entire club sees
- **Script Implementation:** `_buildRoleSteps()` special case
  - silver_fox_act (selectPlayer)
  - Flag: `silverFoxAbilityUsed` prevents reuse
- **Ability Resolution:** YES - `silverFoxReveal` (priority 1, effect: reveal)
- **Game Engine:** Reveal happens during morning announcement
- **Status:** ✅ Fully functional one-time ability

---

#### 12. **THE PREDATOR** - ✅ FULLY IMPLEMENTED
- **Role Definition:** If voted out during day, choose one voter to die with them (retaliation)
- **Script Implementation:** Handled in game_engine.dart `voteOutPlayer()` method
- **Ability Resolution:** YES - `predatorRetaliate` (trigger: onVoted, effect: kill)
- **Game Engine:** When Predator voted out, selects one voter to take down
- **Status:** ✅ Fully functional day-phase mechanic

---

#### 13. **THE TEA SPILLER** - ✅ FULLY IMPLEMENTED
- **Role Definition:** When dies, expose one player's role as either Dealer or Not
- **Script Implementation:** NONE (no night actions)
- **Ability Resolution:** YES - `teaSpillerReveal` (trigger: onDeath, effect: reveal)
- **Game Engine:** Death event triggers reveal ability
- **Status:** ✅ Fully functional death-trigger mechanic

---

### ⚠️ ROLES WITH CRITICAL/MAJOR GAPS (9)

#### 1. **THE HOST** - ❌ NOT IMPLEMENTED
- **Role Definition:** Game Master; facilitate, refresh memory, set themes
- **Current State:** EXCLUDED FROM GAME
  - roleRepository filters: `r.id != 'host'`
  - No script generation
  - No ability resolution
- **Gap:** Entire role is non-functional; exists in roles.json but cannot be selected
- **Severity:** 🔴 CRITICAL (Role cannot be played at all)

---

#### 2. **THE WHORE** - ❌ CRITICAL GAP
- **Role Definition:** Defend Dealers; redirect votes away from Dealers/self to another player
- **Current State:** PARTIAL
  - Wakes with Dealers in `_buildDealerSteps()`
  - No dedicated action step for vote deflection
  - No script for choosing deflection target
- **Missing:**
  - No script step for vote deflection ability
  - No ability in resolver for `whoreDeflect`
  - No game engine logic to apply vote redirects
- **Impact:** Whore has no way to use her primary ability during night
- **Severity:** 🔴 CRITICAL (Core ability missing)

---

#### 3. **THE CLINGER** - ⚠️ MAJOR GAP
- **Role Definition:**
  1. Must vote exactly as obsession partner does
  2. If partner dies, Clinger dies too
  3. If called "controller" by obsession, freed from obsession and gains ability to kill one player
- **Current State:** PARTIAL
  - Night 0 setup: selects obsession partner ✅
  - Death sync: `_handleClingerObsessionDeath()` triggers Clinger death if partner dies ✅
  - Vote sync: NOT FOUND ❌
  - Attack Dog liberation: NOT FOUND ❌
- **Missing:**
  - No vote sync mechanic (Clinger must vote as partner votes)
  - No "controller" trigger detection
  - No Attack Dog kill ability after liberation
- **Impact:** Clinger's core gameplay loop is broken; vote forcing and liberation mechanics missing
- **Severity:** 🟠 MAJOR (Multiple abilities missing; role playable but non-functional)

---

#### 4. **THE LIGHTWEIGHT** - ❌ CRITICAL GAP
- **Role Definition:** After each night, Host assigns a "taboo" name; speaking that name = instant death
- **Current State:** NOT IMPLEMENTED
  - No setup script
  - No night announcement for taboo name assignment
  - No validation when Lightweight (or anyone) speaks a name
  - `tabooNames` list exists in Player class but never populated
- **Missing:**
  - No night script step: "Host, assign a taboo name to Lightweight"
  - No game engine logic to track and enforce taboo names
  - No UI/text validation system to detect taboo names spoken
  - No death trigger on speaking taboo name
- **Impact:** Role is completely unplayable; core memory mechanic missing
- **Severity:** 🔴 CRITICAL (Entire role non-functional)

---

#### 5. **THE ALLY CAT** - ⚠️ MAJOR GAP
- **Role Definition:**
  1. Vantage Point: Open eyes when Bouncer checks I.D.; only communicate via 'Meow'
  2. Nine Lives: Has 9 lives; survives 9 kill attempts
- **Current State:** PARTIAL
  - Nine Lives: ✅ FULLY IMPLEMENTED
    - `lives = 9` set in Player.initialize()
    - Kill logic respects multi-life mechanic
  - Vantage Point - Meow Communication: ❌ NOT IMPLEMENTED
    - Ally Cat wakes with Bouncer in `_buildBouncerSteps()` ✅
    - No script step for "meow" communication action
    - No game engine validation for meow-only communication
    - No tracking of when Ally Cat can "meow" vs must stay silent
- **Missing:**
  - No night action script: "Ally Cat, when Bouncer checks, you may meow once"
  - No communication validation system
  - No UI affordance for "meow" communication
- **Impact:** Nine lives work; meow communication entirely missing
- **Severity:** 🟠 MAJOR (Signature ability missing; role playable but incomplete)

---

#### 6. **THE CREEP** - ⚠️ MINOR GAP
- **Role Definition:**
  1. Choose one player on Night 0 to pretend to be (mimic their role/alliance)
  2. When mimicked player dies, Creep inherits their role
- **Current State:** MOSTLY IMPLEMENTED
  - Night 0 selection: ✅ `creep_act`, creep views target's role card
  - Mimicked alliance: ✅ `creep.alliance = target.role.alliance`
  - Inheritance on target death: ⚠️ PARTIALLY
    - `_handleCreepInheritance()` method exists in game_engine.dart
    - Should set `creep.role = target.role` and update alliance
    - Logic appears correct but **not independently tested/verified**
- **Missing:**
  - Test coverage for inheritance mechanic
  - Verification that Creep properly becomes new role after inheritance
- **Impact:** Core mechanic likely works but lacks verification
- **Severity:** 🟡 MINOR (Probably works; needs testing)

---

#### 7. **THE SECOND WIND** - ⚠️ MAJOR GAP
- **Role Definition:**
  1. Starts as Party Animal
  2. If killed, can convince Dealers to convert her to become one of them
  3. If converted: she revives as Dealer, no one else dies that night
- **Current State:** PARTIAL
  - Detection of death: ✅ Game engine detects `role.id == 'second_wind'` when killed
  - Pending conversion: ✅ `secondWindPendingConversion` flag exists
  - **Dealer decision-making: ❌ NOT IMPLEMENTED**
- **Missing:**
  - No script step to ask Dealers: "Do you want to convert Second Wind?"
  - No UI/mechanism for Dealers to vote on conversion
  - No logic to handle Dealer acceptance/rejection
  - No resurrection logic if conversion approved
  - No "no murders" rule if conversion happens
- **Impact:** Second Wind can be killed but cannot be converted; half-implemented
- **Severity:** 🟠 MAJOR (Unique conversion mechanic completely unimplemented)

---

#### 8. **THE DRAMA QUEEN** - ⚠️ MINOR GAP
- **Role Definition:** When voted out and dies, can swap two players' role cards and look at swapped cards
- **Current State:** PARTIAL
  - Script for two-player selection: ✅ `selectTwoPlayers` action type handled
  - Death trigger: ✅ Can detect when Drama Queen is voted out
  - **Swap mechanic: ⚠️ UNCLEAR**
    - `dramaQueenSwap` exists in ability resolver with effect: swap
    - **When exactly does swap happen?** (immediately after death? before morning announcement?)
    - **What can Drama Queen learn?** (visible card swap? hidden info?)
- **Missing:**
  - Clear documentation of swap timing and visibility
  - Verification that swapped roles persist for rest of game
- **Impact:** Mechanic may work but timing/visibility unclear
- **Severity:** 🟡 MINOR (Core mechanic likely present; logic flow unclear)

---

#### 9. **THE BOUNCER - ROOFI CHALLENGE** - ⚠️ MAJOR GAP (DUPLICATE OF #4)
- **Covered above in Bouncer entry**

---

## DETAILED GAP ANALYSIS

### 🔴 CRITICAL GAPS (3 roles)

| Role | Gap | Fix Complexity | Testing Impact |
|------|-----|-----------------|-----------------|
| **The Host** | Entire role excluded from game | MEDIUM | All game modes if Host added |
| **The Whore** | Vote deflection ability missing | MEDIUM | Day-phase voting mechanics |
| **The Lightweight** | Taboo name mechanic missing | HIGH | New name validation system needed |

### 🟠 MAJOR GAPS (4 roles)

| Role | Gap | Fix Complexity | Testing Impact |
|------|-----|-----------------|-----------------|
| **The Clinger** | Vote sync + Attack Dog ability missing | HIGH | Late-game liberation scenarios |
| **The Ally Cat** | Meow communication missing | MEDIUM | Bouncer integration tests |
| **The Second Wind** | Dealer conversion decision missing | HIGH | New voting/resolution system |
| **The Bouncer** | Roofi power-stealing missing | MEDIUM | Bouncer vs Roofi interaction tests |

### 🟡 MINOR GAPS (2 roles)

| Role | Gap | Fix Complexity | Testing Impact |
|------|-----|-----------------|-----------------|
| **The Creep** | Inheritance mechanic unverified | LOW | Add test case for inheritance |
| **The Drama Queen** | Swap timing/visibility unclear | LOW | Clarify and add test case |

---

## SCRIPT FLOW COMPLETENESS

### Night 0 (Setup Night) - Script Coverage

```
✅ Phase transition: "NIGHT FALLS"
✅ Creep: select target + view role card
✅ Clinger: select obsession + view role card
✅ Medic: choose PROTECT/REVIVE strategy
✅ Bouncer: acknowledge rules about Minor vulnerability
⏹️ End setup immediately (no actual actions)
✅ Phase transition: "NIGHT BREAKS" → Morning announcement
```

**Coverage:** 100% ✅

### Night 1+ (Standard Nights) - Script Coverage

```
✅ Phase transition: "NIGHT FALLS"
✅ Role wake notifications in priority order:
   ✅ Dealer (priority 5) - murder selection
   ✅ Medic (priority 2) - protection/revive choice
   ✅ Bouncer (priority 2) - I.D. check
   ✅ Roofi (priority 3) - paralyze selection
   ✅ Club Manager (priority 3) - view role
   ✅ Messy Bitch (priority 1) - spread rumour
   ✅ Silver Fox (priority 1) - force reveal
   ✅ Sober (priority 1) - send home (once per game)
   ⚠️  Clinger (priority 0) - vote sync NOT SCRIPTED
   ⚠️  Whore (priority 0) - vote deflection NOT SCRIPTED
   ✅ Others via generic _buildRoleSteps()

❌ Lightweight: No taboo name assignment step
⚠️  Second Wind: No conversion decision step
⚠️  Ally Cat: No meow communication step
✅ Messy Bitch: Special kill after win condition

✅ Phase transition: "DAY BREAKS"
✅ Morning announcement with deaths reported
✅ Discussion phase
```

**Coverage:** ~85% (missing Lightweight, Second Wind conversion, some deflections)

---

## ABILITY RESOLVER COVERAGE

### Implemented Abilities in AbilityResolver

```dart
✅ dealerKill (priority 5)
✅ medicProtect (priority 2)
✅ medicRevive (priority 1)
✅ roofiSilence (priority 4)
✅ seasonedDrinkerPassive (passive)
✅ minorProtection (passive - kill fail)
✅ messy_bitch_spread (priority 6)
✅ messy_bitch_kill (priority 7)
✅ teaSpillerReveal (onDeath trigger)
✅ predatorRetaliate (onVoted trigger)
✅ allyCatPassive (9 lives - kill respect)
✅ silverFoxReveal (priority 1)
✅ dramaQueenSwap (onDeath trigger)
✅ soberSendHome (priority 1)
```

**Total: 14 ability implementations**

### Missing from AbilityResolver

```dart
❌ whoreDeflect (vote deflection)
❌ roofiChallenge (Bouncer stealing Roofi powers)
❌ clingerVoteSync (must vote with partner)
❌ clingerAttackDog (kill after liberation)
❌ secondWindConvert (Dealer agreement to convert)
❌ creepInherit (role takeover on death) - LIKELY WORKS BUT NOT IN RESOLVER
❌ lightwightTaboo (taboo name enforcement)
❌ allyCatMeow (meow communication validation)
```

**Missing: 8 ability implementations**

---

## GAME ENGINE INTEGRATION POINTS

### Phase Resolution - Properly Integrated ✅

- `_resolveNightPhase()` calls `abilityResolver.resolveAllAbilities()`
- Death reactions trigger properly via `reactionSystem.triggerEvent()`
- Late-joiner activation on night transition ✅
- Win condition checks via `checkGameEnd()`

### Missing Integration Points ⚠️

- **Vote redirection:** No integration point for Whore to redirect votes
- **Vote synchronization:** No mechanism for Clinger to force vote matching
- **Taboo name validation:** No text input validation for Lightweight
- **Conversion voting:** No second voting phase for Second Wind conversion
- **Meow communication:** No special text input validation for Ally Cat
- **Bouncer challenge:** No interaction resolution for Roofi power-stealing

---

## RECOMMENDATION PRIORITY

### Tier 1: CRITICAL (Must fix before release)
1. **Fix The Whore** - Vote deflection mechanic
2. **Fix The Lightweight** - Taboo name system
3. **Clarify The Host** - Include or formally exclude from roles.json

### Tier 2: MAJOR (Important for balanced gameplay)
4. **Fix The Clinger** - Vote sync + Attack Dog
5. **Fix The Second Wind** - Dealer conversion voting
6. **Fix The Bouncer** - Roofi challenge mechanic
7. **Fix The Ally Cat** - Meow communication

### Tier 3: MINOR (Quality of life)
8. **Verify The Creep** - Test inheritance mechanic
9. **Clarify The Drama Queen** - Document swap timing
10. **Test all 27 scenarios** - Ensure no regressions

---

## SUMMARY TABLE

| Role | Status | Script | Resolver | Engine | Tests |
|------|--------|--------|----------|--------|-------|
| Dealer | ✅ | ✅ | ✅ | ✅ | ✅ |
| Party Animal | ✅ | ✅ | ✅ | ✅ | ✅ |
| Medic | ✅ | ✅ | ✅ | ✅ | ✅ |
| Bouncer | ⚠️ | ✅ | ⚠️ | ⚠️ | ⚠️ |
| Minor | ✅ | ✅ | ✅ | ✅ | ✅ |
| Seasoned Drinker | ✅ | ✅ | ✅ | ✅ | ✅ |
| Sober | ✅ | ✅ | ✅ | ✅ | ✅ |
| Wallflower | ✅ | ✅ | ✅ | ✅ | ✅ |
| Roofi | ✅ | ✅ | ✅ | ✅ | ✅ |
| Club Manager | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| Silver Fox | ✅ | ✅ | ✅ | ✅ | ✅ |
| Predator | ✅ | ✅ | ✅ | ✅ | ✅ |
| Tea Spiller | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Host** | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Whore** | ❌ | ⚠️ | ❌ | ❌ | ❌ |
| **Clinger** | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ |
| **Lightweight** | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Ally Cat** | ⚠️ | ⚠️ | ✅ | ⚠️ | ⚠️ |
| **Creep** | ⚠️ | ✅ | ⚠️ | ⚠️ | ⚠️ |
| **Second Wind** | ❌ | ⚠️ | ❌ | ❌ | ❌ |
| **Drama Queen** | ⚠️ | ✅ | ⚠️ | ⚠️ | ⚠️ |

**Fully Working: 13 roles**  
**Partially Working: 6 roles**  
**Broken/Missing: 3 roles**

---

## NEXT STEPS

1. ✅ **Assessment Complete** - All 22 roles audited
2. ⏳ **Gap Fixes Needed** - 9 roles require implementation
3. ⏳ **Integration Testing** - Verify fixes work with game flow
4. ⏳ **Regression Testing** - Ensure 27 test suite still passes

---

## Role Implementation Audit (Current)

### Properly wired through GameEngine
- Dealer: selection canonicalized to `kill`
- Medic: protect canonicalized to `protect`; revive handled via UI + dead list sync
- Bouncer: canonicalized to `bouncer_check`; sets `idCheckedByBouncer` and Minor flag
- Roofi: canonicalized to `roofi`; sets `silencedDay` (+ dealer block)
- Creep: canonicalized to `creep_target`; inheritance on victim death
- Clinger: obsession stored; heartbreak double-death on partner death
- Drama Queen / Tea Spiller: death reactions dispatched via ReactionSystem

### Known “UI-driven” (not fully engine-authored)
- Voting telemetry (per-voter) is not captured by current vote UI (uses tap counters, no voter ids).

## Role Implementation Audit

Primary consistency checks:
- `nightActions` step ids are canonicalized into engine keys in `_canonicalizeNightActions()`
- `deadPlayerIds` matches `players.where(!isAlive)`
- String enums: Medic choice is `PROTECT_DAILY` or `REVIVE` (engine + UI must match)

