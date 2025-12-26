# Quick Deploy Guide - iOS to Firebase App Distribution

## Current Status

✅ **Firebase App Distribution**: Ready  
✅ **iOS App Registered**: `1:68201275359:ios:98246017c23c3fe3dd6e6a`  
⚠️ **Code Signing**: Needs configuration in Xcode

## Quick Start

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

### Step 2: Deploy

```bash
./deploy_ios_to_firebase.sh
```

The script will:
- Build the iOS IPA
- Upload to Firebase App Distribution
- Prompt for tester groups/emails
- Provide download links

## Manual Export (if automatic fails)

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

## Adding Testers

### Option 1: Create Tester Group (Recommended)
1. Go to: https://console.firebase.google.com/project/wordn3rd-7bd5d/appdistribution
2. Click "Testers & Groups" tab
3. Click "Create group"
4. Name it (e.g., "testers")
5. Add tester emails
6. Use in deployment: `--groups "testers"`

### Option 2: Direct Email
```bash
--testers "email1@example.com,email2@example.com"
```

## Testing

After deployment:
1. Testers receive email notification
2. Click "Download" link
3. Or install "Firebase App Distribution" app from App Store
4. Sign in and download the app

## Troubleshooting

**"No signing certificate found"**
→ Configure signing in Xcode (see Step 1 above)

**"App Distribution extension not found"**
→ Enable in Firebase Console or run:
```bash
firebase ext:install firebase/appdistribution
```

**"Upload failed"**
→ Check internet connection and Firebase permissions

## View Distributions

Firebase Console:
https://console.firebase.google.com/project/wordn3rd-7bd5d/appdistribution

