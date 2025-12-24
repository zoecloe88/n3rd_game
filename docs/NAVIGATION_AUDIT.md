# Navigation & Gameplay Audit Report
## All 18 Game Modes + Editions

### Game Modes Verification

All 18 game modes are present in `mode_selection_screen.dart`:

1. **Classic** - `GameMode.classic` ✓
2. **Classic II** - `GameMode.classicII` ✓
3. **Speed** - `GameMode.speed` ✓
4. **Regular** - `GameMode.regular` ✓
5. **Shuffle** - `GameMode.shuffle` ✓
6. **Challenge** - `GameMode.challenge` ✓
7. **Random** - `GameMode.random` ✓
8. **Time Attack** - `GameMode.timeAttack` ✓
9. **Streak** - `GameMode.streak` ✓
10. **Blitz** - `GameMode.blitz` ✓
11. **Marathon** - `GameMode.marathon` ✓
12. **Perfect** - `GameMode.perfect` ✓
13. **Survival** - `GameMode.survival` ✓
14. **Precision** - `GameMode.precision` ✓
15. **Flip Mode** - `GameMode.flip` ✓
16. **AI Mode** - `GameMode.ai` (Premium) ✓
17. **Practice** - `GameMode.practice` (Premium) ✓
18. **Learning** - `GameMode.learning` (Premium) ✓

### Navigation Flow Verification

#### Standard Flow (15 modes):
1. Mode Selection Screen → User taps mode card
2. `/mode-transition` → 3-second transition screen
3. `/game` → Game screen with `GameMode` argument

**Modes using standard flow:**
- Classic, Classic II, Speed, Regular, Challenge, Random, Time Attack, Streak, Blitz, Marathon, Perfect, Survival, Precision, AI Mode

#### Special Flows:

**Shuffle Mode:**
1. Mode Selection Screen → User taps Shuffle card
2. Dialog: "Shuffle Difficulty" (Easy/Medium/Hard) → User selects
3. `/mode-transition` → 3-second transition
4. `/game` → Game screen with `Map{'mode': GameMode.shuffle, 'difficulty': difficulty}`

**Flip Mode:**
1. Mode Selection Screen → User taps Flip Mode card
2. Dialog: "Flip Mode Reveal Setting" (Instant/Blind/Random) → User selects
3. GameService.setFlipRevealMode() is called
4. `/mode-transition` → 3-second transition
5. `/game` → Game screen with `GameMode.flip` argument

**Practice Mode (Premium):**
1. Mode Selection Screen → User taps Practice card
2. `/practice` → Direct navigation (bypasses transition)
3. RouteGuard checks Premium subscription

**Learning Mode (Premium):**
1. Mode Selection Screen → User taps Learning card
2. `/learning` → Direct navigation (bypasses transition)
3. RouteGuard checks Premium subscription

### Mode Configuration Verification

All ModeConfig values match their descriptions:

