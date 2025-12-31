# N3RD Game Design System

## Overview

This document provides comprehensive guidelines for using the N3RD Game design system. It covers typography, colors, spacing, components, accessibility, responsive design, and RTL support.

## Table of Contents

1. [Typography](#typography)
2. [Colors](#colors)
3. [Spacing](#spacing)
4. [Components](#components)
5. [Accessibility](#accessibility)
6. [Responsive Design](#responsive-design)
7. [RTL Support](#rtl-support)
8. [Theme System](#theme-system)

## Typography

### Font Families

- **Playfair Display**: Headlines and display text
- **Lora**: Body text and serif content
- **Inter**: UI elements, labels, and interface text

### Font Implementation

#### Current Strategy: Google Fonts (Dynamic Loading)

The app uses the `google_fonts` package (^6.1.0) to load fonts dynamically from Google Fonts CDN.

**Benefits:**
- No app size increase
- Always up-to-date font versions
- Works immediately without setup
- Excellent offline support (fonts cached after first load)

**How It Works:**
1. App attempts to use bundled font (if available)
2. If bundled font not found, Flutter automatically falls back to system fonts
3. Google Fonts package loads the font dynamically when needed
4. Font is cached after first load for offline use

#### Optional: Bundled Fonts (For Complete Offline Support)

If you need guaranteed offline support from first launch, you can bundle fonts directly in the app.

**Trade-off:** Increases app size by ~500-800KB

**Setup Steps:**

1. **Download Font Files** from [Google Fonts](https://fonts.google.com/):
   - **Playfair Display**: Regular, SemiBold (600), Bold (700)
   - **Lora**: Regular, Medium (500)
   - **Inter**: Regular, Medium (500), SemiBold (600)

2. **Create Fonts Directory:**
   ```bash
   mkdir -p fonts
   ```

3. **Place Font Files** in the `fonts/` directory in the project root

4. **Uncomment Font Configuration** in `pubspec.yaml`:
   ```yaml
   fonts:
     - family: PlayfairDisplay
       fonts:
         - asset: fonts/PlayfairDisplay-Regular.ttf
         - asset: fonts/PlayfairDisplay-Bold.ttf
           weight: 700
         - asset: fonts/PlayfairDisplay-SemiBold.ttf
           weight: 600
     - family: Lora
       fonts:
         - asset: fonts/Lora-Regular.ttf
         - asset: fonts/Lora-Medium.ttf
           weight: 500
     - family: Inter
       fonts:
         - asset: fonts/Inter-Regular.ttf
         - asset: fonts/Inter-SemiBold.ttf
           weight: 600
         - asset: fonts/Inter-Medium.ttf
           weight: 500
   ```

5. **Verify Setup:**
   - Run `flutter pub get`
   - Run `flutter analyze` to ensure no errors
   - Test the app to verify fonts load correctly

#### AppTypography Class

The `AppTypography` class in `lib/theme/app_typography.dart` handles font loading with automatic fallback. **Always use `AppTypography` instead of hardcoding font families.**

#### Performance Considerations

**Current (Google Fonts Only):**
- **First Load**: ~100-200ms per font family (network request, if not cached)
- **Subsequent Loads**: Instant (cached locally)
- **App Size**: No increase
- **Offline**: Fonts work after first load (cached)

**With Bundled Fonts:**
- **First Load**: Instant (bundled)
- **App Size**: +500-800KB
- **Offline**: Full support from first launch

#### Font Weights

1. **Playfair Display** - Headlines and display text
   - Regular
   - SemiBold (600)
   - Bold (700)

2. **Lora** - Body text and subtitles
   - Regular
   - Medium (500)

3. **Inter** - UI elements and labels
   - Regular
   - Medium (500)
   - SemiBold (600)

### Typography Scale

| Style | Size | Font | Weight | Usage |
|-------|------|------|--------|-------|
| displayLarge | 36px | Playfair Display | Bold | Hero headlines |
| displayMedium | 28px | Playfair Display | Bold | Large headlines |
| headlineLarge | 24px | Playfair Display | Semi-bold | Section headers |
| headlineMedium | 20px | Playfair Display | Semi-bold | Subsection headers |
| titleLarge | 20px | Lora | Medium | Card titles |
| titleMedium | 18px | Lora | Medium | Subtitles |
| titleSmall | 16px | Lora | Medium | Small titles |
| bodyLarge | 16px | Lora | Normal | Body text |
| bodyMedium | 14px | Inter | Normal | Secondary body text |
| bodySmall | 12px | Inter | Normal | Small body text |
| labelLarge | 16px | Inter | Semi-bold | Buttons, labels |
| labelSmall | 12px | Inter | Medium | Small labels |

### Usage Guidelines

- Use `displayLarge/Medium` for hero headlines
- Use `headlineLarge/Medium` for section headers
- Use `titleLarge/Medium/Small` for card titles and subtitles
- Use `bodyLarge/Medium/Small` for body text
- Use `labelLarge/Small` for buttons and labels
- Use special fonts (orbitron, ibmPlexMono, spaceGrotesk) sparingly for special UI elements

### Example

```dart
Text(
  'Welcome to N3RD',
  style: AppTypography.displayLarge,
)

Text(
  'Game Mode Selection',
  style: AppTypography.headlineLarge,
)

Text(
  'Card Title',
  style: AppTypography.titleLarge,
)

Text(
  'Body text content goes here.',
  style: AppTypography.bodyMedium,
)
```

## Colors

### Color System

The color system is theme-aware and automatically adapts to light/dark mode.

### Primary Colors

- **primaryText**: Main text color (near black in light, white in dark)
- **secondaryText**: Secondary text color (dark gray in light, light gray in dark)
- **tertiaryText**: Tertiary text color (medium gray)

### Surface Colors

- **surface**: Main surface color
- **surfaceVariant**: Variant surface color
- **surfaceContainer**: Container surface color
- **cardBackground**: Card background color
- **cardBackgroundAlt**: Alternative card background

### Interactive Colors

- **primaryButton**: Primary button background
- **primaryButtonHover**: Primary button hover state
- **buttonText**: Button text color
- **buttonTextDark**: Dark button text color

### State Colors

- **hover**: Hover state color
- **pressed**: Pressed state color
- **disabled**: Disabled state color
- **disabledText**: Disabled text color
- **focus**: Focus indicator color

### Semantic Colors

- **success**: Success state (green)
- **error**: Error state (red)
- **warning**: Warning state (orange)
- **info**: Info state (blue)

### Accent Colors

- **accent**: Primary accent color
- **accentVariant**: Accent variant
- **accentLight**: Light accent
- **accentDark**: Dark accent

### Border Colors

- **borderLight**: Light border
- **borderMedium**: Medium border
- **borderDark**: Dark border

### Usage

```dart
final colors = AppColors.of(context);

Text(
  'Hello',
  style: TextStyle(color: colors.primaryText),
)

Container(
  color: colors.cardBackground,
  child: ...,
)

ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: colors.primaryButton,
    foregroundColor: colors.buttonText,
  ),
  child: Text('Button'),
)
```

## Spacing

### Spacing Scale

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Tight spacing |
| sm | 8px | Small spacing |
| md | 16px | Medium spacing (default) |
| lg | 24px | Large spacing |
| xl | 32px | Extra large spacing |
| xxl | 48px | 2x large spacing |
| xxxl | 64px | 3x large spacing |

### Usage

```dart
Padding(
  padding: EdgeInsets.all(AppSpacing.md),
  child: ...,
)

SizedBox(height: AppSpacing.lg)

EdgeInsets.symmetric(
  horizontal: AppSpacing.md,
  vertical: AppSpacing.sm,
)
```

## Components

### AppButton

Standardized button component with variants, sizes, and states.

#### Variants

- **primary**: Main action button with filled background
- **secondary**: Secondary action with outlined style
- **tertiary**: Subtle action with minimal styling
- **text**: Text-only button
- **icon**: Icon-only button

#### Sizes

- **small**: Compact button (32px height)
- **medium**: Standard button (44px height, default)
- **large**: Prominent button (56px height)

#### Usage

```dart
AppButton.primary(
  label: 'Submit',
  onPressed: () => _handleSubmit(),
)

AppButton.secondary(
  label: 'Cancel',
  onPressed: () => _handleCancel(),
)

AppButton.icon(
  icon: Icons.add,
  onPressed: () => _handleAdd(),
)
```

### AppCard

Standardized card component with variants.

#### Variants

- **elevated**: Card with shadow elevation
- **outlined**: Card with border outline
- **filled**: Card with filled background

#### Usage

```dart
AppCard.elevated(
  child: Column(
    children: [
      Text('Card Title'),
      Text('Card content'),
    ],
  ),
)

AppCard.outlined(
  onTap: () => _handleTap(),
  child: ...,
)
```

### AppTextField

Standardized text field component with states.

#### States

- **normal**: Default state
- **focused**: When field has focus
- **error**: When validation fails
- **disabled**: When field is disabled

#### Usage

```dart
AppTextField(
  label: 'Email',
  hint: 'Enter your email',
  controller: _emailController,
  onChanged: (value) => _email = value,
  leadingIcon: Icons.email,
)

AppTextField(
  label: 'Password',
  obscureText: true,
  errorText: 'Password is required',
  controller: _passwordController,
)
```

### AppBadge

Badge component for notifications, counts, and status indicators.

#### Variants

- **primary**: Primary badge
- **error**: Error badge
- **success**: Success badge
- **warning**: Warning badge
- **info**: Info badge
- **neutral**: Neutral badge

#### Usage

```dart
AppBadge(
  label: '5',
  variant: AppBadgeVariant.error,
)

AppBadge(
  label: 'New',
  variant: AppBadgeVariant.success,
  size: AppBadgeSize.small,
)
```

### AppChip

Chip component for tags, filters, and selections.

#### Variants

- **filter**: Filter chip
- **outlined**: Outlined chip
- **filled**: Filled chip

#### Usage

```dart
AppChip(
  label: 'Tag',
  onTap: () => _handleTap(),
  selected: _isSelected,
)

AppChip(
  label: 'Filter',
  onDelete: () => _handleDelete(),
  variant: AppChipVariant.outlined,
)
```

## Accessibility

The N3RD Game design system includes comprehensive accessibility features to ensure WCAG 2.1 AA compliance. For a complete accessibility guide, see [ACCESSIBILITY.md](./ACCESSIBILITY.md).

### High Contrast Mode

High contrast mode provides maximum visual contrast (21:1 ratio - WCAG AAA) for users with low vision.

**Implementation:**
- Automatically applied via `AppColors.of(context)` when enabled
- Pure white text on pure black background
- All UI elements respect high contrast mode

```dart
// Automatically uses high contrast if enabled
final colors = AppColors.of(context);

// Manual check (use safe access pattern)
final accessibilityService = ProviderHelper.safeGet<AccessibilityService>(context, listen: false);
if (accessibilityService?.settings.highContrastMode ?? false) {
  // High contrast colors are already applied via AppColors.of(context)
}
```

### Font Size Multiplier

Users can scale text from 80% to 200% for better readability.

**Implementation:**
- Applied globally via `MediaQuery` builder in `main.dart`
- `AccessibilityHelper.getScaledFontSize()` and `getScaledTextStyle()` utilities
- All text automatically scales based on user preference

```dart
// Automatic scaling (recommended - applied globally)
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

### Larger Touch Targets

Enforces minimum 48x48px touch targets for easier interaction.

**Implementation:**
- `AccessibilityHelper.ensureMinimumTouchTarget()` wrapper
- Automatically applied to all buttons via `AppButton` component
- Navigation items respect larger touch targets

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
    onPressed: () => _handleAdd(),
  ),
)
```

### Extended Time Limits

Provides 1.5x multiplier for game timers to accommodate users who need more time.

**Implementation:**
- `AccessibilityService.settings.extendedTimeLimits` boolean
- Applied to all game modes via `ModeConfig.getConfig()`
- Affects both memorize time and play time

```dart
// Automatically set in GameScreen
final extendedTimeMultiplier =
    accessibilityService.settings.extendedTimeLimits ? 1.5 : 1.0;
gameService.setExtendedTimeMultiplier(extendedTimeMultiplier);

// ModeConfig automatically applies multiplier
final config = ModeConfig.getConfig(
  GameMode.classic,
  extendedTimeMultiplier: gameService.extendedTimeMultiplier,
);
```

### Semantics

All interactive elements should have proper Semantics widgets for screen reader support.

#### Usage

```dart
// Button semantics
Semantics(
  label: 'Submit form',
  button: true,
  child: AppButton.primary(
    label: 'Submit',
    onPressed: () => _handleSubmit(),
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

### Reduced Motion

Respects user preferences for reduced motion to prevent motion sickness.

**Implementation:**
- Checks `MediaQuery.disableAnimations` (system setting)
- Checks `AccessibilityService.settings.reduceMotion` (app setting)
- Video backgrounds automatically fall back to static images

```dart
// Check if motion should be reduced
final mediaQuery = MediaQuery.maybeOf(context);
if (mediaQuery?.disableAnimations ?? false) {
  // Disable animations
}

// Check app-level setting (use safe access pattern)
final accessibilityService = ProviderHelper.safeGet<AccessibilityService>(context, listen: false);
if (accessibilityService?.settings.reduceMotion ?? false) {
  // Use static fallback instead of video
}
```

### Focus Management

Use focus management for keyboard navigation.

```dart
FocusNode _focusNode = FocusNode();

AccessibilityHelper.withFocusIndicator(
  focusNode: _focusNode,
  child: AppTextField(
    focusNode: _focusNode,
    label: 'Email',
  ),
)
```

### Contrast Validation

Use `ContrastValidator` to ensure text meets WCAG contrast requirements.

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
print(result.complianceLevel); // 'AAA'
```

### Decorative Images

Decorative images should be excluded from the accessibility tree.

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

### AccessibilityService

The `AccessibilityService` manages all accessibility settings with persistence.

```dart
// Get service (use safe access pattern)
final accessibilityService = ProviderHelper.safeGet<AccessibilityService>(context, listen: false);

// Access settings (with null check)
if (accessibilityService != null) {
  final settings = accessibilityService.settings;
  if (settings.highContrastMode) {
    // Use high contrast
  }
}

// Update settings
await accessibilityService.setHighContrastMode(true);
await accessibilityService.setFontSizeMultiplier(1.5);
await accessibilityService.setLargerTouchTargets(true);
await accessibilityService.setExtendedTimeLimits(true);
await accessibilityService.setReducedMotion(true);
```

For comprehensive accessibility documentation, see [ACCESSIBILITY.md](./ACCESSIBILITY.md).

## Responsive Design

### Breakpoints

- **Small Phone**: < 360px
- **Large Phone**: 360-600px
- **Tablet**: 600-840px
- **Large Tablet**: > 840px

### Usage

```dart
if (ResponsiveHelper.isTablet(context)) {
  // Tablet layout
} else {
  // Phone layout
}

// Responsive font size
Text(
  'Hello',
  style: AppTypography.headlineLarge.copyWith(
    fontSize: ResponsiveHelper.responsiveFontSize(
      context,
      baseSize: 24,
      minSize: 20,
      maxSize: 32,
    ),
  ),
)

// Responsive spacing
Padding(
  padding: ResponsiveHelper.responsivePadding(
    context,
    all: 16,
  ),
  child: ...,
)
```

## RTL Support

### Text Direction

Use `EdgeInsetsDirectional` instead of `EdgeInsets` for RTL support.

```dart
Padding(
  padding: EdgeInsetsDirectional.only(
    start: AppSpacing.md,
    end: AppSpacing.sm,
  ),
  child: ...,
)
```

### Icon Mirroring

Mirror icons for RTL languages.

```dart
RTLHelper.mirrorIcon(
  Icon(Icons.arrow_back),
  context,
)
```

### RTL Helpers

```dart
// Check if RTL
if (RTLHelper.isRTLFromContext(context)) {
  // RTL-specific logic
}

// Get text direction
final direction = RTLHelper.getTextDirectionFromContext(context);
```

## Theme System

### AppTheme Integration

The app supports multiple themes with custom color palettes.

### Usage

```dart
// Get current theme
final theme = themeService.currentTheme;

// Set theme
await themeService.setTheme(selectedTheme);

// Toggle dark mode
await themeService.toggleDarkMode();
```

### Theme Colors

Themes define custom colors that are applied to the Material Theme:

- **primary**: Primary theme color
- **secondary**: Secondary theme color
- **accent**: Accent theme color

## Best Practices

1. **Always use design tokens**: Never hardcode colors, spacing, or typography
2. **Always use AppTypography**: Never hardcode font families - use `AppTypography` for all text styles
3. **Use standardized components**: Prefer AppButton, AppCard, AppTextField over raw Material widgets
4. **Ensure accessibility**: Add Semantics to all interactive elements
5. **Support text scaling**: Use responsive typography helpers
6. **Test on multiple devices**: Verify responsive design on different screen sizes
7. **Test offline**: Verify fonts work without network (especially for Google Fonts)
8. **Support RTL**: Use EdgeInsetsDirectional and mirror icons
9. **Follow theme system**: Use AppColors.of(context) for theme-aware colors
10. **Monitor font loading**: Use analytics to track font load failures

## Typography Troubleshooting

### Fonts Not Loading
- Check network connection (for Google Fonts on first load)
- Verify `google_fonts` package is installed
- Check Flutter console for font loading errors
- Verify fonts directory exists (if using bundled fonts)

### Fonts Look Different
- Verify font weights match between bundled and Google Fonts
- Check `fontFamilyFallback` is set correctly
- Test on different devices

## Related Documentation

- See [ADR-001: Font Loading Strategy](./ADRs/001-font-loading-strategy.md) for architectural decision details

## Component Showcase

See the component showcase screen for live examples of all components.

