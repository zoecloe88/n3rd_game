#!/bin/bash

# Comprehensive cleanup script - removes all unessential files
# This will free up significant disk space

set -e

echo "🧹 Starting comprehensive cleanup..."
echo ""

cd "$(dirname "$0")"
PROJECT_DIR=$(pwd)

# Track space freed
SPACE_BEFORE=$(df -h . | tail -1 | awk '{print $4}')

echo "📊 Space before cleanup: $SPACE_BEFORE"
echo ""

# ============================================
# 1. Xcode DerivedData (LARGEST CLEANUP)
# ============================================
echo "Step 1/10: Cleaning Xcode DerivedData..."
DERIVED_DATA_SIZE=$(du -sh ~/Library/Developer/Xcode/DerivedData 2>/dev/null | awk '{print $1}' || echo "0B")
echo "  Found: $DERIVED_DATA_SIZE"
rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null || true
echo "  ✅ Cleaned all DerivedData"
echo ""

# ============================================
# 2. Xcode Archives
# ============================================
echo "Step 2/10: Cleaning Xcode Archives..."
ARCHIVES_SIZE=$(du -sh ~/Library/Developer/Xcode/Archives 2>/dev/null | awk '{print $1}' || echo "0B")
echo "  Found: $ARCHIVES_SIZE"
rm -rf ~/Library/Developer/Xcode/Archives/* 2>/dev/null || true
echo "  ✅ Cleaned old archives"
echo ""

# ============================================
# 3. Flutter Build Artifacts
# ============================================
echo "Step 3/10: Cleaning Flutter build artifacts..."
flutter clean 2>/dev/null || true
rm -rf build
rm -rf .dart_tool/build
rm -rf .dart_tool/flutter_build
echo "  ✅ Cleaned Flutter builds"
echo ""

# ============================================
# 4. iOS Build Artifacts
# ============================================
echo "Step 4/10: Cleaning iOS build artifacts..."
rm -rf ios/build
rm -rf ios/.symlinks
rm -rf ios/.flutter-plugins
rm -rf ios/.flutter-plugins-dependencies
rm -rf ios/Flutter/ephemeral
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec
rm -rf ios/Flutter/Generated.xcconfig
rm -rf ios/Flutter/app.flx
rm -rf ios/Flutter/app.zip
rm -rf ios/Flutter/flutter_assets
rm -rf ios/Flutter/flutter_export_environment.sh
rm -rf ios/ServiceDefinitions.json
rm -rf ios/Runner/GeneratedPluginRegistrant.*
find ios -name "*.xcuserstate" -delete 2>/dev/null || true
find ios -name "*.xcuserdatad" -type d -exec rm -rf {} + 2>/dev/null || true
echo "  ✅ Cleaned iOS builds"
echo ""

# ============================================
# 5. Android Build Artifacts
# ============================================
echo "Step 5/10: Cleaning Android build artifacts..."
rm -rf android/build
rm -rf android/app/build
rm -rf android/.gradle
rm -rf android/.idea
rm -rf android/local.properties
find android -name "*.iml" -delete 2>/dev/null || true
echo "  ✅ Cleaned Android builds"
echo ""

# ============================================
# 6. CocoaPods Cache
# ============================================
echo "Step 6/10: Cleaning CocoaPods cache..."
pod cache clean --all 2>/dev/null || true
rm -rf ~/Library/Caches/CocoaPods 2>/dev/null || true
echo "  ✅ Cleaned CocoaPods cache"
echo ""

# ============================================
# 7. System Caches
# ============================================
echo "Step 7/10: Cleaning system caches..."
rm -rf ~/Library/Caches/com.apple.dt.Xcode/* 2>/dev/null || true
rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/* 2>/dev/null || true
rm -rf ~/Library/Developer/Xcode/Products/* 2>/dev/null || true
echo "  ✅ Cleaned Xcode caches"
echo ""

# ============================================
# 8. .DS_Store Files
# ============================================
echo "Step 8/10: Removing .DS_Store files..."
find . -name ".DS_Store" -delete 2>/dev/null || true
echo "  ✅ Removed .DS_Store files"
echo ""

# ============================================
# 9. Temporary Files
# ============================================
echo "Step 9/10: Cleaning temporary files..."
rm -rf /tmp/flutter_* 2>/dev/null || true
rm -rf /tmp/dart_* 2>/dev/null || true
find . -name "*.tmp" -delete 2>/dev/null || true
find . -name "*.log" -not -path "./ios/Pods/*" -not -path "./android/.gradle/*" -delete 2>/dev/null || true
echo "  ✅ Cleaned temporary files"
echo ""

# ============================================
# 10. Reinstall Dependencies (Fresh Start)
# ============================================
echo "Step 10/10: Reinstalling dependencies..."
flutter pub get
cd ios && pod install && cd ..
echo "  ✅ Dependencies reinstalled"
echo ""

# Calculate space freed
SPACE_AFTER=$(df -h . | tail -1 | awk '{print $4}')
echo "📊 Space after cleanup: $SPACE_AFTER"
echo ""
echo "✅ Comprehensive cleanup complete!"
echo ""
echo "💡 Additional cleanup options:"
echo "  - Xcode > Window > Organizer > Archives (delete old archives)"
echo "  - Empty Trash"
echo "  - Clean Downloads folder if needed"
echo "  - Check ~/Library/Developer for other large folders"

