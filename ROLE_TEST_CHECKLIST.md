# ROLE TEST CHECKLIST

This document provides a prioritized list of roles and suggested test cases based on the ROLE_IMPLEMENTATION_AUDIT.md findings.

## Priority Legend
- 🔴 **CRITICAL**: Role is non-functional or core ability is missing
- 🟠 **MAJOR**: Multiple abilities missing; role playable but incomplete
- 🟡 **MINOR**: Mechanic probably works but needs testing/verification
- ✅ **COMPLETE**: Fully implemented

---

## HIGH PRIORITY (Critical Gaps) 🔴

### 1. THE WHORE 🔴
**Status**: Critical gap - core deflection ability missing

**Suggested Test Cases**:
- [ ] Whore deflects vote from Dealer to Party Animal
- [ ] Whore deflects vote from herself to another player
- [ ] Whore deflection only works once per day/night cycle
- [ ] Deflection fails if target is invalid or dead

---

### 2. THE LIGHTWEIGHT 🔴
**Status**: Not implemented - entire taboo name mechanic missing

**Suggested Test Cases**:
- [ ] Host assigns taboo name to Lightweight at night
- [ ] Lightweight dies when speaking their taboo name during day
- [ ] Other players can speak taboo name without penalty
- [ ] Multiple taboo names accumulate over multiple nights
- [ ] Lightweight survives if taboo name not spoken

---

### 3. THE HOST 🔴
**Status**: Excluded from game entirely

**Suggested Test Cases**:
- [ ] Host role can be selected/assigned in role selection
- [ ] Host has appropriate game master permissions
- [ ] Host can facilitate night actions without participating
- [ ] Host abilities don't interfere with normal gameplay

---

## MEDIUM PRIORITY (Major Gaps) 🟠

### 4. THE CLINGER 🟠
**Status**: Partial - death sync works, vote sync and Attack Dog missing

**Suggested Test Cases**:
- [ ] Clinger dies when obsession partner dies
- [ ] Clinger must vote exactly as partner votes (vote sync)
- [ ] Clinger is freed when called "controller" by obsession
- [ ] Freed Clinger can use Attack Dog ability to kill one player
- [ ] Attack Dog ability is one-time use only
- [ ] Clinger cannot use Attack Dog before being freed

---

### 5. THE ALLY CAT 🟠
**Status**: Partial - nine lives works, meow communication missing

**Suggested Test Cases**:
- [ ] Ally Cat starts with 9 lives
- [ ] Ally Cat survives 9 kill attempts
- [ ] Ally Cat dies on 10th kill attempt
- [ ] Ally Cat wakes with Bouncer during ID checks
- [ ] Ally Cat can only communicate via "meow" during certain phases
- [ ] Non-meow communication from Ally Cat is blocked/invalid

---

### 6. THE SECOND WIND 🟠
**Status**: Partial - death detection works, conversion mechanic missing

**Suggested Test Cases**:
- [ ] Second Wind starts as Party Animal alliance
- [ ] When killed, Dealers are prompted for conversion decision
- [ ] If Dealers accept: Second Wind revives as Dealer
- [ ] If Dealers accept: no other murders occur that night
- [ ] If Dealers reject: Second Wind stays dead
- [ ] Conversion offer only happens once

---

### 7. THE BOUNCER (Roofi Challenge) 🟠
**Status**: Partial - ID check works, Roofi power-stealing missing

**Suggested Test Cases**:
- [ ] Bouncer can ID check players (nod for Dealer, shake for not)
- [ ] Bouncer can challenge Roofi to steal paralyze ability
- [ ] Successful challenge: Bouncer gains Roofi's ability, Roofi loses it
- [ ] Failed challenge: Bouncer loses ID check ability permanently
- [ ] Minor vulnerability to Bouncer ID check

---

## LOW PRIORITY (Minor Gaps) 🟡

### 8. THE CREEP 🟡
**Status**: Mostly implemented - needs test verification

**Suggested Test Cases**:
- [ ] Creep selects target on Night 0 and views their role
- [ ] Creep's alliance matches mimicked player's alliance
- [ ] When mimicked player dies, Creep inherits their role completely
- [ ] Creep's abilities change to match inherited role
- [ ] Creep can only mimic one player per game

---

### 9. THE DRAMA QUEEN 🟡
**Status**: Partial - swap timing and visibility unclear

**Suggested Test Cases**:
- [ ] Drama Queen can select two players when voted out
- [ ] Selected players' roles are swapped
- [ ] Drama Queen views both swapped role cards
- [ ] Swapped roles persist for rest of game
- [ ] Swap timing is clearly defined (before/after morning announcement)

---

### 10. THE MESSY BITCH 🟡
**Status**: Mostly implemented - win condition needs testing

