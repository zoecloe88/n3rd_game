# iOS Deployment to Firebase App Distribution

## Quick Reference

### Prerequisites
- Xcode installed and configured
- Code signing certificates set up in Xcode
- Firebase CLI installed: `npm install -g firebase-tools`
- Firebase CLI logged in: `firebase login`
- App Distribution extension installed (auto-installed by script)

### Quick Deploy

```bash
./deploy_ios_to_firebase.sh
```

### Manual Steps (if script fails)

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

### Configuration

- **Firebase Project**: `wordn3rd-7bd5d`
- **iOS App ID**: `1:68201275359:ios:98246017c23c3fe3dd6e6a`
- **Bundle ID**: `com.clairsaint.wordn3rd`
- **IPA Location**: `build/ios/ipa/n3rd_game.ipa`

### Adding Testers

#### Option 1: Tester Groups (Recommended)
1. Go to Firebase Console → App Distribution
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

### Troubleshooting

#### "App Distribution extension not found"
- Enable App Distribution in Firebase Console:
  https://console.firebase.google.com/project/wordn3rd-7bd5d/appdistribution
- Or install manually: `firebase ext:install firebase/appdistribution`

#### "Code signing failed" or "No signing certificate found"
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

3. **If you don't have a team:**
   - Sign up at https://developer.apple.com
   - Free account works for development/testing
   - Paid account ($99/year) needed for App Store distribution

4. **Alternative: Manual Export**
   - After `flutter build ipa` creates archive at `build/ios/archive/Runner.xcarchive`
   - Open Xcode → Window → Organizer
   - Select the archive
   - Click "Distribute App"
   - Choose "Ad Hoc" or "Development"
   - Export IPA manually
   - Use the exported IPA path in deployment script

#### "IPA not found"
- Check build output for errors
- Verify Xcode is properly configured
- Try building in Xcode: Product → Archive → Distribute App

#### "Upload failed"
- Check internet connection
- Verify Firebase project permissions
- Check IPA file size (should be < 500MB)
- Try uploading via Firebase Console manually

### Viewing Distributions

Firebase Console:
https://console.firebase.google.com/project/wordn3rd-7bd5d/appdistribution

### Tester Instructions

1. Testers receive email notification
2. Click "Download" link in email
3. Or install Firebase App Distribution app from App Store
4. Open app and sign in with Google account
5. Download and install the app

### Version Management

Current version: `1.0.0+2`
- Update in `pubspec.yaml` before each deployment
- Version format: `major.minor.patch+buildNumber`

