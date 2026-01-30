# Minor Role Implementation Review

## Current Implementation Status
The "Minor" role logic is already correctly implemented in the `GameEngine`.

### 1. Death Protection (`processDeath` in `lib/logic/game_engine.dart`)
- **Logic:** Calls to `processDeath` (specifically for 'night_kill' or 'dealer_kill') check if the victim is the Minor.
- **Condition:** `if (victim.role.id == 'minor' && isDealerKillAttempt && !victim.minorHasBeenIDd)`
- **Effect:** If the Minor has NOT been ID'd, the death is prevented, and a log entry is created: "${name} is The Minor and cannot be killed until ID’d by the Bouncer."

### 2. ID-Check Mechanics (`handleScriptAction` in `lib/logic/game_engine.dart`)
- **Logic:** When the Bouncer acts (`case 'bouncer'`), the target is flagged.
- **Code:** `if (target.role.id == 'minor') target.minorHasBeenIDd = true;`
- **Effect:** This permanently sets the `minorHasBeenIDd` flag on the player model, removing their immunity to Dealer kills.

### 3. Data Model (`lib/models/player.dart`)
- **Flag:** `bool minorHasBeenIDd` exists and is persisted in JSON.

## Verification
The requested behavior matches the existing code perfectly.
- "Cannot die unless The Bouncer has checked her identity": **implemented**.
- "If Dealers try to kill her before she is I.D.'d, the attempt fails": **implemented**.

## Action Required
None. The code is already correct.
