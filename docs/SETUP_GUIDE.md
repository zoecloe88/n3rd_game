# Setup Guide

Complete setup guide for the N3RD Trivia Game project, including Firebase, RevenueCat, API key restrictions, and development environment configuration.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Firebase Setup](#firebase-setup)
3. [API Key Restrictions](#api-key-restrictions)
4. [RevenueCat Setup](#revenuecat-setup)
5. [Development Environment](#development-environment)

---

## Prerequisites

- Flutter SDK 3.10.0 or higher
- Dart SDK 3.10.0 or higher
- Firebase project configured
- RevenueCat account (for subscriptions)
- Access to Firebase Console
- Admin access to your Firebase project
- iOS bundle ID and Android package name

---

## Firebase Setup

### Step 1: Add Firebase Configuration Files

1. **Android:**
   - Download `google-services.json` from Firebase Console
   - Place it in `android/app/`

2. **iOS:**
   - Download `GoogleService-Info.plist` from Firebase Console
   - Place it in `ios/Runner/`

### Step 2: Configure Firebase Services

Enable the following Firebase services:
- Authentication
- Firestore Database
- Analytics
- Crashlytics
- Cloud Messaging
- Storage
- Cloud Functions

### Step 3: Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

### Step 4: Deploy Cloud Functions

```bash
cd functions
npm install
firebase deploy --only functions
```

---

## API Key Restrictions

Firebase API keys are public by design (client-side), but they should be restricted to prevent unauthorized usage. This section provides comprehensive step-by-step instructions to enable API key restrictions in Google Cloud Console.

### Why API Key Restrictions Matter

- **Prevent Abuse**: Restrict API keys to specific apps/platforms
- **Reduce Attack Surface**: Limit which APIs can be called
- **Cost Control**: Prevent unauthorized usage that could incur costs
- **Security Best Practice**: Defense in depth approach
- **Monitor Usage**: Track API usage by application
- **Compliance**: Meet security best practices and compliance requirements

### Prerequisites

- Access to Google Cloud Console
- Firebase project administrator permissions
- iOS app bundle ID (if applicable)
- Android app package name (if applicable)

### Step-by-Step Setup

#### Step 1: Access Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your Firebase project
3. Navigate to **APIs & Services** > **Credentials**

#### Step 2: Identify Your API Keys

1. In the Credentials page, find all API keys (they start with `AIza...`)
2. You should see keys for:
   - iOS app (if configured)
   - Android app (if configured)
   - Web app (if configured)

**Note**: You can also find API keys in:
- iOS: `ios/Runner/GoogleService-Info.plist` - look for `api_key` field
- Android: `android/app/google-services.json` - look for `api_key` field

#### Step 3: Restrict iOS API Key

1. Click on the iOS API key
2. Under **Application restrictions**, select **iOS apps**
3. Click **Add an item**
4. Enter your iOS bundle ID (e.g., `com.clairsaint.wordn3rd`)
5. Click **Save**
6. Under **API restrictions**, select **Restrict key**
7. Select **Firebase APIs** (or specific Firebase services you use):
   - Firebase Installations API
   - Firebase Cloud Messaging API
   - Firebase Remote Config API
   - Identity Toolkit API
   - Cloud Firestore API
   - Firebase Storage API
8. Click **Save**

#### Step 4: Restrict Android API Key

1. Click on the Android API key
2. Under **Application restrictions**, select **Android apps**
3. Click **Add an item**
4. Enter your Android package name (e.g., `com.clairsaint.wordn3rd`)
5. Enter your SHA-1 certificate fingerprint (see "Getting SHA-1 Certificate Fingerprint" below)
6. Click **Save**
7. Under **API restrictions**, select **Restrict key**
8. Select **Firebase APIs** (or specific Firebase services you use):
   - Firebase Installations API
   - Firebase Cloud Messaging API
   - Firebase Remote Config API
   - Identity Toolkit API
   - Cloud Firestore API
   - Firebase Storage API
9. Click **Save**

#### Step 5: Restrict Web API Key (if applicable)

1. Click on the Web API key
2. Under **Application restrictions**, select **HTTP referrers (web sites)**
3. Add your domain(s):
   - `https://yourdomain.com/*`
   - `https://*.yourdomain.com/*`
4. Click **Save**
5. Under **API restrictions**, select **Restrict key**
6. Select **Firebase APIs**
7. Click **Save**

### Getting SHA-1 Certificate Fingerprint

#### For Android Debug Keystore

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

#### For Android Release Keystore

```bash
keytool -list -v -keystore android/app/key.jks -alias your-key-alias
```

Look for the **SHA1** value in the output.

### Verification

#### Manual Verification

1. Go back to **APIs & Services** > **Credentials**
2. Verify each API key shows:
   - ✅ Application restrictions enabled
   - ✅ API restrictions enabled
   - ✅ Correct app/domain restrictions

#### Automated Verification

Run the verification script:

```bash
./scripts/verify_api_restrictions.sh
```

This script checks:
- Configuration files exist
- API keys are present in config files
- Documentation is available

**Note**: The script cannot verify restrictions are enabled in Google Cloud Console. You must verify manually.

#### Testing

- Test your app to ensure it still works correctly
- Monitor API usage in Google Cloud Console
- Check Firebase Console for any errors

### Troubleshooting

#### Issue: API calls failing after restrictions

**Solution**: 
- Verify bundle ID/package name matches exactly
- Check API restrictions include all required Firebase services
- Verify SHA-1 fingerprint is correct (for Android)

#### Issue: Can't find API keys

**Solution**:
- Check `ios/Runner/GoogleService-Info.plist` for iOS API key
- Check `android/app/google-services.json` for Android API key
- Keys are in the `api_key` field

#### Issue: Multiple API keys

**Solution**:
- Each platform (iOS/Android/Web) should have its own key
- Restrict each key separately
- Use the same restrictions for keys used by the same app

### Best Practices

1. **Separate Keys**: Use different API keys for different environments (dev/staging/prod)
2. **Minimal Permissions**: Only enable APIs that are actually used
3. **Regular Review**: Review API key usage monthly in Google Cloud Console
4. **Monitor Usage**: Set up alerts for unusual API key usage
5. **Rotate Keys**: Rotate API keys annually or if compromised

### Monitoring API Key Usage

1. Go to **APIs & Services** > **Dashboard**
2. View API usage metrics
3. Set up alerts for:
   - Unusual traffic spikes
   - Errors from unauthorized sources
   - Cost anomalies

### Security Notes

- API key restrictions are a **first line of defense**
- They do **not** replace Firestore Security Rules
- They do **not** replace authentication
- Always use defense in depth approach
- API keys are still visible in client code (this is expected)

### Checklist

- [ ] iOS API key restricted to iOS app bundle ID
- [ ] Android API key restricted to Android package name with SHA-1
- [ ] Web API key restricted to HTTP referrers (if applicable)
- [ ] All API keys restricted to Firebase APIs only
- [ ] Verified restrictions in Google Cloud Console
- [ ] Tested app functionality after restrictions
- [ ] Documented restrictions in project documentation
- [ ] Set up monitoring for API key usage

### Additional Resources

- [Firebase Security Best Practices](https://firebase.google.com/docs/projects/best-practices)
- [Google Cloud API Key Restrictions](https://cloud.google.com/docs/authentication/api-keys#restricting_apis)
- [Firebase Security Rules](https://firebase.google.com/docs/firestore/security/get-started)

---

## RevenueCat Setup

This guide walks you through setting up RevenueCat subscriptions for the N3RD Game app.

### Part 1: Store Configuration

#### Option A: Test Store (For Development/Testing)

1. **In RevenueCat Dashboard:**
   - Navigate to "Apps & providers" page
   - You'll see the Test Store with API key: `test_nKjKZdchUSWxK0WrEWopRtYXgyK`
   - **Copy this test key** if you want to use it for testing
   - The Test Store allows you to test subscriptions without connecting real app stores

2. **Update launch.json (optional for testing):**
   - Replace `REVENUECAT_API_KEY` in `.vscode/launch.json` with the test key
   - Or keep using production key: `sk_dkIMaGJLgRDTNPq0aHJtDAINRbvWk`

#### Option B: Real Store Setup (For Production)

1. **Click "New app configuration"** button
   - This opens a setup wizard

2. **For iOS (Apple App Store):**
   - Connect your App Store Connect account
   - Authorize RevenueCat to access your apps
   - Select your app: `com.clairsaint.wordn3rd`
   - Configure in-app purchases

3. **For Android (Google Play Store):**
   - Connect your Google Play Console account
   - Authorize RevenueCat to access your apps
   - Select your app
   - Configure in-app purchases

### Part 2: Configure Products

1. **Create Products in RevenueCat:**
   - Navigate to "Products" in RevenueCat Dashboard
   - Create subscription products:
     - Premium Monthly
     - Premium Yearly
     - Family & Friends Monthly
     - Family & Friends Yearly

2. **Map to Store Products:**
   - Link each RevenueCat product to corresponding App Store/Play Store products
   - Set pricing and availability

### Part 3: Update App Configuration

1. **Update API Key:**
   - Copy your RevenueCat API key from Dashboard
   - Update `lib/config/app_config.dart`:
     ```dart
     static const String revenueCatApiKey = 'your-api-key-here';
     ```

2. **Configure Entitlements:**
   - Set up entitlements in RevenueCat Dashboard
   - Map products to entitlements:
     - `premium` - Premium subscription features
     - `family_friends` - Family & Friends features

### Part 4: Testing

1. **Test Subscriptions:**
   - Use RevenueCat test mode
   - Test subscription flows
   - Verify entitlement checks

2. **Monitor:**
   - Check RevenueCat Dashboard for subscription events
   - Verify analytics tracking

---

## Development Environment

### Flutter Setup

1. **Install Flutter:**
   ```bash
   # Follow official Flutter installation guide
   # https://flutter.dev/docs/get-started/install
   ```

2. **Verify Installation:**
   ```bash
   flutter doctor
   ```

3. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

### Environment Variables

Update `lib/config/app_config.dart` with:
- RevenueCat API keys
- Cloud Functions URLs
- Firebase configuration

### Running the App

```bash
# Development
flutter run

# Release build
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

---

## Troubleshooting

### Common Issues

1. **Firebase Not Initialized:**
   - Verify `google-services.json` and `GoogleService-Info.plist` are in correct locations
   - Check Firebase project configuration

2. **API Key Restrictions Too Strict:**
   - Verify bundle ID/package name matches exactly
   - Check SHA-1 fingerprint for Android
   - Allow a few minutes for changes to propagate

3. **RevenueCat Not Working:**
   - Verify API key is correct
   - Check internet connection
   - Ensure products are configured in RevenueCat Dashboard

4. **Build Errors:**
   - Run `flutter clean`
   - Run `flutter pub get`
   - Check Flutter and Dart versions match requirements

---

## Additional Resources

- [Firebase Documentation](https://firebase.google.com/docs)
- [RevenueCat Documentation](https://docs.revenuecat.com/)
- [Flutter Documentation](https://flutter.dev/docs)
- [Project Architecture](./ARCHITECTURE.md)
- [Deployment Guide](./DEPLOYMENT_GUIDE.md)

---

*Last Updated: January 2025*


