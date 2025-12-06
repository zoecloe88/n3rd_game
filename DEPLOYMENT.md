# Deployment Guide

## Prerequisites

1. Flutter SDK 3.10.0 or higher
2. Firebase CLI installed and authenticated
3. Node.js and npm for Cloud Functions
4. Android Studio / Xcode for platform-specific builds
5. RevenueCat account configured

## Firebase Setup

### 1. Initialize Firebase Project

```bash
firebase login
firebase init
```

Select:
- Firestore
- Functions
- Hosting (optional)

### 2. Configure Firebase Projects

Create three Firebase projects:
- Development (for local testing)
- Staging (for pre-production testing)
- Production (for live app)

### 3. Add Firebase Configuration Files

**Android:**
- Download `google-services.json` from Firebase Console
- Place in `android/app/`

**iOS:**
- Download `GoogleService-Info.plist` from Firebase Console
- Place in `ios/Runner/`

## Cloud Functions Deployment

### 1. Install Dependencies

```bash
cd functions
npm install
```

### 2. Configure Environment Variables

Set environment variables in Firebase Console:
- `GEMINI_API_KEY`: Google Gemini API key
- `ANTHROPIC_API_KEY`: Anthropic Claude API key

### 3. Deploy Functions

```bash
firebase deploy --only functions
```

Or deploy specific function:
```bash
firebase deploy --only functions:generateTrivia
```

## Firestore Security Rules

### 1. Review Rules

Review `firestore.rules` for security compliance.

### 2. Deploy Rules

```bash
firebase deploy --only firestore:rules
```

### 3. Test Rules

Use Firestore emulator for testing:
```bash
firebase emulators:start --only firestore
```

## RevenueCat Configuration

### 1. Configure Products

Set up subscription products in RevenueCat dashboard:
- Premium Monthly
- Premium Yearly

### 2. Update API Keys

Update `lib/config/app_config.dart`:
```dart
static const String revenueCatApiKey = 'your_api_key';
```

## Building for Release

### Android

#### 1. Generate Keystore

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

#### 2. Configure Key Properties

Create `android/key.properties`:
```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=<path-to-keystore>
```

#### 3. Build APK

```bash
flutter build apk --release
```

#### 4. Build App Bundle

```bash
flutter build appbundle --release
```

### iOS

#### 1. Configure Signing

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target
3. Configure signing in "Signing & Capabilities"

#### 2. Build IPA

```bash
flutter build ios --release
```

#### 3. Archive in Xcode

1. Open Xcode
2. Product → Archive
3. Distribute App

## Environment-Specific Builds

### Development

```bash
flutter run --dart-define=ENV=dev
```

### Staging

```bash
flutter build apk --release --dart-define=ENV=staging
```

### Production

```bash
flutter build appbundle --release --dart-define=ENV=prod
```

## Version Management

### Update Version

1. Update `version` in `pubspec.yaml`:
```yaml
version: 1.0.1+3  # version+buildNumber
```

2. For Android, build number is in `android/app/build.gradle`:
```gradle
versionCode 3
versionName "1.0.1"
```

3. For iOS, version is in `ios/Runner/Info.plist`:
```xml
<key>CFBundleShortVersionString</key>
<string>1.0.1</string>
<key>CFBundleVersion</key>
<string>3</string>
```

## Pre-Deployment Checklist

- [ ] All tests passing
- [ ] Code reviewed and approved
- [ ] Version numbers updated
- [ ] Firebase configuration files updated
- [ ] API keys configured correctly
- [ ] Firestore rules deployed
- [ ] Cloud Functions deployed
- [ ] Security audit completed
- [ ] Performance testing completed
- [ ] Accessibility testing completed
- [ ] Documentation updated
- [ ] Release notes prepared

## Post-Deployment

### 1. Monitor Crashlytics

Check Firebase Crashlytics for crashes and errors.

### 2. Monitor Analytics

Review Firebase Analytics for user behavior.

### 3. Monitor Performance

Check app performance metrics in Firebase Performance.

### 4. Monitor RevenueCat

Verify subscription purchases in RevenueCat dashboard.

## Rollback Procedure

### If Critical Issues Found

1. **Immediate**: Disable feature flags if applicable
2. **Short-term**: Release hotfix version
3. **Long-term**: Plan proper fix and release

### Rollback Steps

1. Revert code to previous stable version
2. Update version number
3. Rebuild and redeploy
4. Notify users if necessary

## Continuous Integration

### GitHub Actions (Example)

```yaml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test
      - run: flutter build apk --release
      - run: firebase deploy --only firestore:rules,functions
```

## Troubleshooting

### Common Issues

1. **Build Failures**: Check Flutter version and dependencies
2. **Firebase Errors**: Verify configuration files and API keys
3. **RevenueCat Issues**: Check API keys and product configuration
4. **Signing Errors**: Verify keystore and certificates

### Support

For deployment issues, contact the development team or check:
- Firebase Console
- RevenueCat Dashboard
- Flutter Documentation
- Project README


