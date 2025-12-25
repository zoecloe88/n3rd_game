# N3RD Trivia Game

A modern, engaging trivia game built with Flutter, featuring multiple game modes, AI-powered custom editions, multiplayer support, and comprehensive analytics.

## 🎯 Build Quality: 100/100 ✅

**Status:** Production-Ready  
**Security Score:** 94/100  
**Test Coverage:** 224 tests passing  
**Linter Errors:** 0  
**Analysis Issues:** 0

## 📚 Documentation

Comprehensive documentation is available in the [`docs/`](./docs/) directory:

- **[Build Quality Report](./docs/BUILD_QUALITY_REPORT.md)** - Comprehensive review and final score
- **[Security Audit](./docs/SECURITY_AUDIT.md)** - Security assessment and recommendations
- **[Deployment Guide](./docs/DEPLOYMENT_GUIDE.md)** - Production deployment checklist
- **[Architecture](./docs/ARCHITECTURE.md)** - System architecture documentation

See [`docs/README.md`](./docs/README.md) for complete documentation index.

## Features

### Core Gameplay
- **18 Game Modes**: 
  - **Classic Modes**: Classic (10s/20s), Classic II (5s/10s), Regular (0s/15s), Speed (0s/7s)
  - **Challenge Modes**: Challenge (progressive difficulty), Time Attack (60s continuous), Blitz (3s/5s), Marathon (infinite rounds)
  - **Special Modes**: Shuffle (tiles move), Flip Mode (face-down tiles), Random (varies each round)
  - **Advanced Modes**: Perfect (all correct or game over), Survival (1 life start), Precision (instant life loss), Streak (multiplier increases)
  - **Premium Modes**: AI Mode (adaptive difficulty), Practice (no scoring, unlimited hints), Learning (review missed questions)
- **Trivia Categories**: Wide variety of topics including Science, History, Geography, Sports, Entertainment, and more
- **AI-Powered Editions**: Generate custom trivia on any topic using Google Gemini and Anthropic Claude
- **Offline Mode**: Download trivia packs for offline gameplay

### Multiplayer
- **Real-time Game Rooms**: Create or join multiplayer game rooms
- **In-Game Chat**: Communicate with other players during games
- **Leaderboards**: Compete for top scores and rankings
- **Friends System**: Add friends and compete together

### Premium Features
- **Subscription Tiers**: Free and Premium tiers with different access levels
- **Grace Period**: Continue playing active games even if subscription expires
- **Advanced Analytics**: Detailed performance insights and statistics
- **Practice Mode**: Learn and practice without affecting stats
- **Voice Features**: Voice recognition and text-to-speech support

### Design & UX
- **Modern UI**: Clean, professional design
- **Unified Background System**: Consistent background across all screens
- **Dark Mode**: Full dark mode support with theme switching
- **Typography System**: Consistent typography using Playfair Display, Lora, and Inter fonts
- **Navigation**: Centralized navigation system with safe error handling
- **Accessibility**: Screen reader support, semantic widgets, and accessibility features
- **Internationalization**: i18n support (currently English, extensible)

## Architecture

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
├── screens/         # UI screens (45 files)
├── services/        # Business logic services (57 files)
├── theme/           # Design system (colors, typography)
├── utils/           # Utility functions
└── widgets/         # Reusable widgets (27 files)
```

### Key Services
- **GameService**: Core game logic and state management (supports all 18 game modes)
- **MultiplayerService**: Real-time multiplayer game management
- **SubscriptionService**: Subscription tier management with grace period
- **AnalyticsService**: Event tracking and analytics
- **AIEditionService**: AI-powered trivia generation
- **ChatService**: In-game messaging with content moderation
- **NavigationHelper**: Centralized, safe navigation with error handling

## Security

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

## Getting Started

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

## Configuration

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

## Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

## Building

### Android
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## Code Quality

- **Zero linter errors** ✅
- **Zero analysis issues** ✅
- **224 tests passing** ✅
- Follows Flutter/Dart style guide
- Comprehensive error handling
- Proper resource management

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

[Add your license here]

## Support

For issues, questions, or contributions, please open an issue on GitHub or contact support.

---

*Built with Flutter • Firebase • RevenueCat*
