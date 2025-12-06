#!/bin/bash
# optimize_code.sh - Clean up code quality issues

cd "$(dirname "$0")"

echo "🔧 Optimizing code..."
echo ""

# Step 1: Fix common issues automatically
echo "Step 1/3: Fixing common issues..."
flutter pub run dart fix --apply 2>&1 | grep -v "No fixes available" || echo "  No automatic fixes available"
echo "✅ Automatic fixes applied"

# Step 2: Format all Dart files
echo "Step 2/3: Formatting code..."
dart format lib/ test/ --set-exit-if-changed
if [ $? -eq 0 ]; then
    echo "✅ Code formatted successfully"
else
    echo "⚠️  Some files were reformatted"
fi

# Step 3: Analyze with enhanced rules
echo "Step 3/3: Running enhanced analysis..."
flutter analyze --no-fatal-infos 2>&1 | tee code_analysis.txt | tail -30
echo ""
echo "✅ Code optimization complete!"
echo "📄 Full analysis saved to: code_analysis.txt"

