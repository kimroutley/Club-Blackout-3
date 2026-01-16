# Role Implementation Status

## ✅ Fully Implemented Roles

### The Dealer
- ✅ Night kill action (priority 5)
- ✅ Team coordination
- ✅ Script steps generated

### The Whore
- ✅ Wakes with Dealers
- ✅ Deflection setup (Night Step)
- ✅ Vote deflection mechanic (GameEngine & Vote UI)
- ✅ Notification when vote deflected

### The Medic  
- ✅ Binary choice at Night 1 (PROTECT vs REVIVE)
- ✅ Protect action (priority 2)
- ✅ REVIVE implemented via FAB Menu

### The Bouncer
- ✅ ID check action (priority 2)
- ✅ Marks Minor as ID'd (removes death protection)
- ❌ Missing: Can take Roofi powers (challenge mechanic)

### The Messy Bitch
- ✅ Rumor spreading (priority 6)
- ✅ Win condition check
- ✅ Special kill after win condition

### The Roofi
- ✅ Silence/paralyze action (priority 4)
- ❌ Missing: Extended paralyze for Dealers (2 rounds)
- ❌ Missing: Can be challenged by Bouncer

### The Creep
- ✅ Mimic target selection (Night 0)
- ✅ Role inheritance on target death
- ✅ Alliance copying

### Seasoned Drinker
- ✅ Multiple lives (2 lives)

### Ally Cat
- ✅ Nine lives implementation
- ❌ Missing: Can see Bouncer ID checks
- ❌ Missing: "Meow" communication mechanic

### Drama Queen
- ✅ Mark two players during night
- ✅ Swap on death trigger
- ✅ Card viewing on swap

### Tea Spiller
- ✅ Mark player during night
- ✅ Reveal on death

### Predator
- ✅ Mark player during night
- ✅ Retaliation on vote-out

### The Wallflower ✨ NEW
- ✅ Priority 5 (after Dealer kill)
- ✅ Optional eye-opening mechanic during murder phase
- ✅ Script step allowing optional observation
- ✅ Can witness who Dealers targeted

### The Club Manager ✨ NEW
- ✅ Priority 3 (before Roofi)
- ✅ Night vision of player cards
- ✅ Script step to select player and view role
- ✅ Host shows selected player's character card

### The Silver Fox ✨ NEW
- ✅ Priority 1 (early in night)
- ✅ Force role reveal mechanic (one-time use)
- ✅ Script step + tracking for one-time use
- ✅ Queues reveal ability for next day phase

### The Minor ✨ NEW
- ✅ Passive death protection until ID'd
- ✅ Bouncer ID check integration
- ✅ First attack triggers ID'd status (survives)
- ✅ Subsequent attacks kill normally
- ✅ Special logging for Minor protection

### The Sober ✨ NEW
- ✅ Priority 1 (early, before kills)
- ✅ One-time "send home" ability
- ✅ Protection queued with priority 1
- ✅ No murders if Dealer sent home (special logic)
- ✅ Ability usage tracking

---

## ⚠️ Partially Implemented Roles

### The Whore
- Current: Listed in roles.json, no priority (0)
- **Missing**: Vote deflection mechanic (day phase ability)
- **Needs**: Day phase voting system integration

---

## ❌ Not Implemented Roles

### The Clinger
- **Missing**: Partner assignment at game start
- **Missing**: Linked fate (dies when partner dies)
- **Missing**: Death if called "controller"
- **Missing**: Forced vote matching
- **Missing**: UI for raising hand at night start

### The Second Wind
- **Missing**: Conversion mechanic on death
- **Missing**: Dealer vote on conversion
- **Missing**: Alliance swap

---

## 🔧 Required Updates

### Script Builder Changes Needed

1. **Wallflower** - Add optional observation note during Dealer murder phase
2. **Club Manager** - Add nightly card viewing step (priority 4)
3. **Silver Fox** - Add one-time forced reveal step (priority 1)
4. **Sober** - Add "send home" selection at night start
5. **Ally Cat** - Add note during Bouncer ID check
6. **Clinger** - Track partner, enforce vote matching
7. **Lightweight** - Add Host pointing step after each night
8. **Minor** - Integrate with Bouncer ID check protection
9. **Second Wind** - Add conversion choice for Dealers on death
10. **Whore** - Integrate vote deflection into day voting

### Player Model Extensions Needed

```dart
// Additional fields needed
String? clingerPartnerId;
List<String> tabooNames = [];
bool minorHasBeenIDd = false;
bool soberAbilityUsed = false;
bool silverFoxAbilityUsed = false;
bool secondWindConverted = false;
```

### Game Engine Changes Needed

1. **Vote deflection** (Whore) - Modify vote counting
2. **Partner linking** (Clinger) - Auto-death on partner death
3. **Taboo enforcement** (Lightweight) - Manual/verbal tracking
4. **Protected until ID'd** (Minor) - Override kill if not ID'd
5. **Send home** (Sober) - Block night kills
6. **Forced reveal** (Silver Fox) - Show role card for 5 seconds
7. **Conversion vote** (Second Wind) - Dealer group decision
8. **Bouncer challenge** (Bouncer vs Roofi) - Power transfer mechanic

---

## Priority Implementation Order

### High Priority (Core Mechanics)
1. ✅ Wallflower optional observation
2. ✅ Club Manager card viewing
3. ✅ Silver Fox forced reveal
4. ✅ Minor death protection

### Medium Priority (Complex Mechanics)
5. Sober send-home ability
6. Ally Cat seeing Bouncer checks
7. Whore vote deflection
8. Second Wind conversion

### Low Priority (Social/Manual Mechanics)
9. Clinger partner mechanics
10. Lightweight taboo names
11. Bouncer vs Roofi challenge
12. Extended Roofi paralyze for Dealers

---

## Notes

- Some mechanics (like Lightweight's taboo names) are primarily social/manual and may not need full digital implementation
- Clinger mechanics require careful UI/UX design to avoid revealing the role
- Wallflower's "optional" observation is a player choice, not automated
- Many day-phase abilities need voting system updates
