#!/bin/bash

# Deploy iOS App to Firebase App Distribution
# This script builds the iOS IPA and uploads it to Firebase App Distribution

set -e

# Configuration
FIREBASE_PROJECT="wordn3rd-7bd5d"
IOS_APP_ID="1:68201275359:ios:98246017c23c3fe3dd6e6a"
BUNDLE_ID="com.clairsaint.wordn3rd"
VERSION="1.0.0+2"
IPA_PATH="build/ios/ipa/n3rd_game.ipa"

echo "🚀 Deploying iOS App to Firebase App Distribution"
echo "=================================================="
echo "Project: $FIREBASE_PROJECT"
echo "App ID: $IOS_APP_ID"
echo "Bundle ID: $BUNDLE_ID"
echo "Version: $VERSION"
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter."
    exit 1
fi
echo "✅ Flutter found: $(flutter --version | head -1)"

# Check Firebase CLI
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Installing..."
    npm install -g firebase-tools
fi
echo "✅ Firebase CLI found: $(firebase --version)"

# Check if logged in
if ! firebase projects:list &> /dev/null; then
    echo "🔐 Not logged in to Firebase. Please log in:"
    firebase login
fi
echo "✅ Logged in to Firebase"

# Check App Distribution extension
if ! firebase appdistribution:distribute --help &> /dev/null; then
    echo "⚠️  App Distribution extension not found. Installing..."
    firebase ext:install firebase/appdistribution --project=$FIREBASE_PROJECT || {
        echo "❌ Failed to install App Distribution extension"
        echo "💡 You may need to enable it in Firebase Console:"
        echo "   https://console.firebase.google.com/project/$FIREBASE_PROJECT/appdistribution"
        exit 1
    }
fi
echo "✅ App Distribution extension available"

# Check Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode not found. Please install Xcode from the App Store."
    exit 1
fi
echo "✅ Xcode found: $(xcodebuild -version | head -1)"

echo ""
echo "🔨 Building iOS Release IPA..."
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build IPA
echo "🏗️  Building iOS IPA (this may take several minutes)..."
if flutter build ipa --release 2>&1 | tee /tmp/flutter_build.log; then
    BUILD_SUCCESS=true
else
    BUILD_SUCCESS=false
    # Check if archive was created even if IPA export failed
    if [ -d "build/ios/archive/Runner.xcarchive" ]; then
        echo "⚠️  IPA export failed, but archive was created."
        echo "💡 This usually means code signing needs to be configured."
        echo ""
        echo "📦 Archive location: build/ios/archive/Runner.xcarchive"
        echo ""
        echo "To export IPA manually:"
        echo "1. Open Xcode: open ios/Runner.xcworkspace"
        echo "2. Product → Archive (if not already done)"
        echo "3. Window → Organizer → Distribute App"
        echo "4. Choose 'Ad Hoc' or 'Development'"
        echo "5. Export and save IPA"
        echo "6. Then run this script again with the IPA path"
        echo ""
        read -p "Do you want to open Xcode to export the IPA manually? (y/n): " OPEN_XCODE
        if [ "$OPEN_XCODE" = "y" ] || [ "$OPEN_XCODE" = "Y" ]; then
            open ios/Runner.xcworkspace
            echo ""
            echo "After exporting the IPA, update IPA_PATH in this script or provide the path:"
            read -p "Enter path to IPA file (or press Enter to exit): " MANUAL_IPA
            if [ -n "$MANUAL_IPA" ] && [ -f "$MANUAL_IPA" ]; then
                IPA_PATH="$MANUAL_IPA"
                BUILD_SUCCESS=true
            else
                echo "❌ IPA file not found. Exiting."
                exit 1
            fi
        else
            exit 1
        fi
    else
        echo "❌ Build failed. Check the output above for errors."
        exit 1
    fi
fi

# Verify IPA exists
if [ ! -f "$IPA_PATH" ]; then
    echo "❌ IPA file not found at: $IPA_PATH"
    echo "💡 Build may have failed. Check the output above for errors."
    exit 1
fi

IPA_SIZE=$(du -h "$IPA_PATH" | cut -f1)
echo "✅ IPA ready: $IPA_PATH ($IPA_SIZE)"

echo ""
echo "📤 Uploading to Firebase App Distribution..."
echo ""

# Generate release notes
RELEASE_NOTES="N3RD Trivia v$VERSION

Features:
- Complete game history tracking
- All game modes functional
- Multiplayer support
- Subscription management
- Analytics dashboard
- Performance insights

Please test all features and report any issues."

# Upload to Firebase App Distribution
echo "📝 Release notes:"
echo "$RELEASE_NOTES"
echo ""

# Prompt for tester groups/emails
echo "👥 Tester Configuration:"
echo "   You can distribute to:"
echo "   1. Tester groups (e.g., 'testers', 'qa-team')"
echo "   2. Email addresses (comma-separated)"
echo "   3. Both"
echo ""
read -p "Enter tester groups (leave empty to skip): " TESTER_GROUPS
read -p "Enter tester emails (comma-separated, leave empty to skip): " TESTER_EMAILS

# Build distribution command
DIST_CMD="firebase appdistribution:distribute \"$IPA_PATH\" --app \"$IOS_APP_ID\" --project \"$FIREBASE_PROJECT\""

if [ -n "$TESTER_GROUPS" ]; then
    DIST_CMD="$DIST_CMD --groups \"$TESTER_GROUPS\""
fi

if [ -n "$TESTER_EMAILS" ]; then
    DIST_CMD="$DIST_CMD --testers \"$TESTER_EMAILS\""
fi

DIST_CMD="$DIST_CMD --release-notes \"$RELEASE_NOTES\""

# Execute distribution
echo ""
echo "🚀 Uploading to Firebase App Distribution..."
eval $DIST_CMD

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Successfully deployed to Firebase App Distribution!"
    echo ""
    echo "📱 Next steps:"
    echo "   1. Testers will receive an email notification"
    echo "   2. Testers can install via:"
    echo "      - Firebase App Distribution app (iOS)"
    echo "      - Direct download link from email"
    echo "   3. View distribution in Firebase Console:"
    echo "      https://console.firebase.google.com/project/$FIREBASE_PROJECT/appdistribution"
    echo ""
else
    echo ""
    echo "❌ Failed to upload to Firebase App Distribution"
    echo "💡 Check the error message above for details"
    exit 1
fi

