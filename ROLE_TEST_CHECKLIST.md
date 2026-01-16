# ROLE TEST CHECKLIST

This checklist provides a prioritized testing roadmap for Club Blackout role implementations, based on the ROLE_IMPLEMENTATION_AUDIT.md findings.

## TIER 1: CRITICAL - Must Fix Before Release

### 🔴 The Whore
**Status:** Vote deflection mechanic missing  
**Priority:** CRITICAL  
**Implementation Gap:** No night script step or ability resolver for vote deflection

**Suggested Tests:**
- [ ] Test Whore can select a deflection target during night phase
- [ ] Test votes against Dealer are redirected to deflection target during day phase
- [ ] Test votes against Whore herself are redirected to deflection target
- [ ] Test deflection does not apply to votes against Party Animals
- [ ] Test Whore can change deflection target each night
- [ ] Test deflection persists throughout the day phase after being set

---

### 🔴 The Lightweight
**Status:** Taboo name mechanic entirely missing  
**Priority:** CRITICAL  
**Implementation Gap:** No name validation system, no taboo name assignment, no death trigger

**Suggested Tests:**
- [ ] Test Host can assign taboo name to Lightweight each night
- [ ] Test taboo name is stored in Lightweight's tabooNames list
- [ ] Test Lightweight dies immediately when speaking taboo name
- [ ] Test other players speaking taboo name does not affect Lightweight
- [ ] Test multiple taboo names accumulate over game (if design allows)
- [ ] Test taboo name is case-insensitive
- [ ] Test taboo name matching handles partial words vs full words
- [ ] Test Lightweight can still speak non-taboo names safely

---

### 🔴 The Host
**Status:** Entire role excluded from game  
**Priority:** CRITICAL (if intended to be playable)  
**Implementation Gap:** Filtered out in roleRepository; no script generation

**Decision Needed:** Is Host meant to be a playable role or just a facilitator?

**Suggested Tests (if playable):**
- [ ] Test Host role can be assigned to a player
- [ ] Test Host has no night actions (passive role)
- [ ] Test Host can facilitate game without breaking mechanics
- [ ] Test Host does not count toward victory conditions
- [ ] OR: Document that Host is NPC-only and update roles.json accordingly

---

## TIER 2: MAJOR - Important for Balanced Gameplay

### 🟠 The Clinger
**Status:** Vote sync and Attack Dog mechanics missing  
**Priority:** MAJOR  
**Implementation Gap:** No vote synchronization, no "controller" trigger, no kill ability after liberation

**Suggested Tests:**
- [ ] Test Clinger selects obsession partner on Night 0
- [ ] Test Clinger views obsession's role card on Night 0
- [ ] Test Clinger must vote exactly as obsession votes during day phase
- [ ] Test Clinger vote is automatically updated if obsession changes vote
- [ ] Test Clinger cannot vote independently while obsessed
- [ ] Test Clinger dies when obsession dies (death sync)
- [ ] Test obsession calling Clinger "controller" liberates them
- [ ] Test liberated Clinger gains Attack Dog ability (one-time kill)
- [ ] Test liberated Clinger can vote independently after liberation
- [ ] Test Attack Dog kill is separate from Dealer kills
- [ ] Test Attack Dog ability can only be used once

---

### 🟠 The Second Wind
**Status:** Dealer conversion voting missing  
**Priority:** MAJOR  
**Implementation Gap:** No script step for Dealer decision, no conversion logic

**Suggested Tests:**
- [ ] Test Second Wind starts as Party Animal
- [ ] Test Second Wind is detected when killed by Dealers
- [ ] Test Dealers are prompted to vote on conversion
- [ ] Test all Dealers must agree (or majority) to convert Second Wind
- [ ] Test if Dealers accept: Second Wind revives as Dealer
- [ ] Test if Dealers accept: no other deaths occur that night
- [ ] Test if Dealers reject: Second Wind stays dead
- [ ] Test if Dealers reject: normal deaths still occur
- [ ] Test converted Second Wind gains Dealer alliance and abilities
- [ ] Test converted Second Wind counts toward Dealer parity

---

### 🟠 The Bouncer - Roofi Challenge
**Status:** Roofi power-stealing mechanic missing  
**Priority:** MAJOR  
**Implementation Gap:** No challenge mechanic, no ability transfer logic

**Suggested Tests:**
- [ ] Test Bouncer can challenge player suspected of being Roofi
- [ ] Test if challenged player IS Roofi: Bouncer gains Roofi's silence ability
- [ ] Test if challenged player IS Roofi: Roofi loses silence ability permanently
- [ ] Test if challenged player IS Roofi: Bouncer keeps ID check ability
- [ ] Test if challenged player is NOT Roofi: Bouncer loses ID check ability permanently
- [ ] Test if challenged player is NOT Roofi: Roofi keeps silence ability
- [ ] Test Bouncer can only challenge once per game
- [ ] Test Bouncer with Roofi ability can silence one player per night
- [ ] Test Bouncer without ID ability cannot check IDs anymore

---

### 🟠 The Ally Cat
**Status:** Meow communication mechanic missing  
**Priority:** MAJOR  
**Implementation Gap:** No meow-only communication validation system