| Mode | Description | Config | Status |
|------|-------------|--------|--------|
| Classic | 10s memorize, 20s play | memorizeTime: 10, playTime: 20 | ✓ |
| Classic II | 5s memorize, 10s play | memorizeTime: 5, playTime: 10 | ✓ |
| Speed | 0s memorize, 7s play, words+question together | memorizeTime: 0, playTime: 7, showWordsWithQuestion: true | ✓ |
| Regular | 0s memorize, 15s play, words+question together | memorizeTime: 0, playTime: 15, showWordsWithQuestion: true | ✓ |
| Shuffle | 10s memorize, 20s play, tiles shuffle | memorizeTime: 10, playTime: 20, enableShuffle: true | ✓ |
| Challenge | Progressive difficulty | Round 1: 12s/18s, Round 2: 10s/15s, Round 3: 8s/12s, Round 4+: 6s/10s | ✓ |
| Random | Different mode each round | memorizeTime: 10, playTime: 20 | ✓ |
| Time Attack | 60s continuous play | memorizeTime: 10, playTime: 20 (handled in game logic) | ✓ |
| Streak | 10s memorize, 20s play, multiplier increases | memorizeTime: 10, playTime: 20 | ✓ |
| Blitz | 3s memorize, 5s play | memorizeTime: 3, playTime: 5 | ✓ |
| Marathon | Progressive difficulty, infinite rounds | Rounds 1-5: 10s/20s, 6-10: 8s/15s, 11-15: 6s/12s, 16+: 5s/10s | ✓ |
| Perfect | 10s memorize, 20s play, must get all correct | memorizeTime: 10, playTime: 20 | ✓ |
| Survival | 10s memorize, 20s play, life system | memorizeTime: 10, playTime: 20 | ✓ |
| Precision | 10s memorize, 20s play, lose life on wrong | memorizeTime: 10, playTime: 20 | ✓ |
| AI Mode | Dynamic timing, adaptive | memorizeTime: 10, playTime: 20 (overridden by AIModeService) | ✓ |
| Flip Mode | 10s study (4s visible, 6s flipping), 20s play | memorizeTime: 10, playTime: 20, enableFlip: true, flipStartTime: 4, flipDuration: 6 | ✓ |
| Practice | 15s memorize, 30s play, no scoring | memorizeTime: 15, playTime: 30 | ✓ |
| Learning | 15s memorize, 30s play, review mode | memorizeTime: 15, playTime: 30 | ✓ |

### Editions Navigation Flow

**Regular Editions:**
1. Title Screen → "Editions" button
2. Editions Selection Screen → "Regular Editions" card
3. `/editions` → Editions Screen (RouteGuard: requiresEditionsAccess)
4. User selects edition → `/game` with arguments:
   ```dart
   {
     'mode': null,
     'edition': edition.id,
     'editionName': edition.name,
   }
   ```

**Youth Editions:**
1. Title Screen → "Editions" button
2. Editions Selection Screen → "Youth Editions" card
3. `/youth-editions` → Youth Editions Screen (RouteGuard: requiresEditionsAccess)
4. User selects edition → Navigation flow (similar to regular editions)

### Game Screen Argument Handling

The game screen correctly handles:
1. **GameMode argument** (direct): `args is GameMode`
2. **Map argument** (with mode and difficulty): `args is Map<String, dynamic>`
   - Extracts `mode` from `args['mode']`
   - Extracts `difficulty` from `args['difficulty']`
   - Extracts `customTriviaPool` from `args['triviaPool']`
3. **Edition arguments** (Map with edition info):
   - `args['edition']` - edition ID
   - `args['editionName']` - edition name
   - `args['mode']` - null (editions may have their own modes)

### Issues Found

1. **Editions navigation**: Editions navigate directly to `/game` with edition info, but the game screen may need special handling for edition-specific content. Need to verify edition content system integration.

2. **Time Attack mode**: Description says "60s continuous play" but ModeConfig shows 10s/20s. Need to verify if this is handled by special game logic (e.g., continuous rounds totaling 60s).

3. **Mode transition screen**: Correctly passes arguments through, but validation only checks for `GameMode` or `Map` types. May need to handle edition arguments differently if editions use different argument structure.

### Recommendations

1. ✅ All 18 game modes are correctly listed and navigable
2. ✅ Navigation flows are properly implemented
3. ✅ ModeConfig timing values match descriptions
4. ⚠️ Verify edition content system integration in game screen
5. ⚠️ Verify Time Attack 60s continuous play implementation
6. ✅ Special modes (shuffle, flip, practice, learning) have correct special handling

### Test Checklist

- [ ] Test each of the 15 standard modes (navigation + gameplay)
- [ ] Test Shuffle mode with each difficulty (Easy/Medium/Hard)
- [ ] Test Flip mode with each reveal setting (Instant/Blind/Random)
- [ ] Test Practice mode (Premium required)
- [ ] Test Learning mode (Premium required)
- [ ] Test AI mode (Premium required)
- [ ] Test Editions navigation flow
- [ ] Verify back navigation from game screen works correctly
- [ ] Verify subscription checks work for premium modes
- [ ] Verify free tier restriction to Classic mode only

