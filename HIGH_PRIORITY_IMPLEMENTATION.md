# High Priority Role Mechanics - Implementation Summary

## Completed Implementation (Phase 1)

### 1. Club Manager - View Role Card ✅
**Status:** COMPLETE

**Changes:**
- `roles.json`: Updated night_priority from 4 to 3, added `"ability": "view_role"`
- `script_builder.dart`: Added custom script step with clear instructions to show the selected player's character card
- `game_engine.dart`: Added handler in `handleScriptAction` to log which role was viewed

**How it works:**
- Club Manager wakes at priority 3 (before Roofi)
- Selects one player
- Host shows that player's character card to the Club Manager
- Logged for game review

---

### 2. Silver Fox - Force Reveal ✅
**Status:** COMPLETE

**Changes:**
- `roles.json`: Added `"ability": "force_reveal"` (keeps priority 1)
- `player.dart`: Added `silverFoxAbilityUsed` boolean field
- `script_builder.dart`: Added custom script step explaining the once-per-game forced reveal
- `game_engine.dart`: Added handler that checks if ability is used, queues reveal effect, marks as used

**How it works:**
- Silver Fox wakes at priority 1 (early in night)
- Once per game, can force a player to reveal their role next day phase
- Ability is tracked via `silverFoxAbilityUsed` flag
- Queues a reveal ability with priority 1

---

### 3. Wallflower - Witness Murder ✅
**Status:** COMPLETE

**Changes:**
- `roles.json`: Updated night_priority from 4 to 5, added `"ability": "witness_murder"`
- `script_step.dart`: Added `ScriptActionType.optional` enum value
- `script_builder.dart`: Added custom script step for optional witnessing
- `game_engine.dart`: Added handler that checks if Wallflower chose to witness, reveals dealer target

**How it works:**
- Wallflower wakes at priority 5 (after Dealer kill at priority 5)
- Optional action: can choose to witness or not
- If they witness, host reveals who the Dealers targeted
- Information is logged

---

### 4. The Sober - Send Home ✅
**Status:** COMPLETE

**Changes:**
- `roles.json`: Updated night_priority from 0 to 1, added `"ability": "send_home"`
- `player.dart`: Added `soberAbilityUsed` boolean field
- `script_builder.dart`: Added custom script step explaining the once-per-game protection
- `game_engine.dart`: Added handler that:
  - Checks if ability is used
  - Queues protection ability with priority 1 (early, before kills)
  - Special logic: if target is a Dealer, cancels ALL kills that night
  - Marks as used

**How it works:**
- Sober wakes at priority 1 (very early, before kills)
- Once per game, sends one player home (protected from death)
- If the sent-home player is a Dealer, NO murders happen that night
- Ability tracked via `soberAbilityUsed` flag

---

### 5. Minor - Death Protection ✅
**Status:** COMPLETE

**Changes:**
- `player.dart`: Added `minorHasBeenIDd` boolean field (already existed from previous work)
- `ability_system.dart`: Updated `_resolveKill` method to check for Minor
  - If target is Minor AND not yet ID'd, survives but becomes ID'd
  - If Minor is ID'd, dies normally
- `game_engine.dart`: Updated `_resolveNightPhase` to handle Minor protection logging
  - Shows special message when Minor survives an attack
  - Announces they've been ID'd

**How it works:**
- Minor is passive (no night action)
- First time Dealers target Minor, they survive but become "ID'd"
- `minorHasBeenIDd` is set to true, removing protection
- Second attack kills Minor normally
- Bouncer checking Minor's ID also sets this flag (already implemented)

---

## Priority Order (Night Phase)

1. **Silver Fox** (priority 1) - Force reveal
2. **The Sober** (priority 1) - Send home / protection
3. **Medic/Bouncer** (priority 2) - Protection
4. **Club Manager** (priority 3) - View role
5. **Roofi** (priority 4) - Silence
6. **Dealer** (priority 5) - Kill
7. **Wallflower** (priority 5) - Witness (after Dealer)
8. **Messy Bitch** (priority 6) - Spread rumour

---

## Testing Checklist

- [ ] Club Manager can view a role card each night
- [ ] Silver Fox can force reveal once per game
- [ ] Silver Fox ability is disabled after first use
- [ ] Wallflower can optionally witness Dealer target
- [ ] Sober can send someone home once per game
- [ ] Sober sending a Dealer home cancels all kills
- [ ] Minor survives first attack
- [ ] Minor becomes vulnerable after first attack
- [ ] Minor protection message appears correctly
- [ ] Bouncer ID'ing Minor removes protection

---

## Next Steps (Medium Priority)

1. **Ally Cat** - Social alignment mechanics
2. **Whore** - Role swap ability  
3. **Second Wind** - Death -> Party Animal conversion
4. **Lightweight** - Taboo word mechanics

