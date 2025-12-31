# Accessibility Guide

## Overview

The N3RD Trivia Game is designed with accessibility as a core principle, implementing comprehensive features to ensure the app is usable by everyone, including users with disabilities. The app strives for **WCAG 2.1 AA compliance** and includes features that exceed minimum requirements in many areas.

## Compliance Status

- **WCAG 2.1 Level**: AA (targeting AAA where possible)
- **Screen Reader Support**: ✅ Full support (VoiceOver, TalkBack)
- **Keyboard Navigation**: ✅ Supported
- **High Contrast Mode**: ✅ Implemented
- **Text Scaling**: ✅ Up to 200% (2.0x multiplier)
- **Touch Targets**: ✅ Minimum 48x48px enforced
- **Reduced Motion**: ✅ Full support
- **Extended Time Limits**: ✅ 1.5x multiplier for game timers

## Implemented Features

### 1. High Contrast Mode

High contrast mode provides maximum visual contrast for users with low vision or visual impairments.

**Implementation:**
- `AppColorScheme.highContrast()` factory in `lib/theme/app_colors.dart`
- Pure white text on pure black background (21:1 contrast ratio - WCAG AAA)
- Automatically applied when enabled in `AccessibilityService`
- All UI elements respect high contrast mode

**User Experience:**
- Toggle in Settings → Accessibility
- Instant visual feedback
- Settings persist across app sessions

**Developer Usage:**
```dart
// Automatically uses high contrast if enabled
final colors = AppColors.of(context);

// Manual check
if (accessibilityService.settings.highContrastMode) {
  // Use high contrast colors
}
```

### 2. Reduced Motion Support

Respects user preferences for reduced motion to prevent motion sickness and accommodate vestibular disorders.

**Implementation:**
- Checks `MediaQuery.disableAnimations` (system setting)
- Checks `AccessibilityService.settings.reduceMotion` (app setting)
- Checks `AccessibilityService.settings.disableBackgroundVideos`
- Video backgrounds automatically fall back to static images
- Animations respect reduced motion preferences

**User Experience:**
- System-level reduced motion automatically detected
- App-level setting in Settings → Accessibility
- Video backgrounds replaced with static fallback
- Smooth transitions without jarring animations

**Developer Usage:**
```dart
// Check if motion should be reduced
final mediaQuery = MediaQuery.maybeOf(context);
if (mediaQuery?.disableAnimations ?? false) {
  // Disable animations
}

// Check app-level setting
if (accessibilityService.settings.reduceMotion) {
  // Use static fallback instead of video
}
```

### 3. Font Size Multiplier

Allows users to scale text up to 200% (2.0x) for better readability.

**Implementation:**
- `AccessibilityService.settings.fontSizeMultiplier` (0.8 to 2.0 range)
- Applied globally via `MediaQuery` builder in `main.dart`
- `AccessibilityHelper.getScaledFontSize()` and `getScaledTextStyle()` utilities
- All text automatically scales based on user preference

**User Experience:**
- Slider in Settings → Accessibility
- Range: 80% to 200% of normal size
- Instant visual feedback
- Settings persist across app sessions

**Developer Usage:**
```dart
// Automatic scaling via MediaQuery (recommended)
Text(
  'Hello',
  style: AppTypography.bodyMedium,
  // Automatically scaled by MaterialApp builder
)

// Manual scaling
final scaledSize = AccessibilityHelper.getScaledFontSize(
  context,
  16.0, // Base font size
);

final scaledStyle = AccessibilityHelper.getScaledTextStyle(
  context,
  AppTypography.bodyMedium,
);
```

### 4. Larger Touch Targets

Enforces minimum 48x48px touch targets for easier interaction.

**Implementation:**
- `AccessibilityService.settings.largerTouchTargets` boolean
- `AccessibilityHelper.ensureMinimumTouchTarget()` wrapper
- Automatically applied to all buttons via `AppButton` component
- Navigation items respect larger touch targets

**User Experience:**
- Toggle in Settings → Accessibility
- All interactive elements automatically expand
- Easier tapping for users with motor impairments

**Developer Usage:**
```dart
// Automatic enforcement in AppButton
AppButton.primary(
  label: 'Submit',
  onPressed: () {},
  // Automatically enforces 48x48px minimum
)

// Manual enforcement
AccessibilityHelper.ensureMinimumTouchTarget(
  context,
  IconButton(
    icon: Icon(Icons.add),
    onPressed: () {},
  ),
)
```

### 5. Extended Time Limits

Provides 1.5x multiplier for game timers to accommodate users who need more time.

