# ROLE TEST CHECKLIST

This checklist prioritizes roles to test based on implementation complexity and gaps identified in ROLE_IMPLEMENTATION_AUDIT.md.

## PRIORITY 1: CORE MECHANICS (High Impact, Currently Tested)

### ✅ The Dealer
- [x] Basic kill action (covered in night_resolver_test.dart)
- [x] Victory parity check (covered in night_resolver_victory_test.dart)
- [x] Multiple dealers voting consensus (covered in night_resolver_test.dart)
- [ ] Blocked by Roofi (silenced dealer cannot kill next night)
- [ ] Cancelled by Sober (covered in night_resolver_test.dart for basic case)

### ✅ The Medic
- [x] Protection prevents dealer kill (covered in night_resolver_test.dart)
- [ ] PROTECT_DAILY mode - nightly protection
- [ ] RESUSCITATE_ONCE mode - one-time revive
- [ ] Revive time limit (can only revive players who died within last 2 days)
- [ ] Revive token used flag prevents duplicate revives

### ✅ The Party Animal
- [ ] Victory condition (all dealers eliminated)
- [ ] No special abilities (baseline role for testing)

---

## PRIORITY 2: PARTIALLY IMPLEMENTED ROLES (Missing Critical Features)

### ⚠️ The Whore (Vote Deflection Missing)
**Status:** Vote deflection during day phase not implemented

**Suggested Tests:**
- [ ] Select target during night (basic selection)
- [ ] Deflect vote when Dealer is voted out
- [ ] Deflect vote when Whore themselves is voted out
- [ ] Original target survives, deflection target dies
- [ ] Interaction with Predator retaliation

### ⚠️ The Lightweight (Taboo Tracking Incomplete)
**Status:** Taboo name collection works, but real-time death trigger missing

**Suggested Tests:**
- [ ] Collect taboo names each night
- [ ] Track cumulative list of forbidden names
- [ ] Die immediately when speaking any taboo name during day phase
- [ ] Edge case: Speaking own name if added to taboo list
- [ ] Multiple Lightweights (if allowed)

### ⚠️ The Creep (Inheritance Timing)
**Status:** Inherits role on target death, but may have edge cases

**Suggested Tests:**
- [ ] Choose mimicry target on Night 0
- [ ] Inherit role when target dies
- [ ] Inherit alliance along with role
- [ ] Cannot inherit if target dies before Night 0 selection
- [ ] Interaction with Drama Queen swap (does Creep track original or swapped target?)

### ⚠️ The Clinger (Attack Dog Trigger Missing)
**Status:** Obsession death works, but "controller" word trigger not implemented

**Suggested Tests:**
- [ ] Choose obsession on Night 0
- [ ] Die when obsession dies (heartbreak)
- [ ] Liberate when called "controller" during day
- [ ] Use Attack Dog kill ability after liberation
- [ ] One-time kill ability usage
- [ ] Cannot die from obsession death after liberation

### ⚠️ Second Wind (Conversion Flow)
**Status:** Basic trigger works, but full conversion flow may have gaps

**Suggested Tests:**
- [ ] Trigger on any death (night kill, vote, etc.)
- [ ] Dealers vote on conversion (accept/reject)
- [ ] Conversion: becomes Dealer, survives, joins team
- [ ] Rejection: dies normally
- [ ] Interaction with Medic protection (if protected, no trigger?)

---

## PRIORITY 3: ROLES WITH MISSING MECHANICS (Not Implemented)

### ❌ The Bouncer (Roofi Challenge)
**Status:** ID check works, Roofi challenge not implemented

**Suggested Tests:**
- [ ] Basic ID check reveals alliance
- [ ] Minor loses immunity after ID check
- [ ] Challenge Roofi during night
- [ ] Win challenge: gain Roofi's silence ability, Roofi loses ability
- [ ] Lose challenge: lose ID check ability, Roofi keeps ability
- [ ] Can use stolen Roofi ability in future nights

### ❌ Silver Fox (Public Reveal)
**Status:** One-time ability selection works, but day-phase reveal not implemented

**Suggested Tests:**
- [ ] Select target during night (one-time use)
- [ ] Target forced to publicly reveal role next day
- [ ] Reveal happens at start of day phase
- [ ] Cannot use ability more than once
- [ ] Interaction with other reveal mechanics (Club Manager)

### ❌ Messy Bitch (Win Condition)
**Status:** Rumor spreading works, but win detection may be incomplete

**Suggested Tests:**
- [ ] Spread rumor to one player per night
- [ ] Track rumor recipients
- [ ] Win when ALL other alive players have rumor
- [ ] Post-win special kill ability unlocked
- [ ] One-time special kill after achieving win