**Suggested Tests:**
- [ ] Test Ally Cat has 9 lives (passive ability) ✅ (already implemented)
- [ ] Test Ally Cat survives 9 kill attempts ✅ (already implemented)
- [ ] Test Ally Cat wakes with Bouncer during ID checks
- [ ] Test Ally Cat can communicate only via "meow" during night
- [ ] Test Ally Cat cannot speak normal words when awake at night
- [ ] Test Ally Cat can speak freely during day phase
- [ ] Test meow communication provides hints without revealing role
- [ ] Test Host validates Ally Cat communication is meow-only

---

## TIER 3: MINOR - Quality of Life

### 🟡 The Creep
**Status:** Inheritance mechanic likely works but unverified  
**Priority:** MINOR  
**Implementation Gap:** Needs test coverage

**Suggested Tests:**
- [ ] Test Creep selects mimic target on Night 0 ✅ (script exists)
- [ ] Test Creep views target's role card on Night 0 ✅ (script exists)
- [ ] Test Creep's alliance matches target's alliance ✅ (logic exists)
- [ ] Test when target dies, Creep inherits their role
- [ ] Test when target dies, Creep gains their abilities
- [ ] Test when target dies, Creep's alliance updates to inherited role
- [ ] Test Creep cannot choose Host as mimic target
- [ ] Test Creep inheritance is permanent (cannot change after)

---

### 🟡 The Drama Queen
**Status:** Swap mechanic timing/visibility unclear  
**Priority:** MINOR  
**Implementation Gap:** Documentation needed

**Suggested Tests:**
- [ ] Test Drama Queen triggers swap when voted out and dies
- [ ] Test Drama Queen can select two players for swap
- [ ] Test selected players' roles are swapped
- [ ] Test Drama Queen can view the swapped roles
- [ ] Test swap happens before morning announcement (or clarify timing)
- [ ] Test swapped players do not know their roles were swapped
- [ ] Test swapped roles persist for remainder of game
- [ ] Test swapped players gain new role abilities immediately
- [ ] Test Drama Queen cannot swap if killed at night (only if voted out)

---

## FULLY IMPLEMENTED ROLES ✅

These roles have comprehensive implementations and should be regression-tested:

### ✅ The Dealer
- [x] Dealers vote on kill target each night
- [x] Consensus kill is resolved
- [x] Works with Whore and Wallflower wake calls

### ✅ The Medic
- [x] Night 0: Binary choice between PROTECT and REVIVE
- [x] PROTECT mode: Shield one player each night
- [x] REVIVE mode: Resurrect one dead player once per game
- [x] Choice persists throughout game

### ✅ The Bouncer - ID Check Only
- [x] Check player's identity each night
- [x] Host nods if Dealer, shakes if not
- [x] Minor vulnerability detection
- (Roofi challenge separate - see Tier 2)

### ✅ The Minor
- [x] Cannot die unless ID'd by Bouncer first
- [x] First kill attempt fails but marks as ID'd
- [x] Second kill attempt succeeds

### ✅ The Seasoned Drinker
- [x] Lives equal number of Dealers
- [x] Survives multiple kills
- [x] Lives decrease with each kill

### ✅ The Sober
- [x] Once per game, send one player home
- [x] Sent player protected from death
- [x] If Dealer sent home, no murders that night

### ✅ The Wallflower
- [x] Optional witness Dealer murder
- [x] Wakes with Dealers
- [x] Can provide hints next day

### ✅ The Roofi
- [x] Paralyze one player each night
- [x] Target cannot speak/vote next round
- [x] Status effect properly applied

### ✅ The Club Manager
- [x] View one player's role each night
- [x] Information-gathering ability
- [x] No direct game impact

### ✅ The Silver Fox
- [x] Once per game, force role reveal
- [x] Entire club sees reveal
- [x] One-time ability

### ✅ The Predator
- [x] When voted out, choose one voter to kill
- [x] Retaliation mechanic
- [x] Day-phase trigger

### ✅ The Tea Spiller
- [x] On death, expose one player as Dealer or Not
- [x] Death trigger
- [x] Information reveal

### ✅ The Party Animal
- [x] No abilities (passive role)
- [x] Correctly implemented

---

## TESTING STRATEGY

### Integration Tests Priority
1. **Critical roles first** (Whore, Lightweight, Host decision)
2. **Major mechanics second** (Clinger, Second Wind, Bouncer challenge, Ally Cat)
3. **Minor verification last** (Creep, Drama Queen)

### Test Approach
- **Unit tests**: Individual role abilities in isolation
- **Integration tests**: Multi-role interactions (e.g., Whore + Dealer, Bouncer + Roofi)
- **Scenario tests**: Full game flows with specific role combinations
- **Edge case tests**: Simultaneous effects, death cascades, ability conflicts

### Determinism Requirements
- All role resolution must be deterministic
- Tie-breaks use lexicographic ordering
- Priority-based resolution order documented
- No random elements in core mechanics

---

## NOTES

- Tests marked with ✅ indicate existing implementation verified
- Tests marked with [ ] need to be written
- Each role should have minimum 5-7 focused unit tests
- Complex roles (Clinger, Second Wind) need 10+ tests
- Use MockRoleRepository for controlled test environments
- Follow existing test patterns in `test/full_game_scenarios_v2_test.dart`

---

**Last Updated:** January 16, 2026  
**Based On:** ROLE_IMPLEMENTATION_AUDIT.md  
**Status:** Living document - update as implementations progress
