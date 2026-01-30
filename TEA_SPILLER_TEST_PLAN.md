# Tea Spiller Logic Implementation Plan

## Objective
Persist the Tea Spiller's mark so that if they die (Day or Night), the correct target is revealed, even if `nightActions` has been cleared for the new phase.

## Changes Applied

### 1. Data Model (`lib/models/player.dart`)
- Added `String? teaSpillerMarkId` to the `Player` class.
- This ensures the marked target is tied to the Tea Spiller player instance.

### 2. Game Engine (`lib/logic/game_engine.dart`)
- **Night Action**: In `handleScriptAction` (case `tea_spiller`), the target ID is now saved to `sourcePlayer.teaSpillerMarkId`.
- **Reaction**: In `_handleTeaSpillerReveal`, the target ID is read from `reaction.sourcePlayer.teaSpillerMarkId`.
  - Added fallback to `nightActions` for backward compatibility during active game updates.
- **Cleanup**: In `_resetPlayerStateForNewRole`, `teaSpillerMarkId` is set to `null`.

## Verification Steps / Test Case

1. **Setup**:
   - Assign **Player A** as **Tea Spiller**.
   - Assign **Player B** as **Dealer**.

2. **Night 1**:
   - **Tea Spiller** (Player A) marks **Player B**.
   - Ensure the log shows "Tea Spiller marked Player B...".

3. **Day 1**:
   - Do NOT kill the Tea Spiller yet.
   - Vote out someone else or skip.

4. **Night 2**:
   - (Optional) **Tea Spiller** can mark someone else. If they do, the new mark should overwrite.
   - Let's assume they *don't* change (or wake up and confirm Player B again).

5. **Day 2 (Death Test)**:
   - Vote out **Tea Spiller** (Player A).
   - **EXPECTED RESULT**: The game log should show:
     > "Tea Spilled! Player A revealed: Player B is the Dealer!"

## Edge Cases

- **Roofi Block**: If Tea Spiller is Roofied on Night 2, they cannot update their mark. The mark from Night 1 will persist. If they die, they reveal the Night 1 target.
- **Game Reset**: Starting a new game properly clears the mark (via player recreation).
