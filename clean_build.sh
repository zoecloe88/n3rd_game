#!/bin/bash

# Complete clean build script for iOS
# This resolves caching issues and ensures a fresh build

echo "🧹 Starting complete iOS build cleanup..."
echo ""

# Navigate to project directory
cd "$(dirname "$0")"

# Step 1: Clean Flutter
echo "Step 1/7: Cleaning Flutter..."
flutter clean

# Step 2: Remove build artifacts
echo "Step 2/7: Removing build directories..."
rm -rf build
rm -rf ios/build
rm -rf android/build

# Step 3: Clean iOS Pods
echo "Step 3/7: Cleaning iOS Pods..."
cd ios
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock

# Step 4: Clean Xcode DerivedData
echo "Step 4/7: Cleaning Xcode DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*

# Step 5: Clean CocoaPods cache (optional - comment out if you want to keep cache)
echo "Step 5/7: Cleaning CocoaPods cache..."
pod cache clean --all 2>/dev/null || echo "  (CocoaPods cache clean skipped - not critical)"

# Step 6: Reinstall dependencies
echo "Step 6/7: Reinstalling dependencies..."
cd ..
flutter pub get
cd ios && export LANG=en_US.UTF-8 && pod install && cd ..

# Step 7: Build
echo "Step 7/7: Building iOS app..."
echo ""
echo "Choose build type:"
echo "  1) Debug build (for testing)"
echo "  2) Release build (for App Store)"
read -p "Enter choice (1 or 2): " choice

if [ "$choice" = "2" ]; then
    echo "Building Release..."
    flutter build ios --release --no-codesign
else
    echo "Building Debug..."
    flutter build ios --debug --no-codesign
fi

echo ""
echo "✅ Clean build complete!"
echo ""
echo "Next steps:"
echo "  - Open ios/Runner.xcworkspace in Xcode"
echo "  - Select your device"
echo "  - Click Run (▶️)"