### ❌ Tea Spiller (Death Reveal)
**Status:** Marked target stored, but reveal trigger uncertain

**Suggested Tests:**
- [ ] Mark player during night
- [ ] Reveal marked player's role when Tea Spiller dies
- [ ] Only reveals if target still alive when Tea Spiller dies
- [ ] Interaction with Drama Queen (if Tea Spiller dies via swap)

### ❌ Drama Queen (Role Swap)
**Status:** Swap logic exists but may have edge cases

**Suggested Tests:**
- [ ] Mark two players during night
- [ ] Trigger swap when Drama Queen dies
- [ ] Swap roles between marked players
- [ ] Swap resets player state (lives, abilities, etc.)
- [ ] Only one swap per Drama Queen death
- [ ] Interaction with Creep (if swapped player was Creep's target)

---

## PRIORITY 4: COMPLEX INTERACTIVE ROLES (Lower Priority)

### The Predator
**Suggested Tests:**
- [ ] Mark retaliation target during night
- [ ] Kill marked target when voted out during day
- [ ] Does not kill if eliminated at night
- [ ] Retaliation is guaranteed (ignores protection?)

### The Club Manager
**Suggested Tests:**
- [ ] View any player's role during night
- [ ] Information revealed to host only (not public)
- [ ] Can use every night (no limits)

### The Bartender
**Suggested Tests:**
- [ ] Check two players' alliance match
- [ ] Return "same team" for same alliance
- [ ] Return "different team" for different alliances
- [ ] Neutrals never match with anyone

### The Wallflower
**Suggested Tests:**
- [ ] Choose to witness or not during night
- [ ] If witness: learn dealer kill target
- [ ] If not witness: no information
- [ ] Information revealed to player only

---

## PRIORITY 5: PASSIVE/SPECIAL CASE ROLES

### The Minor
**Suggested Tests:**
- [x] Immune to dealer kills until ID'd (covered in ROLE_IMPLEMENTATION_AUDIT.md)
- [ ] Vulnerable after Bouncer ID check
- [ ] Dies normally to votes

### The Seasoned Drinker
**Suggested Tests:**
- [x] Lives equal to dealer count (covered in existing tests)
- [ ] Loses one life per dealer attack
- [ ] Dies when all lives consumed
- [ ] Dies normally to votes (no extra lives)

### The Sober
**Suggested Tests:**
- [x] Send player home (one-time ability) (covered in night_resolver_test.dart)
- [x] Sent player protected from death (covered in night_resolver_test.dart)
- [x] If dealer sent home, no murders that night (covered in night_resolver_test.dart)
- [ ] Sent player cannot act that night (blocked)

### Roofi
**Suggested Tests:**
- [ ] Silence player for next day
- [ ] If target is Dealer, block kill next night
- [ ] Silenced players cannot speak/vote during day
- [ ] Effect expires after one day/night cycle

### The Ally Cat
**Suggested Tests:**
- [ ] Starts with 9 lives
- [ ] Loses one life per attack (dealer kill or vote)
- [ ] Dies when all 9 lives consumed
- [ ] Lives persist across day and night phases

---

## TEST INFRASTRUCTURE PRIORITIES

### Unit Tests
- [x] NightResolver deterministic kill resolution
- [x] Victory parity checks
- [x] Roles schema validation
- [ ] Reaction system triggers
- [ ] Ability priority ordering
- [ ] Status effect management

### Integration Tests
- [ ] Full night resolution with multiple roles
- [ ] Day-to-night phase transitions
- [ ] Vote processing with special abilities
- [ ] Save/load game state

### Edge Case Tests
- [ ] All players dead (no winner)
- [ ] Single player remaining
- [ ] Multiple role swaps in one night
- [ ] Simultaneous deaths (Clinger + obsession)
- [ ] Protection vs. multi-life mechanics

---

## NOTES FOR IMPLEMENTERS

1. **Start with Priority 1-2** - These are the most impactful and currently have gaps.

2. **Use Minimal Role Construction** - The existing tests show how to create minimal Role and Player objects. This keeps tests fast and focused.

3. **Test One Mechanic at a Time** - Each test should verify a single behavior. Combine multiple assertions only when testing the same action's multiple effects.

4. **Mock Time-Dependent Logic** - For roles like Medic's 2-day revive window, use controlled day counts rather than real timestamps.

5. **Parallel Test Execution** - Ensure tests are independent and can run in any order.

6. **Coverage Goals** - Aim for >80% coverage on logic files (game_engine.dart, night_resolver.dart, ability_system.dart).

7. **CI Integration** - All tests should pass in the GitHub Actions workflow before merging.
