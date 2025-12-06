# Deployment Runbook

This document provides step-by-step instructions for deploying the N3RD Game application to production.

## Table of Contents

- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [Build Preparation](#build-preparation)
- [iOS Deployment](#ios-deployment)
- [Android Deployment](#android-deployment)
- [Post-Deployment Verification](#post-deployment-verification)
- [Rollback Procedures](#rollback-procedures)
- [Monitoring](#monitoring)

---

## Pre-Deployment Checklist

### Code Quality

- [ ] All tests passing (`flutter test`)
- [ ] No linter errors (`flutter analyze`)
- [ ] Code review completed
- [ ] Performance benchmarks met
- [ ] Security audit completed

### Configuration

- [ ] Firebase configuration verified (`google-services.json`, `GoogleService-Info.plist`)
- [ ] API keys configured (RevenueCat, Firebase)
- [ ] Environment variables set correctly
- [ ] Build version numbers updated
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

## Build Preparation

### 1. Update Version Numbers

Update version in `pubspec.yaml`:
```yaml
version: 1.0.0+2  # Format: major.minor.patch+buildNumber
```

### 2. Clean Build

```bash
flutter clean
flutter pub get
```

### 3. Verify Dependencies

```bash
flutter pub outdated
flutter pub upgrade --dry-run
```

### 4. Run Tests

```bash
flutter test
```

### 5. Analyze Code

```bash
flutter analyze
```

---

## iOS Deployment

### 1. Configure iOS Build

```bash
cd ios
pod install
cd ..
```

### 2. Update iOS Version

Edit `ios/Runner/Info.plist`:
- Update `CFBundleShortVersionString` (version)
- Update `CFBundleVersion` (build number)

### 3. Build iOS App

**Development Build:**
```bash
flutter build ios --debug
```

**Release Build:**
```bash
flutter build ios --release
```

### 4. Archive in Xcode

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select "Any iOS Device" as target
3. Product → Archive
4. Wait for archive to complete

### 5. Distribute to App Store

1. In Xcode Organizer, select the archive
2. Click "Distribute App"
3. Choose "App Store Connect"
4. Follow distribution wizard
5. Submit for review

### 6. TestFlight (Optional)

1. After upload, go to App Store Connect
2. Select build for TestFlight
3. Add internal/external testers
4. Submit for beta testing

---

## Android Deployment

### 1. Configure Android Build

Verify `android/app/build.gradle.kts`:
- `versionCode` updated
- `versionName` updated
- Signing configuration correct

### 2. Generate Signing Key (First Time Only)

```bash
keytool -genkey -v -keystore ~/n3rd-game-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias n3rd-game
```

### 3. Configure Signing

Create/update `android/key.properties`:
```properties
storePassword=<password>
keyPassword=<password>
keyAlias=n3rd-game
storeFile=<path-to-keystore>
```

### 4. Build Android App

**Debug Build:**
```bash
flutter build apk --debug
```

**Release APK:**
```bash
flutter build apk --release
```

**Release App Bundle (for Play Store):**
```bash
flutter build appbundle --release
```

### 5. Upload to Google Play Console

1. Go to Google Play Console
2. Select app → Release → Production (or Internal Testing)
3. Create new release
4. Upload `.aab` file from `build/app/outputs/bundle/release/`
5. Fill in release notes
6. Review and roll out

---

## Post-Deployment Verification

### 1. Smoke Tests

- [ ] App launches successfully
- [ ] User can create account/login
- [ ] Game modes work correctly
- [ ] State persistence works
- [ ] Multiplayer features work
- [ ] Subscriptions work (if applicable)

### 2. Performance Checks

- [ ] Check Firebase Analytics for errors
- [ ] Review Crashlytics for crashes
- [ ] Monitor performance metrics
- [ ] Check network reachability tracking

### 3. User Feedback

- [ ] Monitor app store reviews
- [ ] Check support channels
- [ ] Review analytics dashboards

### 4. Monitoring

Monitor these key metrics:
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

### Custom Alerts

Set up alerts for:
- Save failure rate > 5%
- Network reachability failure rate > 10%
- Template initialization failure rate > 1%

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

## Best Practices

1. **Always test on physical devices** before release
2. **Use staged rollouts** (10% → 50% → 100%)
3. **Monitor metrics** for 24-48 hours after release
4. **Keep previous version** available for quick rollback
5. **Document changes** in release notes
6. **Communicate** with team during deployment
7. **Have rollback plan** ready before deployment

---

## Support Contacts

- **Development Team**: [team-email]
- **DevOps**: [devops-email]
- **Firebase Support**: Firebase Console
- **App Store Support**: App Store Connect
- **Play Store Support**: Google Play Console

---

## Version History

| Version | Date | Changes | Deployed By |
|---------|------|---------|-------------|
| 1.0.0+2 | TBD | Initial production release | TBD |


