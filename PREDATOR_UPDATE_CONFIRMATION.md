# Predator Logic Update

## Overview
The Predator logic has been aligned with the user requirement that the Predator **chooses a target at the moment of being voted out**, restricted specifically to players who voted for them. The previous "Night Mark" ability has been removed as it conflicted with this interactive requirement.

## Changes

### 1. Script Builder (`lib/logic/script_builder.dart`)
- **Removed**: The Predator's night step ("Mark a player") is now commented out/disabled. The Predator does not wake up at night.

### 2. Game Engine (`lib/logic/game_engine.dart`)
- **Night Action**: Disabled the `case 'predator'` logic in `handleScriptAction`.
- **Day Vote**: In `handleDayVote`:
    - `pendingPredatorId` is set to the voted-out Predator.
    - `pendingPredatorEligibleVoterIds` is populated with the list of players who voted for the Predator.
    - `pendingPredatorPreferredTargetId` is explicitly set to `null` (no pre-choice).
- **Cleanup**: Removed usage of `predatorMarkId`.

### 3. Data Model (`lib/models/player.dart`)
- **Reverted**: Removed `exclude predatorMarkId` since it is no longer used.

## Verification Checklist

1. **Role Setup**: exist a Predator in the game.
2. **Night Phase**: Verify Predator does NOT wake up.
3. **Day Phase**:
    - Several players must vote for the Predator.
    - Vote out the Predator.
4. **Trigger**:
    - The Engine signals `hasPendingPredatorRetaliation = true`.
    - The `pendingPredatorEligibleVoterIds` list contains primarily the players who voted for the Predator.
5. **UI Logic (Implied)**:
    - The UI should see this state and present a "Who dies with you?" dialog.
    - Selecting a target calls `completePredatorRetaliation(targetId)`.
    - Verify the target dies (Cause: `predator_retaliation`).
