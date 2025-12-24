#!/bin/bash

# Script to check test coverage and generate coverage report
# Usage: ./scripts/check_coverage.sh

set -e

echo "🧪 Running Flutter tests with coverage..."
echo ""

# Run tests with coverage
flutter test --coverage

# Check if lcov is available
if command -v genhtml &> /dev/null; then
    echo ""
    echo "📊 Generating HTML coverage report..."
    genhtml coverage/lcov.info -o coverage/html --no-function-coverage
    
    echo ""
    echo "✅ Coverage report generated at: coverage/html/index.html"
    echo "📈 Open it in your browser to view detailed coverage"
else
    echo ""
    echo "⚠️  genhtml not found. Install lcov to generate HTML reports:"
    echo "   macOS: brew install lcov"
    echo "   Linux: sudo apt-get install lcov"
    echo ""
    echo "📊 Raw coverage data available at: coverage/lcov.info"
fi

# Calculate basic coverage percentage
if [ -f coverage/lcov.info ]; then
    echo ""
    echo "📈 Coverage Summary:"
    echo "==================="
    
    # Count lines
    total_lines=$(grep -c "^SF:" coverage/lcov.info || echo "0")
    covered_lines=$(grep -c "^DA:" coverage/lcov.info | grep -v ",0$" || echo "0")
    
    if [ "$total_lines" -gt 0 ]; then
        coverage_percent=$((covered_lines * 100 / total_lines))
        echo "   Total Lines: $total_lines"
        echo "   Covered Lines: $covered_lines"
        echo "   Coverage: ~${coverage_percent}%"
    fi
    
    echo ""
    echo "💡 Target: 80%+ coverage"
fi







