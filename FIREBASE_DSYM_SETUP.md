# Firebase Crashlytics dSYM Upload Setup

## Issue
Firebase Crashlytics detected a missing dSYM for version 1.0.0 (2).
- **dSYM UUID**: `EFF72DCB-1692-3C52-9E90-2BFF872975B4`

## Solution
Add an automatic dSYM upload script to your Xcode build process.

## Quick Fix (Manual - Recommended)

1. **Open Xcode:**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Add Build Script Phase:**
   - Select the **Runner** target in the project navigator
   - Go to the **Build Phases** tab
   - Click the **+** button at the top
   - Select **New Run Script Phase**

3. **Configure the Script:**
   - **Name**: `Upload dSYM to Firebase Crashlytics`
   - **Shell**: `/bin/sh`
   - **Script**: Add this line:
     ```bash
     "${SRCROOT}/upload_dsym.sh"
     ```
   - **Input Files**: Leave empty
   - **Output Files**: Leave empty
   - **Uncheck**: "For install builds only" (so it runs for all builds)

4. **Position the Script:**
   - Drag the new script phase to run **AFTER** "Embed Frameworks"
   - It should be one of the last build phases

5. **Save and Build:**
   - Save the project (Cmd+S)
   - Build the app (Cmd+B)
   - The dSYM will be automatically uploaded to Firebase

## Automated Script

A script has been created at `ios/upload_dsym.sh` that will:
- Automatically find the Firebase Crashlytics upload-symbols script
- Locate your GoogleService-Info.plist
- Upload the dSYM file after each build

## Verification

After building, check Firebase Console:
1. Go to Firebase Console → Crashlytics
2. Check if the dSYM warning is gone
3. Future builds will automatically upload dSYMs

## For Current Missing dSYM

If you need to upload the dSYM for the current build:

1. **Find your dSYM file:**
   ```bash
   find ~/Library/Developer/Xcode/Archives -name "*.dSYM" -type d | grep -i wordn3rd
   ```

2. **Upload manually:**
   ```bash
   "${PODS_ROOT}/FirebaseCrashlytics/upload-symbols" \
     -gsp "ios/Runner/GoogleService-Info.plist" \
     -p ios \
     "/path/to/your/app.dSYM"
   ```

## Notes

- dSYMs are only generated for **Release** and **Profile** builds
- Debug builds don't generate dSYMs (they're not needed)
- The script will skip upload if files are missing (non-fatal)

