# N3RD Trivia Game

A modern, engaging trivia game built with Flutter, featuring multiple game modes, AI-powered custom editions, multiplayer support, and comprehensive analytics.

## 🎯 Current Status

**Build Quality:** 100/100 ✅  
**Security Score:** 94/100 ✅  
**Test Coverage:** 224 tests passing ✅  
**Linter Errors:** 0 ✅  
**Analysis Issues:** 0 ✅

**Status:** Production-Ready

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.10.0 or higher
- Dart SDK 3.10.0 or higher
- Firebase project configured
- RevenueCat account (for subscriptions)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd n3rd_game
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Firebase:
   - Add `google-services.json` (Android) to `android/app/`
   - Add `GoogleService-Info.plist` (iOS) to `ios/Runner/`

4. Configure RevenueCat:
   - Update API keys in `lib/config/app_config.dart`

5. Run the app:
```bash
flutter run
```

## 📖 Documentation

Comprehensive documentation is available in the [`docs/`](./docs/) directory:

- **[Architecture](./docs/ARCHITECTURE.md)** - System architecture and design patterns
- **[Deployment Guide](./docs/DEPLOYMENT_GUIDE.md)** - Production deployment checklist
- **[Security Audit](./docs/SECURITY_AUDIT.md)** - Security assessment and recommendations
- **[Build Quality Report](./docs/BUILD_QUALITY_REPORT.md)** - Comprehensive build quality review

See [`docs/README.md`](./docs/README.md) for complete documentation index.

## ✨ Features

### Core Gameplay
- **18 Game Modes**: Classic, Challenge, Time Attack, Blitz, Marathon, Shuffle, Flip, Random, Perfect, Survival, Precision, Streak, AI Mode, Practice, Learning, and more
- **Trivia Categories**: Wide variety of topics including Science, History, Geography, Sports, Entertainment
- **AI-Powered Editions**: Generate custom trivia on any topic using Google Gemini and Anthropic Claude
- **Offline Mode**: Download trivia packs for offline gameplay

### Multiplayer
- Real-time game rooms
- In-game chat with content moderation
- Global and friends leaderboards
- Friends system

### Premium Features
- Subscription tiers (Free and Premium)
- Grace period for active games
- Advanced analytics and insights
- Practice mode
- Voice recognition and text-to-speech

### Design & UX
- Modern, cohesive UI design
- Unified background system (video and static backgrounds)
- Dark mode support
- Consistent typography system
- Safe navigation with error handling
- Accessibility features
- Internationalization support

## 🏗️ Architecture

### Tech Stack
- **Framework**: Flutter 3.10+
- **State Management**: Provider pattern with ChangeNotifier
- **Backend**: Firebase (Auth, Firestore, Analytics, Crashlytics, Messaging, Storage)
- **Subscriptions**: RevenueCat
- **AI Services**: Google Gemini, Anthropic Claude (via Cloud Functions)

### Project Structure
```
lib/
├── config/          # App configuration and constants
├── data/            # Static data (trivia templates)
├── exceptions/      # Custom exception classes
├── l10n/            # Localization files
├── models/          # Data models
├── screens/         # UI screens (46 files)
├── services/        # Business logic services (59 files)
├── theme/           # Design system (colors, typography)
├── utils/           # Utility functions
└── widgets/         # Reusable widgets (26 files)
```

### Key Services
- **GameService**: Core game logic and state management (supports all 18 game modes)
- **MultiplayerService**: Real-time multiplayer game management
- **SubscriptionService**: Subscription tier management with grace period
- **AnalyticsService**: Event tracking and analytics
- **AIEditionService**: AI-powered trivia generation
- **ChatService**: In-game messaging with content moderation
- **NavigationHelper**: Centralized, safe navigation with error handling

## 🔒 Security

### Client-Side
- Input sanitization to prevent XSS attacks
- Content moderation for user-generated content
- Rate limiting for API calls and user actions
- Secure storage for sensitive data

### Server-Side
- Firestore security rules with defense-in-depth approach
- Cloud Functions authentication and rate limiting
- Content moderation in AI generation
- Server-side validation of all user inputs

## 🧪 Testing

### Run Tests
```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/

# Coverage report
flutter test --coverage
```

### Test Coverage
- 224 tests passing
- Unit tests for services and utilities
- Widget tests for UI components
- Integration tests for key user flows

## 📦 Building

### Android
```bash
# APK
flutter build apk --release

# App Bundle
flutter build appbundle --release
```

### iOS
```bash
# Release build
flutter build ios --release

# Create IPA for Firebase App Distribution
cd ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -archivePath build/Runner.xcarchive archive
xcodebuild -exportArchive -archivePath build/Runner.xcarchive -exportPath build/ios/ipa -exportOptionsPlist ExportOptions.plist
```

### Firebase App Distribution
```bash
firebase appdistribution:distribute ios/build/ios/ipa/n3rd_game.ipa --app <APP_ID>
```

## ⚙️ Configuration

### Environment Variables
Update `lib/config/app_config.dart` with:
- RevenueCat API keys
- Cloud Functions URLs
- Firebase configuration

### Firestore Rules
Deploy security rules:
```bash
firebase deploy --only firestore:rules
```

### Cloud Functions
Deploy Cloud Functions:
```bash
cd functions
npm install
firebase deploy --only functions
```

## 📊 Code Quality

- **Zero linter errors** ✅
- **Zero analysis issues** ✅
- **224 tests passing** ✅
- Follows Flutter/Dart style guide
- Comprehensive error handling
- Proper resource management
- Memory leak prevention (Timer cancellation, proper disposal)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

[Add your license here]

## 🆘 Support

For issues, questions, or contributions, please open an issue on GitHub or contact support.

---

*Built with Flutter • Firebase • RevenueCat*