**Implementation:**
- `AccessibilityService.settings.extendedTimeLimits` boolean
- `GameService.setExtendedTimeMultiplier()` method
- Applied to all game modes via `ModeConfig.getConfig()`
- Affects both memorize time and play time

**User Experience:**
- Toggle in Settings → Accessibility
- Automatically applied to all game modes
- 1.5x multiplier (e.g., 10s → 15s, 20s → 30s)

**Developer Usage:**
```dart
// Automatically set in GameScreen.initState()
final extendedTimeMultiplier =
    accessibilityService.settings.extendedTimeLimits ? 1.5 : 1.0;
gameService.setExtendedTimeMultiplier(extendedTimeMultiplier);

// ModeConfig automatically applies multiplier
final config = ModeConfig.getConfig(
  GameMode.classic,
  extendedTimeMultiplier: gameService.extendedTimeMultiplier,
);
```

### 6. Screen Reader Support

Comprehensive screen reader support with semantic labels on all interactive elements.

**Implementation:**
- `Semantics` widgets on all buttons, text fields, checkboxes, etc.
- `semanticLabel` on images (null for decorative images)
- `excludeSemantics: true` for decorative backgrounds
- `liveRegion: true` for dynamic content announcements
- `AccessibilityHelper` utilities for consistent implementation

**Coverage:**
- ✅ All 49 screens have semantic labels
- ✅ All buttons labeled
- ✅ All text fields labeled with hints
- ✅ All checkboxes labeled
- ✅ Loading indicators labeled
- ✅ PageView announcements via live regions
- ✅ Navigation announcements

**Developer Usage:**
```dart
// Button semantics
Semantics(
  label: 'Submit form',
  button: true,
  child: ElevatedButton(
    onPressed: () {},
    child: Text('Submit'),
  ),
)

// Text field semantics
Semantics(
  label: 'Email address',
  hint: 'Enter your email',
  textField: true,
  child: TextField(
    decoration: InputDecoration(labelText: 'Email'),
  ),
)

// Loading indicator semantics
AccessibilityHelper.loadingSemantics(
  label: 'Loading game data',
  value: '50%',
  child: CircularProgressIndicator(value: 0.5),
)

// Live region for announcements
Semantics(
  liveRegion: true,
  label: 'Page 2 of 5',
  child: PageView(...),
)
```

### 7. Loading Indicator Labels

All loading indicators have semantic labels for screen reader users.

**Implementation:**
- `AccessibilityHelper.loadingSemantics()` utility
- Applied to all `CircularProgressIndicator` instances
- Includes descriptive labels and optional progress values

**Developer Usage:**
```dart
AccessibilityHelper.loadingSemantics(
  label: 'Loading game data',
  value: '${(progress * 100).toInt()}%',
  child: CircularProgressIndicator(value: progress),
)
```

### 8. PageView Announcements

PageView widgets announce page changes to screen readers.

**Implementation:**
- `Semantics(liveRegion: true)` wrapper on PageView
- Dynamic label updates on page change
- Used in `YouthEditionsScreen` and `MainNavigationWrapper`

**Developer Usage:**
```dart
Semantics(
  liveRegion: true,
  label: 'Page ${currentPage + 1} of ${totalPages}',
  child: PageView.builder(
    onPageChanged: (index) {
      setState(() {
        currentPage = index;
        // Label automatically updates via liveRegion
      });
    },
    itemBuilder: (context, index) => ...,
  ),
)
```

### 9. Decorative Image Exclusion

Decorative images are properly excluded from the accessibility tree.

**Implementation:**
- `Semantics(excludeSemantics: true)` on decorative backgrounds
- `semanticLabel: null` on decorative images
- Applied to `BackgroundImageWidget` and `VideoBackgroundWidget`
- Applied to `GlowingLogo` widget

**Developer Usage:**
```dart
// Decorative background
Semantics(
  excludeSemantics: true,
  child: Container(
    decoration: BoxDecoration(
      image: DecorationImage(
        image: AssetImage('assets/decorative.png'),
        semanticLabel: null, // Explicitly no label
      ),
    ),
  ),
)

// Decorative logo
Semantics(
  excludeSemantics: true,
  semanticLabel: null,
  child: Image.asset('assets/logo.png'),
)
```

## AccessibilityService

The `AccessibilityService` manages all accessibility settings with persistence and synchronization.

**Location:** `lib/services/accessibility_service.dart`

**Features:**
- Settings persistence (local + Firestore)
- Change notifications via `ChangeNotifier`
- Convenience methods for individual settings
- Automatic sync across devices (when logged in)

