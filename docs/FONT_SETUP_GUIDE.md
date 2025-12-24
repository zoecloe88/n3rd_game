# Font Setup Guide

## Overview
The N3RD Game uses three custom fonts for optimal typography:
- **Playfair Display** - For headlines and display text
- **Lora** - For body text and subtitles
- **Inter** - For UI elements and labels

## Current Status
Fonts are currently loaded via `google_fonts` package as a fallback. For offline support and better performance, fonts should be bundled with the app.

## Setup Instructions

### Step 1: Download Font Files
Download the following font files from [Google Fonts](https://fonts.google.com/):

#### Playfair Display
- Regular: `PlayfairDisplay-Regular.ttf`
- SemiBold (600): `PlayfairDisplay-SemiBold.ttf`
- Bold (700): `PlayfairDisplay-Bold.ttf`
- Download from: https://fonts.google.com/specimen/Playfair+Display

#### Lora
- Regular: `Lora-Regular.ttf`
- Medium (500): `Lora-Medium.ttf`
- Download from: https://fonts.google.com/specimen/Lora

#### Inter
- Regular: `Inter-Regular.ttf`
- Medium (500): `Inter-Medium.ttf`
- SemiBold (600): `Inter-SemiBold.ttf`
- Download from: https://fonts.google.com/specimen/Inter

### Step 2: Create Fonts Directory
```bash
mkdir -p fonts
```

### Step 3: Place Font Files
Copy all downloaded font files to the `fonts/` directory in the project root:
```
n3rd_game/
  fonts/
    PlayfairDisplay-Regular.ttf
    PlayfairDisplay-SemiBold.ttf
    PlayfairDisplay-Bold.ttf
    Lora-Regular.ttf
    Lora-Medium.ttf
    Inter-Regular.ttf
    Inter-Medium.ttf
    Inter-SemiBold.ttf
```

### Step 4: Uncomment Font Configuration
In `pubspec.yaml`, uncomment the fonts section (lines 122-141):

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

### Step 5: Verify Setup
1. Run `flutter pub get`
2. Run `flutter analyze` to ensure no errors
3. Test the app to verify fonts load correctly

## Benefits of Bundled Fonts
- ✅ Offline support - fonts work without internet
- ✅ Faster loading - no network requests
- ✅ Consistent rendering across devices
- ✅ Better performance - fonts loaded at app start

## Fallback Behavior
If font files are not bundled, the app will automatically use `google_fonts` package to load fonts dynamically. This ensures the app works even if fonts are not yet bundled.

## Notes
- Font files are typically 50-200KB each
- Total font bundle size: ~500-800KB
- Fonts are loaded once at app startup
- `AppTypography` class handles font loading with automatic fallback

