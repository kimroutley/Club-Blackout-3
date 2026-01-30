# Seasoned Drinker Implementation Summary

## Changes Made

### 1. Robust Multiple Lives Logic (`lib/models/player.dart`)
- **Correction:** Updated `setLivesBasedOnDealers(count)` to set `lives = 1 + dealerCount`.
  - Previously it was just `dealerCount`, which meant 1 Dealer = 1 Life (0 extra).
  - Now: 1 Dealer = 2 Lives (1 Extra). 2 Dealers = 3 Lives (2 Extra).
  - This ensures they can survive exactly $N$ attacks before dying on the $(N+1)^{th}$.

### 2. UI Display (`lib/ui/widgets/player_tile.dart` & `lib/ui/styles.dart`)
- **Visual Indicator:** Added a dynamic chip to the player tile that appears whenever a player has more than 1 life.
- **Content:** Displays "X LIVES" (e.g., "3 LIVES").
- **Styling:** Added `ClubBlackoutTheme.neonMint` (#98FF98) to match the Seasoned Drinker's branding.
- **Generalization:** This also automatically supports "The Ally Cat" (who has 9 lives), showing "9 LIVES" in their color.

### 3. Initialization (`lib/logic/game_engine.dart`)
- Validated that `_assignRoles` calls `setLivesBasedOnDealers` immediately after role distribution.
- This happens before the game transitions to Night 0 (Setup), satisfying the "confirmed automatically before setup phase" requirement.

## Verification
1. **Setup**: Start a game with **2 Dealers** and **1 Seasoned Drinker**.
2. **Visual Check**: Look at the Seasoned Drinker's tile on the dashboard.
   - **Expected**: A Mint-colored chip saying **"3 LIVES"**.
3. **Gameplay**:
   - Attack Seasoned Drinker (Night 1). -> Log: "Burned a life. Lives left: 2". Chip updates to "2 LIVES".
   - Attack Seasoned Drinker (Night 2). -> Log: "Burned a life. Lives left: 1". Chip disappears (since lives <= 1).
   - Attack Seasoned Drinker (Night 3). -> Dies.