**Usage:**
```dart
// Get service
final accessibilityService = ProviderHelper.safeGet<AccessibilityService>(context, listen: false);

// Access settings
final settings = accessibilityService.settings;
if (settings.highContrastMode) {
  // Use high contrast
}

// Update settings
await accessibilityService.setHighContrastMode(true);
await accessibilityService.setFontSizeMultiplier(1.5);
await accessibilityService.setLargerTouchTargets(true);
await accessibilityService.setExtendedTimeLimits(true);
await accessibilityService.setReducedMotion(true);

// Update multiple settings at once
await accessibilityService.updateSettings(
  settings.copyWith(
    highContrastMode: true,
    fontSizeMultiplier: 1.5,
  ),
);
```

## AccessibilityHelper

Utility class providing common accessibility patterns.

**Location:** `lib/utils/accessibility_helper.dart`

**Methods:**
- `getScaledFontSize()` - Get font size with accessibility multiplier
- `getScaledTextStyle()` - Get text style with accessibility multiplier
- `ensureMinimumTouchTarget()` - Enforce 48x48px minimum touch target
- `loadingSemantics()` - Create semantics for loading indicators
- `buttonSemantics()` - Create semantics for buttons
- `textFieldSemantics()` - Create semantics for text fields

**Usage:**
```dart
// Scaled font size
final fontSize = AccessibilityHelper.getScaledFontSize(context, 16.0);

// Scaled text style
final style = AccessibilityHelper.getScaledTextStyle(
  context,
  AppTypography.bodyMedium,
);

// Minimum touch target
AccessibilityHelper.ensureMinimumTouchTarget(
  context,
  IconButton(icon: Icon(Icons.add), onPressed: () {}),
)

// Loading semantics
AccessibilityHelper.loadingSemantics(
  label: 'Loading',
  child: CircularProgressIndicator(),
)
```

## ContrastValidator

Utility class for calculating and validating color contrast ratios per WCAG 2.1.

**Location:** `lib/utils/contrast_validator.dart`

**Methods:**
- `getRelativeLuminance()` - Calculate relative luminance (WCAG formula)
- `getContrastRatio()` - Calculate contrast ratio between two colors
- `meetsWCAGAA()` - Check if contrast meets AA (4.5:1 for normal text)
- `meetsWCAGAAForLargeText()` - Check if contrast meets AA (3:1 for large text)
- `meetsWCAGAAA()` - Check if contrast meets AAA (7:1 for normal text)
- `meetsWCAGAAAForLargeText()` - Check if contrast meets AAA (4.5:1 for large text)
- `getComplianceLevel()` - Get compliance level ('AAA', 'AA', or 'Fail')
- `validate()` - Comprehensive validation with detailed results

**Usage:**
```dart
// Check contrast ratio
final ratio = ContrastValidator.getContrastRatio(
  Colors.white,
  Colors.black,
); // Returns 21.0 (maximum contrast)

// Check WCAG compliance
final meetsAA = ContrastValidator.meetsWCAGAA(
  Colors.white,
  Colors.black,
); // Returns true

// Comprehensive validation
final result = ContrastValidator.validate(
  Colors.white,
  Colors.black,
  isLargeText: false,
);
print(result.contrastRatio); // 21.0
print(result.complianceLevel); // 'AAA'
print(result.meetsWCAGAA); // true
print(result.meetsWCAGAAA); // true
```

## User Guide

### Enabling Accessibility Features

1. **Open Settings**
   - Navigate to More → Settings

2. **Accessibility Section**
   - Scroll to Accessibility settings

3. **Available Options:**
   - **High Contrast Mode**: Toggle for maximum contrast
   - **Font Size**: Adjust slider (80% to 200%)
   - **Larger Touch Targets**: Toggle for bigger tap areas
   - **Extended Time Limits**: Toggle for 1.5x game timers
   - **Reduce Motion**: Toggle to disable animations
   - **Disable Background Videos**: Toggle to use static backgrounds

4. **Settings Persist**
   - All settings are saved automatically
   - Settings sync across devices (when logged in)

### Testing with Screen Readers

#### iOS (VoiceOver)
1. Enable VoiceOver: Settings → Accessibility → VoiceOver → On
2. Navigate: Swipe right/left to move, double-tap to activate
3. Test all interactive elements
4. Verify labels are descriptive and helpful

#### Android (TalkBack)
1. Enable TalkBack: Settings → Accessibility → TalkBack → On
2. Navigate: Swipe right/left to move, double-tap to activate
3. Test all interactive elements
4. Verify labels are descriptive and helpful

## Developer Guide

### Adding Accessibility to New Components

