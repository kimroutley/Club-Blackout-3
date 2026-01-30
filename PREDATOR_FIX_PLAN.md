# Predator Retaliation Fix

## Problem
The Predator's night mark (`nightActions['predator_mark']`) is cleared at the transition from Night to Day. This means when the Predator is voted out during the Day Phase, `handleDayVote` attempts to retrieve the preferred target but gets `null`, preventing the automatic/preferred retaliation logic from working as intended (forcing a fallback or manual selection without the prompt of who was marked).

## Solution
Persist the Predator's mark on the `Player` object, similar to the Tea Spiller fix.

### 1. Data Model (`lib/models/player.dart`)
- Add `String? predatorMarkId`.

### 2. Game Engine (`lib/logic/game_engine.dart`)
- **Night Action**: In `handleScriptAction` (case `predator`), save target to `sourcePlayer.predatorMarkId`.
- **Day Vote**: In `handleDayVote`, read from `votedOutPlayer.predatorMarkId` (fallback to `nightActions` for legacy/safety).
- **Cleanup**: In `_resetPlayerStateForNewRole`, clear `predatorMarkId`.

## Verification
1. Assign Predator to Player A.
2. Night 1: Predator marks Player B.
3. Day 1: Vote out Player A.
4. Verify that Player A's retaliation prompts (or defaults) to Player B correctly.
