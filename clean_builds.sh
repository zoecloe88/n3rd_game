#!/bin/bash
set -e

echo "🧹 Cleaning old builds..."
echo ""

cd /Users/gerardandre/n3rd_game

# Stop processes
echo "1. Stopping running processes..."
pkill -f "flutter run" 2>/dev/null || true
pkill -f "xcodebuild" 2>/dev/null || true

# Flutter clean
echo "2. Running flutter clean..."
flutter clean

# Remove build directory
echo "3. Removing build directory..."
rm -rf build/

# Remove iOS Pods
echo "4. Removing iOS Pods..."
rm -rf ios/Pods/
rm -rf ios/Podfile.lock

# Remove Xcode DerivedData
echo "5. Removing Xcode DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Remove Xcode Archives (optional, uncomment if you want to remove archived builds)
# echo "6. Removing Xcode Archives..."
# rm -rf ~/Library/Developer/Xcode/Archives/*

# Remove temporary files
echo "6. Cleaning temporary files..."
rm -rf /var/folders/zf/y8sx6ccd0z91l8qb8by0slpc0000gn/T/flutter_tools.* 2>/dev/null || true
rm -rf /var/folders/zf/y8sx6ccd0z91l8qb8by0slpc0000gn/T/*xcresult* 2>/dev/null || true

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "📊 Current disk space:"
df -h / | tail -1
echo ""