**Suggested Test Cases**:
- [ ] Messy Bitch can spread rumour to one player per night
- [ ] Each player can only receive one rumour (no duplicates)
- [ ] Messy Bitch wins when all living players (except self) have rumours
- [ ] Messy Bitch's special kill activates after win condition met
- [ ] Special kill is one-time use

---

## FULLY IMPLEMENTED ROLES ✅

### 11. THE DEALER ✅
**Suggested Test Cases**:
- [x] Dealers wake together and select kill target
- [x] Dealer kill uses vote count with lexicographic tie-breaking
- [x] Kill is prevented if Medic protects target
- [x] Kill is prevented if Sober sends Dealer home
- [x] Multiple Dealers coordinate kills properly

---

### 12. THE MEDIC ✅
**Suggested Test Cases**:
- [x] Medic chooses PROTECT or REVIVE on Night 1 (binary choice)
- [x] Choice cannot be changed after Night 1
- [x] PROTECT mode: shields one player per night from death
- [x] REVIVE mode: resurrects one dead player once per game
- [x] Medic protection prevents Dealer kill

---

### 13. THE BOUNCER (ID Check Only) ✅
**Suggested Test Cases**:
- [x] Bouncer can check one player's ID per night
- [x] Host nods if target is Dealer
- [x] Host shakes head if target is Party Animal
- [x] Minor is vulnerable after being ID'd by Bouncer

---

### 14. THE MINOR ✅
**Suggested Test Cases**:
- [x] Minor cannot die until Bouncer has ID'd them
- [x] First Dealer kill attempt on un-ID'd Minor fails
- [x] First kill attempt marks Minor as ID'd
- [x] Minor can be killed after being ID'd

---

### 15. THE SEASONED DRINKER ✅
**Suggested Test Cases**:
- [x] Seasoned Drinker has lives equal to number of Dealers
- [x] Survives multiple kill attempts (one per Dealer)
- [x] Dies after all lives are depleted
- [x] Lives update if Dealer count changes

---

### 16. THE SOBER ✅
**Suggested Test Cases**:
- [x] Sober can send one player home once per game
- [x] Sent home player is protected from death that night
- [x] If Dealer sent home: no murders occur that night
- [x] Ability can only be used once (tracked via flag)

---

### 17. THE WALLFLOWER ✅
**Suggested Test Cases**:
- [x] Wallflower can optionally witness Dealer's murder
- [x] Wallflower wakes with Dealers to see target selection
- [x] Witnessing is optional (Wallflower can choose to stay asleep)
- [x] Information is used for hints during day phase

---

### 18. THE ROOFI ✅
**Suggested Test Cases**:
- [x] Roofi can paralyze one player per night
- [x] Paralyzed player cannot speak or move during next round
- [x] If Dealer is Roofi'd, they're paralyzed following night too
- [x] Bouncer can challenge Roofi to steal ability (see Bouncer section)

---

### 19. THE CLUB MANAGER ✅
**Suggested Test Cases**:
- [x] Club Manager can view one player's role card per night
- [x] Information is private to Club Manager
- [x] Can choose to help either side based on survival strategy
- [x] Ability works every night (not one-time)

---

### 20. THE SILVER FOX ✅
**Suggested Test Cases**:
- [x] Silver Fox can force one player to reveal role (once per game)
- [x] Reveal happens at night and entire club sees it
- [x] Ability is one-time use only
- [x] Cannot be used after first use

---

### 21. THE PREDATOR ✅
**Suggested Test Cases**:
- [x] When voted out, Predator selects one voter
- [x] Selected voter dies with Predator
- [x] Retaliation only triggers on vote-out (not night kill)
- [x] Predator must select from actual voters

---

### 22. THE TEA SPILLER ✅
**Suggested Test Cases**:
- [x] When Tea Spiller dies, they expose one player
- [x] Exposure reveals if player is Dealer or Not Dealer
- [x] Ability triggers on any death (night kill or vote-out)
- [x] Exposure happens during morning announcement

---

### 23. THE PARTY ANIMAL ✅
**Suggested Test Cases**:
- [x] No special abilities (passive role)
- [x] Participates in voting during day phase
- [x] Can be killed by Dealers at night
- [x] Wins when all Dealers are eliminated

---

## Testing Strategy

### Unit Tests
Focus on testing individual role abilities in isolation:
- Use minimal Player/Role construction
- Test single ability at a time
- Verify state changes and flags

### Integration Tests
Test role interactions:
- Dealer kill + Medic protect
- Bouncer ID + Minor vulnerability
- Sober send home + Dealer kill cancellation
- Roofi silence + Dealer paralysis

### Scenario Tests
Full game scenarios with multiple roles:
- Victory conditions (parity, elimination)
- Edge cases (all Party Animals dead, single Dealer)
- Complex interactions (multiple protective roles)

### Schema Tests
- Validate roles.json structure
- Ensure required fields exist
- Check for duplicate IDs/names
- Verify night_priority values are valid
