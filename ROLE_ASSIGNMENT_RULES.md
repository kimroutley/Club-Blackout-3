# Role Assignment Rules Implementation

## Requirements Implemented

### 1. Required Roles for Game Start
- **At least 1 Dealer** - Game cannot start without a Dealer
- **At least 2 Party Animal alliance members** - Ensures sufficient non-dealer players
- **At least 1 Medic and/or 1 Bouncer** - Core protective roles required

### 2. Multiple Instance Rules
**Roles that can have multiple instances:**
- Dealer
- Party Animal

**All other roles are unique:**
- Only ONE instance allowed in the game at a time
- Examples: Medic, Bouncer, Roofi, Messy Bitch, Silver Fox, etc.

### 3. Role Recycling
- When a unique role character dies, that role becomes available again
- New players joining mid-game can take roles of dead players
- Validation checks `p.isAlive` status when determining availability

## Implementation Details

### Files Created
- `lib/utils/role_validator.dart` - Core validation logic

### Files Modified
- `lib/ui/screens/lobby_screen.dart` - Added validation at multiple points

### Validation Points

#### 1. Game Start Validation
```dart
RoleValidator.validateGameSetup(players)
```
Checks before starting the game:
- At least 1 Dealer
- At least 2 Party Animal alliance members
- At least 1 Medic and/or Bouncer
- Shows error if requirements not met
- Shows warnings for edge cases (e.g., too many dealers)

#### 2. Manual Role Assignment
```dart
RoleValidator.canAssignRole(role, playerId, players)
```
Prevents assigning unique roles that are already taken:
- Filters role dropdown to show only available roles
- Validates before saving role selection
- Shows error message if role is already assigned

#### 3. Add Player with Role
- Validates role availability when adding a new player
- Shows error if selected role is already taken by living player
- Dropdown only shows available roles

### User Experience

**Error Messages:**
- "Game requires at least 1 Dealer."
- "Game requires at least 2 Party Animal alliance members."
- "Game requires at least 1 Medic and/or 1 Bouncer."
- "[Role Name] can only exist once in the game. [Player Name] already has this role."

**Warnings:**
- "Warning: High dealer-to-player ratio may make the game difficult for Party Animals."

**Visual Feedback:**
- Red snackbar for blocking errors (4 seconds)
- Orange snackbar for warnings (3 seconds)
- Role dropdown automatically filters out unavailable roles
- Role selection dialog only shows available roles

## Testing Scenarios

1. **Start game without Dealer** → Error shown
2. **Start game with only 1 non-dealer** → Error shown
3. **Start game without Medic/Bouncer** → Error shown
4. **Try to assign Medic to second player when already assigned** → Filtered from dropdown
5. **Assign multiple Dealers** → Allowed
6. **Assign multiple Party Animals** → Allowed
7. **Player with Medic dies** → Medic becomes available again for new players

## Future Enhancements

- Visual indicators in role selection showing which roles are already taken
- Role count display in lobby (e.g., "Dealers: 2, Party Animals: 5")
- Recommended role distribution based on player count
