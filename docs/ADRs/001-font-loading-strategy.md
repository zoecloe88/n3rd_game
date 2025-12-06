# ADR-001: Font Loading Strategy

**Status**: Accepted  
**Date**: 2024  
**Deciders**: Development Team

## Context

The application requires custom fonts (Playfair Display, Lora, Inter) for a polished, professional appearance. We needed to decide between:
1. Bundling fonts in the app (increases bundle size, guaranteed offline availability)
2. Using Google Fonts package (smaller bundle, dynamic loading, requires network for first load)

## Decision

We chose to use the Google Fonts package (`google_fonts: ^6.1.0`) as the primary font loading mechanism, with `fontFamilyFallback` in typography definitions to specify Google Fonts as fallback.

### Rationale

- **Bundle Size**: Google Fonts reduces app bundle size significantly
- **Automatic Updates**: Fonts are always up-to-date without app updates
- **Offline Support**: Google Fonts caches fonts after first load, providing excellent offline support
- **Fallback Handling**: Automatic fallback to system fonts if Google Fonts fails

### Implementation

- Typography uses `fontFamilyFallback: ['Playfair Display']` to specify Google Fonts
- `pubspec.yaml` includes commented-out bundled font configuration for optional complete offline support
- Fonts are loaded dynamically via `GoogleFonts` package

## Consequences

### Positive

- Smaller app bundle size
- Fonts stay up-to-date automatically
- Good offline support after initial load
- Flexible - can switch to bundled fonts if needed

### Negative

- First launch requires network connection for font loading
- Slight delay on first font load (cached thereafter)
- Dependency on Google Fonts service availability

### Mitigation

- Fonts are cached after first load, so subsequent launches work offline
- Optional bundled fonts configuration available in `pubspec.yaml` if complete offline support is required
- System fonts provide fallback if Google Fonts unavailable


