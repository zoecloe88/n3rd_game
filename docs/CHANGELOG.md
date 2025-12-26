# Changelog

All notable changes to the N3RD Trivia Game project will be documented in this file.

## [1.0.0+2] - December 2024

### Security
- Fixed Firestore security rules for family groups - restricted read access to owners and members only
- Added `memberIds` array to FamilyGroup model for efficient Firestore rules checking
- Updated FamilyGroupService to maintain `memberIds` array when members are added/removed
- Fixed GameService provider dependency injection - ensured single instance across all ProxyProviders
- All services (Personalization, Gamification, Analytics, Subscription, GameHistory) now properly wired

### Testing
- Fixed test binding initialization errors by adding `TestWidgetsFlutterBinding.ensureInitialized()`
- Added SharedPreferences mocking to all test files
- Fixed ProviderNotFoundException in title_screen_test.dart by adding MultiProvider with mock services
- Added routes and onUnknownRoute handler to MaterialApp in tests
- All 240+ tests now passing with proper setup

### Documentation
- Consolidated deployment documentation into single comprehensive `docs/DEPLOYMENT_GUIDE.md`
- Consolidated architecture documentation into single comprehensive `docs/ARCHITECTURE.md` with full diagram
- Removed redundant documentation files (DEPLOYMENT_NOTES.md, QUICK_DEPLOY.md, DEPLOYMENT_RUNBOOK.md, BUILD_QUALITY_REPORT.md, GRAPHITE_SETUP.md, GITHUB_SETUP.md, DEPENDENCY_UPGRADE_PLAN.md, TEST_COVERAGE_IMPROVEMENT_PLAN.md)
- Updated README.md with creator attribution (Girard Clairsaint) and current status
- Updated docs/README.md to reflect consolidated structure

## [1.0.0] - 2024

### Added
- Comprehensive localization support (i18n)
- Empty state widgets for all major screens
- Trivia content validation with quality checks
- Network resilience with offline queue service
- Resource management utilities
- Accessibility improvements (tooltips, semantics)
- Design system (colors, typography, spacing)
- Subscription grace period handling
- Comprehensive analytics tracking

### Fixed
- Test suite compilation errors
- Linter warnings
- Memory leaks in timer and subscription management
- Duplicate category validation in TriviaValidator
- Hardcoded strings in instructions screen
- Password validation localization

### Changed
- Updated typography to use bundled fonts with Google Fonts fallback
- Standardized spacing using AppSpacing constants
- Improved error handling patterns
- Enhanced subscription grace period logic

