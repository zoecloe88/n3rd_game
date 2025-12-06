#!/bin/bash
# optimize_project.sh - Comprehensive project optimization

cd "$(dirname "$0")"

echo "🚀 Starting Project Optimization..."
echo ""

# Step 1: Clean all build artifacts
echo "📦 Step 1/7: Cleaning build artifacts..."
flutter clean > /dev/null 2>&1 || true
echo "✅ Build artifacts cleaned"

# Step 2: Analyze and fix Dart code
echo "📝 Step 2/7: Analyzing Dart code..."
flutter analyze --no-fatal-infos 2>&1 | tee analysis_report.txt | tail -20
echo "✅ Code analysis complete (see analysis_report.txt)"

# Step 3: Format code
echo "🎨 Step 3/7: Formatting code..."
dart format lib/ test/ --set-exit-if-changed > /dev/null 2>&1 || true
echo "✅ Code formatted"

# Step 4: Get dependencies
echo "📚 Step 4/7: Updating dependencies..."
flutter pub get > /dev/null 2>&1
echo "✅ Dependencies updated"

# Step 5: Check for outdated dependencies
echo "🔍 Step 5/7: Checking for outdated dependencies..."
flutter pub outdated 2>&1 | head -30
echo "✅ Dependency check complete"

# Step 6: Optimize assets (check sizes)
echo "📊 Step 6/7: Analyzing asset sizes..."
if [ -f "check_app_size.sh" ]; then
    ./check_app_size.sh | head -20
else
    echo "  Assets folder size:"
    du -sh assets/ 2>/dev/null || echo "  No assets folder"
fi
echo "✅ Asset analysis complete"

# Step 7: Show project size summary
echo "📋 Step 7/7: Project size summary..."
echo ""
echo "Project Structure:"
du -sh . 2>/dev/null | head -1
du -sh lib/ 2>/dev/null | head -1
du -sh assets/ 2>/dev/null | head -1 || echo "No assets folder"
du -sh build/ 2>/dev/null | head -1 || echo "No build folder (cleaned)"

echo ""
echo "✅ Optimization complete!"
echo ""
echo "📋 Summary:"
echo "  - Analysis report: analysis_report.txt"
echo "  - Code formatted"
echo "  - Dependencies updated"
echo ""
echo "Next steps:"
echo "  1. Review analysis_report.txt for issues"
echo "  2. Check asset sizes - consider compressing videos if needed"
echo "  3. Review outdated dependencies above"

