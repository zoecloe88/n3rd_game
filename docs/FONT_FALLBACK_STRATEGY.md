# Font Fallback Strategy

## Overview
The N3RD Game uses a dual-strategy approach for font loading to ensure optimal performance and reliability.

## Current Implementation

### Primary Strategy: Google Fonts (Dynamic Loading)
- **Package**: `google_fonts` (^6.1.0)
- **Method**: Fonts are loaded dynamically from Google Fonts CDN
- **Benefits**:
  - No app size increase
  - Always up-to-date font versions
  - Works immediately without setup

### Fallback Strategy: Bundled Fonts (Future Enhancement)
- **Status**: Font configuration is prepared but commented out in `pubspec.yaml`
- **Location**: `fonts/` directory (to be created)
- **Benefits**:
  - Offline support
  - Faster initial load
  - Consistent rendering

## Font Families Used

1. **Playfair Display** - Headlines and display text
   - Weights: Regular, SemiBold (600), Bold (700)
   
2. **Lora** - Body text and subtitles
   - Weights: Regular, Medium (500)
   
3. **Inter** - UI elements and labels
   - Weights: Regular, Medium (500), SemiBold (600)

## Implementation Details

### AppTypography Class
The `AppTypography` class in `lib/theme/app_typography.dart` handles font loading with automatic fallback:

```dart
static TextStyle _getTextStyle({
  required String fontFamily,
  // ...
}) {
  return TextStyle(
    fontFamily: fontFamily,
    // ...
  ).copyWith(
    fontFamilyFallback: ['Playfair Display'], // Google Fonts fallback
  );
}
```

### How It Works
1. App attempts to use bundled font (if available)
2. If bundled font not found, Flutter automatically falls back to `fontFamilyFallback`
3. Google Fonts package loads the font dynamically
4. Font is cached after first load

## Performance Considerations

### Current (Google Fonts Only)
- **First Load**: ~100-200ms per font family (network request)
- **Subsequent Loads**: Instant (cached)
- **App Size**: No increase
- **Offline**: Fonts may not load if not cached

### Future (Bundled Fonts)
- **First Load**: Instant (bundled)
- **App Size**: +500-800KB
- **Offline**: Full support

## Migration Path

When ready to bundle fonts:

1. Download font files from Google Fonts
2. Place in `fonts/` directory
3. Uncomment font configuration in `pubspec.yaml` (lines 122-141)
4. Run `flutter pub get`
5. Test app to verify fonts load correctly

See `FONT_SETUP_GUIDE.md` for detailed instructions.

## Best Practices

1. **Always use AppTypography** - Never hardcode font families
2. **Test offline** - Verify fonts work without network
3. **Monitor font loading** - Use analytics to track font load failures
4. **Consider user preferences** - Some users may prefer system fonts

## Troubleshooting

### Fonts not loading
- Check network connection (for Google Fonts)
- Verify `google_fonts` package is installed
- Check Flutter console for font loading errors

### Fonts look different
- Verify font weights match between bundled and Google Fonts
- Check `fontFamilyFallback` is set correctly
- Test on different devices

## Future Enhancements

1. **Font preloading** - Load fonts during app initialization
2. **Font subsetting** - Include only used characters to reduce size
3. **User font preferences** - Allow users to choose font size/style
4. **Accessibility fonts** - Support for high-contrast or dyslexia-friendly fonts

