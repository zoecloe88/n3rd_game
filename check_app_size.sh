#!/bin/bash

echo "📱 App Size Breakdown"
echo "===================="
echo ""

# Check if built app exists
if [ -d "build/ios/iphoneos/Runner.app" ]; then
    echo "✅ Built App Size:"
    du -sh build/ios/iphoneos/Runner.app
    echo ""
fi

echo "📦 Source Code & Assets:"
echo "Assets folder:"
du -sh assets 2>/dev/null || echo "No assets folder"
echo ""

echo "Trivia templates:"
du -sh lib/data/trivia_templates_consolidated.dart 2>/dev/null || echo "Not found"
echo ""

echo "Total project size (excluding build):"
du -sh . --exclude=build --exclude=ios/Pods --exclude=ios/.symlinks 2>/dev/null | head -1
echo ""

echo "📊 Asset Breakdown:"
find assets -type f -exec du -h {} + 2>/dev/null | sort -rh | head -10
echo ""

echo "💾 Estimated Final App Size:"
echo "- Debug build: ~85-95 MB"
echo "- Release build: ~40-50 MB (optimized, stripped)"


