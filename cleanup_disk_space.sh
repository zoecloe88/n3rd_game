#!/bin/bash
# Cleanup script to free disk space for Xcode build

echo "🧹 Cleaning up disk space..."
echo ""

# Stop any running builds
echo "Stopping Flutter/Xcode processes..."
pkill -f "flutter run" 2>/dev/null
pkill -f "xcodebuild" 2>/dev/null

# Clean Flutter build
echo "Cleaning Flutter build artifacts..."
cd /Users/gerardandre/n3rd_game
flutter clean 2>/dev/null
rm -rf build ios/Pods ios/Podfile.lock .dart_tool/flutter_build

# Clean Xcode DerivedData (biggest space saver)
echo "Cleaning Xcode DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Clean Xcode caches
echo "Cleaning Xcode caches..."
rm -rf ~/Library/Caches/com.apple.dt.Xcode/*
rm -rf ~/Library/Caches/org.llvm.clang/*

# Show disk space before
echo ""
echo "📊 Disk space BEFORE cleanup:"
df -h / | tail -1

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "📊 Disk space AFTER cleanup:"
df -h / | tail -1

echo ""
echo "💡 Now you can open the project in Xcode:"
echo "   open ios/Runner.xcworkspace"