#### 1. Buttons
```dart
Semantics(
  label: 'Clear description of button action',
  button: true,
  enabled: !isDisabled,
  child: ElevatedButton(
    onPressed: isDisabled ? null : onPressed,
    child: Text('Button Label'),
  ),
)
```

#### 2. Text Fields
```dart
Semantics(
  label: 'Field purpose (e.g., Email address)',
  hint: 'What to enter (e.g., Enter your email)',
  textField: true,
  child: TextField(
    decoration: InputDecoration(
      labelText: 'Email',
      hintText: 'Enter your email',
    ),
  ),
)
```

#### 3. Checkboxes
```dart
Semantics(
  label: 'Checkbox purpose (e.g., Accept terms and conditions)',
  checked: isChecked,
  child: Checkbox(
    value: isChecked,
    onChanged: (value) => setState(() => isChecked = value ?? false),
  ),
)
```

#### 4. Loading Indicators
```dart
AccessibilityHelper.loadingSemantics(
  label: 'What is loading (e.g., Loading game data)',
  value: 'Optional progress (e.g., 50%)',
  child: CircularProgressIndicator(
    value: progress,
  ),
)
```

#### 5. Images
```dart
// Decorative images
Semantics(
  excludeSemantics: true,
  semanticLabel: null,
  child: Image.asset('assets/decorative.png'),
)

// Informative images
Semantics(
  label: 'Description of image content',
  child: Image.asset('assets/informative.png'),
)
```

#### 6. Navigation
```dart
// Tab navigation
Semantics(
  label: 'Tab name (e.g., Home tab)',
  button: true,
  selected: isActive,
  child: GestureDetector(
    onTap: () => onTabTapped(index),
    child: ...,
  ),
)

// PageView with announcements
Semantics(
  liveRegion: true,
  label: 'Page ${currentPage + 1} of ${totalPages}',
  child: PageView.builder(...),
)
```

### Best Practices

1. **Always provide semantic labels** for interactive elements
2. **Use descriptive labels** that explain the action, not just the visual
3. **Exclude decorative images** from accessibility tree
4. **Respect reduced motion** preferences
5. **Test with screen readers** during development
6. **Use AccessibilityHelper** utilities for consistency
7. **Check contrast ratios** for text readability
8. **Enforce minimum touch targets** (48x48px)
9. **Support text scaling** via fontSizeMultiplier
10. **Provide hints** for text fields when helpful

### Testing Checklist

- [ ] All buttons have semantic labels
- [ ] All text fields have labels and hints
- [ ] All checkboxes have labels
- [ ] Loading indicators have labels
- [ ] Decorative images are excluded
- [ ] High contrast mode works correctly
- [ ] Font scaling works (80% to 200%)
- [ ] Touch targets are at least 48x48px
- [ ] Reduced motion is respected
- [ ] Extended time limits work in games
- [ ] Screen reader navigation works
- [ ] Contrast ratios meet WCAG AA (4.5:1 minimum)
- [ ] Keyboard navigation works (if applicable)

## Testing

### Automated Testing

Contrast validation can be tested programmatically:

```dart
test('High contrast mode meets WCAG AAA', () {
  final colors = AppColorScheme.highContrast();
  final result = ContrastValidator.validate(
    colors.primaryText,
    colors.background,
  );
  expect(result.meetsWCAGAAA, true);
  expect(result.contrastRatio, greaterThan(20.0));
});
```

### Manual Testing

1. **Enable VoiceOver/TalkBack** and navigate the app
2. **Enable high contrast mode** and verify all text is readable
3. **Adjust font size** and verify text scales correctly
4. **Enable larger touch targets** and verify buttons are easier to tap
5. **Enable extended time limits** and verify game timers are longer
6. **Enable reduced motion** and verify animations are disabled
7. **Test with keyboard navigation** (if applicable)

## Resources

- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Flutter Accessibility Documentation](https://docs.flutter.dev/accessibility-and-localization/accessibility)
- [Material Design Accessibility](https://material.io/design/usability/accessibility.html)
- [iOS Accessibility Guidelines](https://developer.apple.com/accessibility/)
- [Android Accessibility Guidelines](https://developer.android.com/guide/topics/ui/accessibility)

## Related Documentation

- [Design System](./DESIGN_SYSTEM.md) - Design system including accessibility guidelines
- [Architecture](./ARCHITECTURE.md) - System architecture including AccessibilityService
- [Background Image Investigation](./BACKGROUND_IMAGE_INVESTIGATION.md) - Accessibility improvements for backgrounds

---

**Last Updated:** January 2025  
**Status:** ✅ Launch-Ready - All Phase 1 critical blockers resolved














