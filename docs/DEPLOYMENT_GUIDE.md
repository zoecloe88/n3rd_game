# 🚀 Deployment Guide

Complete guide for deploying N3RD Trivia Game to production and testing environments.

## Table of Contents

- [Quick Start](#quick-start)
- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [iOS Deployment to Firebase App Distribution](#ios-deployment-to-firebase-app-distribution)
- [Android Deployment](#android-deployment)
- [Post-Deployment Verification](#post-deployment-verification)
- [Troubleshooting](#troubleshooting)
- [Monitoring](#monitoring)
- [Rollback Procedures](#rollback-procedures)

---

## Quick Start

### iOS to Firebase App Distribution (Recommended for Testing)

**Prerequisites:**
- Xcode installed and configured
- Code signing certificates set up in Xcode
- Firebase CLI installed: `npm install -g firebase-tools`
- Firebase CLI logged in: `firebase login`

**One-Command Deploy:**
```bash
./deploy_ios_to_firebase.sh
```

The script will:
- Clean and build iOS IPA
- Upload to Firebase App Distribution
- Prompt for tester groups/emails
- Provide distribution links

**Configuration:**
- **Firebase Project**: `wordn3rd-7bd5d`
- **iOS App ID**: `1:68201275359:ios:98246017c23c3fe3dd6e6a`
- **Bundle ID**: `com.clairsaint.wordn3rd`
- **IPA Location**: `build/ios/ipa/n3rd_game.ipa`
- **Current Version**: `1.0.0+2`

---

## Pre-Deployment Checklist

### Code Quality
- [ ] All tests passing (`flutter test`)
- [ ] No linter errors (`flutter analyze`)
- [ ] Code review completed
- [ ] Performance benchmarks met
- [ ] Security audit completed (94/100 ✅)

### Configuration
- [ ] Firebase configuration verified (`google-services.json`, `GoogleService-Info.plist`)
- [ ] API keys configured (RevenueCat, Firebase)
- [ ] Environment variables set correctly
- [ ] Build version numbers updated in `pubspec.yaml`
- [ ] Release notes prepared

### Assets
- [ ] All assets optimized and included
- [ ] App icons generated for all platforms
- [ ] Splash screens configured
- [ ] Legal documents updated (privacy policy, terms of service)

### Firebase
- [ ] Firestore security rules deployed
- [ ] Storage security rules deployed
- [ ] Cloud Functions deployed (if applicable)
- [ ] Firebase Analytics enabled
- [ ] Crashlytics enabled

---

## iOS Deployment to Firebase App Distribution

### Step 1: Configure Code Signing (One-time setup)

```bash
# Open Xcode
open ios/Runner.xcworkspace
```

In Xcode:
1. Click "Runner" project (blue icon) in left sidebar
2. Select "Runner" target
3. Go to "Signing & Capabilities" tab
4. Check ✅ "Automatically manage signing"
5. Select your Apple Developer Team from dropdown
6. Xcode will handle certificates automatically

**If you don't have a team:**
- Sign up at https://developer.apple.com
- Free account works for development/testing
- Paid account ($99/year) needed for App Store distribution

### Step 2: Build and Deploy

**Automatic (Recommended):**
```bash
./deploy_ios_to_firebase.sh
```

**Manual Steps (if script fails):**

1. **Build IPA:**
   ```bash
   flutter clean
   flutter pub get
   flutter build ipa --release
   ```

2. **Upload to Firebase:**
   ```bash
   firebase appdistribution:distribute build/ios/ipa/n3rd_game.ipa \
     --app 1:68201275359:ios:98246017c23c3fe3dd6e6a \
     --groups "testers" \
     --release-notes "Your release notes here"
   ```

### Step 3: Manual Export (if automatic fails)

If `flutter build ipa` fails due to signing:

1. **Build archive:**
   ```bash
   flutter build ipa --release
   # This creates: build/ios/archive/Runner.xcarchive
   ```

2. **Export in Xcode:**
   - Open: `open ios/Runner.xcworkspace`
   - Window → Organizer
   - Select the archive
   - Click "Distribute App"
   - Choose "Ad Hoc" or "Development"
   - Export and save IPA

3. **Upload manually:**
   ```bash
   firebase appdistribution:distribute path/to/your.ipa \
     --app 1:68201275359:ios:98246017c23c3fe3dd6e6a \
     --groups "testers" \
     --release-notes "Testing all features"
   ```

### Adding Testers

#### Option 1: Tester Groups (Recommended)
1. Go to Firebase Console → App Distribution
   - https://console.firebase.google.com/project/wordn3rd-7bd5d/appdistribution
2. Click "Testers & Groups" tab
3. Create a group (e.g., "testers", "qa-team")
4. Add tester emails to the group
5. Use group name in deployment: `--groups "testers"`

#### Option 2: Direct Email
```bash
firebase appdistribution:distribute build/ios/ipa/n3rd_game.ipa \
  --app 1:68201275359:ios:98246017c23c3fe3dd6e6a \
  --testers "tester1@example.com,tester2@example.com" \
  --release-notes "Release notes"
```

### Tester Instructions

After deployment:
1. Testers receive email notification
2. Click "Download" link in email
3. Or install "Firebase App Distribution" app from App Store
4. Open app and sign in with Google account
5. Download and install the app

### Viewing Distributions

Firebase Console:
https://console.firebase.google.com/project/wordn3rd-7bd5d/appdistribution

---

## Android Deployment

### Build Configuration

**Release APK:**
```bash
flutter build apk --release
```

**Release App Bundle (for Play Store):**
```bash
flutter build appbundle --release
```

### Signing

- Keystore configured in `android/key.properties`
- Release signing enabled
- ProGuard rules active

### Requirements
- Minimum SDK: As per Flutter defaults
- Target SDK: Latest
- Java 17 compatibility

### Upload to Google Play Console

1. Go to Google Play Console
2. Select app → Release → Production (or Internal Testing)
3. Create new release
4. Upload `.aab` file from `build/app/outputs/bundle/release/`
5. Fill in release notes
6. Review and roll out

---

## Post-Deployment Verification

### Smoke Tests
- [ ] App launches successfully
- [ ] User can create account/login
- [ ] Game modes work correctly
- [ ] State persistence works
- [ ] Multiplayer features work
- [ ] Subscriptions work (if applicable)

### Performance Checks
- [ ] Check Firebase Analytics for errors
- [ ] Review Crashlytics for crashes
- [ ] Monitor performance metrics
- [ ] Check network reachability tracking

### User Feedback
- [ ] Monitor app store reviews
- [ ] Check support channels
- [ ] Review analytics dashboards

---

## Troubleshooting

### "App Distribution extension not found"
- Enable App Distribution in Firebase Console:
  https://console.firebase.google.com/project/wordn3rd-7bd5d/appdistribution
- Or install manually: `firebase ext:install firebase/appdistribution`

### "Code signing failed" or "No signing certificate found"
This is the most common issue. To fix:

1. **Open Xcode:**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Configure Signing:**
   - Select "Runner" project in left sidebar
   - Select "Runner" target
   - Go to "Signing & Capabilities" tab
   - Check "Automatically manage signing"
   - Select your Apple Developer Team
   - Xcode will automatically create/select certificates

3. **Alternative: Manual Export**
   - After `flutter build ipa` creates archive at `build/ios/archive/Runner.xcarchive`
   - Open Xcode → Window → Organizer
   - Select the archive
   - Click "Distribute App"
   - Choose "Ad Hoc" or "Development"
   - Export IPA manually
   - Use the exported IPA path in deployment script

### "IPA not found"
- Check build output for errors
- Verify Xcode is properly configured
- Try building in Xcode: Product → Archive → Distribute App

### "Upload failed"
- Check internet connection
- Verify Firebase project permissions
- Check IPA file size (should be < 500MB)
- Try uploading via Firebase Console manually

---

## Monitoring

### Firebase Analytics

Monitor these events:
- `game_state_save` - Track save performance
- `game_state_load` - Track load performance
- `trivia_generation` - Track generation latency
- `network_reachability_check` - Track network checks
- `template_initialization` - Track init performance

### Crashlytics

Set up alerts for:
- Crash rate > 1%
- New crash types
- Fatal errors
- ANR (Application Not Responding) events

### Performance Monitoring

Review performance metrics:
- Game state save/load times (should be < 100ms)
- Trivia generation (should be < 500ms)
- Network reachability checks (should be < 1000ms)
- Template initialization (should be < 200ms)

### Key Metrics to Monitor

- **Crash Rate**: Should be < 0.1%
- **ANR Rate**: Should be < 0.05%
- **State Save Failures**: Monitor for spikes
- **Network Reachability**: Check failure rates
- **Template Initialization**: Verify success rate

---

## Rollback Procedures

### iOS Rollback

1. Go to App Store Connect
2. Select previous version
3. Submit for expedited review (if critical)
4. Or wait for standard review process

### Android Rollback

1. Go to Google Play Console
2. Halt current release
3. Promote previous version to production
4. Or create new release with previous build

### Firebase Rollback

If Firestore/Storage rules need rollback:
```bash
firebase deploy --only firestore:rules
firebase deploy --only storage:rules
```

### Code Rollback

```bash
git checkout <previous-release-tag>
flutter clean
flutter pub get
# Follow build procedures above
```

---

## Version Management

Current version: `1.0.0+2`
- Update in `pubspec.yaml` before each deployment
- Version format: `major.minor.patch+buildNumber`

---

## Best Practices

1. **Always test on physical devices** before release
2. **Use staged rollouts** (10% → 50% → 100%)
3. **Monitor metrics** for 24-48 hours after release
4. **Keep previous version** available for quick rollback
5. **Document changes** in release notes
6. **Communicate** with team during deployment
7. **Have rollback plan** ready before deployment

---

## Emergency Procedures

### Critical Bug Found

1. **Immediate**: Halt release if not yet rolled out
2. **Hotfix**: Create hotfix branch from production
3. **Fix**: Implement fix and test thoroughly
4. **Deploy**: Follow deployment procedures
5. **Monitor**: Watch metrics closely after deployment

### Data Issue

1. **Assess**: Determine scope of issue
2. **Notify**: Inform affected users if necessary
3. **Fix**: Implement data migration/fix
4. **Verify**: Confirm fix works
5. **Monitor**: Watch for related issues

### Security Issue

1. **Immediate**: Assess severity and impact
2. **Contain**: Disable affected features if necessary
3. **Fix**: Implement security fix
4. **Deploy**: Expedited deployment
5. **Notify**: Inform users if data compromised
6. **Review**: Conduct post-mortem

---

**Status:** ✅ **READY FOR DEPLOYMENT**

*Last Updated: December 2024*
