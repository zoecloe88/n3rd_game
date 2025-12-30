#!/bin/bash

# Code complexity analysis script
# Calculates cyclomatic complexity and identifies complex methods
# Usage: ./scripts/analyze_complexity.sh

set -e

echo "🔍 Analyzing code complexity..."
echo ""

# Check if dart is available
if ! command -v dart &> /dev/null; then
    echo "❌ Dart SDK not found. Please install Flutter/Dart SDK."
    exit 1
fi

# Run dart analyze for complexity hints
echo "1. Running Dart analyzer..."
dart analyze --no-fatal-infos lib/ 2>&1 | grep -E "complexity|cyclomatic" || echo "   No complexity warnings found"

# Count lines of code per file
echo ""
echo "2. Analyzing file sizes..."
echo "=========================="

find lib/ -name "*.dart" -type f | while read -r file; do
    lines=$(wc -l < "$file" 2>/dev/null || echo "0")
    if [ "$lines" -gt 2000 ]; then
        echo "⚠️  Large file: $file ($lines lines)"
    fi
done

# Count methods per class (basic analysis)
echo ""
echo "3. Analyzing class complexity..."
echo "==============================="

# Find classes with many methods (heuristic: count "  " at start of lines)
find lib/ -name "*.dart" -type f | while read -r file; do
    # Count method-like patterns (simplified)
    method_count=$(grep -c "^  [a-zA-Z].*(" "$file" 2>/dev/null || echo "0")
    if [ "$method_count" -gt 50 ]; then
        echo "⚠️  Complex class: $file (~$method_count methods)"
    fi
done

# Generate complexity report
echo ""
echo "4. Complexity Summary:"
echo "====================="
echo ""
echo "💡 Recommendations:"
echo "   - Keep files under 2000 lines"
echo "   - Keep classes under 50 methods"
echo "   - Refactor complex methods (>10 cyclomatic complexity)"
echo "   - Use composition over inheritance"
echo ""

# Check for nested conditionals (complexity indicator)
echo "5. Checking for deeply nested code..."
deep_nesting=$(find lib/ -name "*.dart" -type f -exec grep -l "if.*if.*if.*if" {} \; 2>/dev/null | wc -l || echo "0")
if [ "$deep_nesting" -gt 0 ]; then
    echo "⚠️  Found $deep_nesting files with deep nesting (4+ levels)"
    echo "   Consider refactoring to reduce nesting"
else
    echo "✅ No files with excessive nesting found"
fi

echo ""
echo "✅ Complexity analysis complete"
echo ""
echo "📊 For detailed analysis, use:"
echo "   - Flutter DevTools (performance profiling)"
echo "   - dart analyze (static analysis)"
echo "   - Code review (manual inspection)"
















