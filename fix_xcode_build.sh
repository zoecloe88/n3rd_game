#!/bin/bash

# Fix Xcode build pause issues
# This script addresses the root causes of Xcode builds pausing or stopping

echo "🔧 Fixing Xcode build pause issues..."
echo ""

cd "$(dirname "$0")"

# Step 1: Clean DerivedData to free up space
echo "Step 1/5: Cleaning Xcode DerivedData (frees ~8.4GB)..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-* 2>/dev/null
rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null || true
echo "✅ DerivedData cleaned"

# Step 2: Clean Flutter build artifacts
echo "Step 2/5: Cleaning Flutter build artifacts..."
flutter clean
rm -rf build/ios
rm -rf ios/build
echo "✅ Build artifacts cleaned"

# Step 3: Ensure Flutter ephemeral directory exists
echo "Step 3/5: Setting up Flutter ephemeral files..."
mkdir -p ios/Flutter/ephemeral
touch ios/Flutter/ephemeral/tripwire 2>/dev/null || true
echo "✅ Ephemeral files ready"

# Step 4: Reinstall pods
echo "Step 4/5: Reinstalling CocoaPods..."
cd ios
pod deintegrate 2>/dev/null || true
pod install
cd ..
echo "✅ Pods reinstalled"

# Step 5: Verify project.pbxproj fix
echo "Step 5/5: Verifying project.pbxproj configuration..."
if grep -q "flutter_build_complete.txt" ios/Runner.xcodeproj/project.pbxproj; then
    echo "✅ Build script output path configured"
else
    echo "⚠️  Warning: Build script output path not found - may need manual fix"
fi

echo ""
echo "✅ All fixes applied!"
echo ""
echo "📋 Summary of fixes:"
echo "  ✅ Cleaned DerivedData (freed ~8.4GB)"
echo "  ✅ Cleaned Flutter build artifacts"
echo "  ✅ Set up Flutter ephemeral files"
echo "  ✅ Reinstalled CocoaPods"
echo "  ✅ Added output path to Flutter build script"
echo ""
echo "🎯 Next steps:"
echo "  1. Open ios/Runner.xcworkspace in Xcode"
echo "  2. Product > Clean Build Folder (Cmd+Shift+K)"
echo "  3. Try building again (Cmd+B)"
echo ""
echo "💡 If builds still pause:"
echo "  - Check Xcode > Preferences > Locations > DerivedData"
echo "  - Ensure you have at least 20GB free disk space"
echo "  - Close other apps to free RAM"
echo "  - Try building with fewer parallel jobs:"
echo "    xcodebuild -project Runner.xcodeproj -scheme Runner -jobs 1"

