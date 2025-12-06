#!/bin/bash
# Cleanup previous builds and prepare to run on physical device

echo "🧹 Cleaning up previous builds..."
echo ""

# Stop any running processes
pkill -f "flutter run" 2>/dev/null || true
pkill -f "xcodebuild" 2>/dev/null || true

# Navigate to project
cd /Users/gerardandre/n3rd_game

# Clean Flutter build
echo "1. Cleaning Flutter build..."
flutter clean

# Remove build artifacts
echo "2. Removing build artifacts..."
rm -rf build/
rm -rf ios/Pods/
rm -rf ios/Podfile.lock
rm -rf .dart_tool/flutter_build/

# Clean Xcode DerivedData
echo "3. Cleaning Xcode DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Clean temporary files
echo "4. Cleaning temporary files..."
rm -rf /var/folders/zf/y8sx6ccd0z91l8qb8by0slpc0000gn/T/flutter_tools.* 2>/dev/null || true
rm -rf /var/folders/zf/y8sx6ccd0z91l8qb8by0slpc0000gn/T/*xcresult* 2>/dev/null || true

# Check disk space
echo ""
echo "📊 Current disk space:"
df -h / | tail -1
echo ""

# List available devices
echo "📱 Available devices:"
flutter devices
echo ""

echo "✅ Cleanup complete!"
echo ""
echo "🚀 To run on your physical device, use one of these commands:"
echo ""
echo "   Option 1 (if device shows as 'iPhone' or similar name):"
echo "   flutter run -d iPhone"
echo ""
echo "   Option 2 (using device ID - replace XXXXX with your device ID from above):"
echo "   flutter run -d XXXXX"
echo ""
echo "   Option 3 (run on first connected device):"
echo "   flutter run -d all"
echo ""

