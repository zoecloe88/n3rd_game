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

# Calculate accurate coverage percentage and generate report
if [ -f coverage/lcov.info ]; then
    echo ""
    echo "📈 Coverage Summary:"
    echo "==================="
    
    # Use lcov to get accurate coverage
    if command -v lcov &> /dev/null; then
        # Generate summary
        lcov --summary coverage/lcov.info 2>&1 | grep -E "lines|functions|branches" || true
        
        # Extract coverage percentage
        coverage_info=$(lcov --summary coverage/lcov.info 2>&1 | grep "lines.*:" | head -1)
        if [ -n "$coverage_info" ]; then
            coverage_percent=$(echo "$coverage_info" | grep -oE '[0-9]+\.[0-9]+%' | head -1 | sed 's/%//')
            coverage_percent_int=$(echo "$coverage_percent" | cut -d. -f1)
            
            echo ""
            echo "📊 Overall Coverage: ${coverage_percent}%"
            
            # Generate coverage report markdown
            REPORT_FILE="docs/TEST_COVERAGE.md"
            mkdir -p docs
            
            cat > "$REPORT_FILE" << EOF
# Test Coverage Report

**Generated**: $(date)  
**Overall Coverage**: ${coverage_percent}%

## Coverage Summary

EOF
            
            # Extract detailed coverage information
            lcov --summary coverage/lcov.info 2>&1 | grep -E "lines|functions|branches" >> "$REPORT_FILE" || true
            
            cat >> "$REPORT_FILE" << EOF

## Coverage Targets

### Overall Targets
- **Target**: >80% overall coverage
- **Current**: ${coverage_percent}%
- **Status**: $([ "$coverage_percent_int" -ge 80 ] && echo "✅ PASSING" || echo "⚠️  BELOW TARGET")

### Critical Service Targets
- **Target**: >90% coverage for critical services
- **Services**: GameService, AuthService, NetworkService, MultiplayerService
- **Status**: See detailed report below

## How to View Detailed Coverage

### HTML Report (Recommended)
\`\`\`bash
open coverage/html/index.html
# or
xdg-open coverage/html/index.html  # Linux
\`\`\`

### Command Line
\`\`\`bash
lcov --summary coverage/lcov.info
\`\`\`

## Coverage by Service Category

### Core Services
- Game Service: [Check HTML report for details]
- Authentication Service: [Check HTML report for details]
- Network Service: [Check HTML report for details]

### Game Managers
- GameTriviaManager: [Check HTML report for details]
- GamePowerupManager: [Check HTML report for details]
- GamePersistenceManager: [Check HTML report for details]

### Other Services
- Multiplayer Service: [Check HTML report for details]
- Stats Service: [Check HTML report for details]
- Challenge Service: [Check HTML report for details]

## Improving Coverage

### Areas Needing More Tests
1. **Integration Tests**: Expand integration test coverage
2. **Edge Cases**: Add tests for error conditions and edge cases
3. **UI Interactions**: Add widget tests for screen interactions
4. **Performance**: Add performance-specific tests

### Test Writing Guidelines
1. **Unit Tests**: Test individual methods and classes in isolation
2. **Widget Tests**: Test UI components and interactions
3. **Integration Tests**: Test complete user flows
4. **Test Helpers**: Use \`TestHelpers\` for common setup

## Running Tests

\`\`\`bash
# Run all tests with coverage
./scripts/check_coverage.sh

# Run specific test file
flutter test test/services/game_service_test.dart

# Run tests without coverage
flutter test

# Run integration tests
flutter test test/integration/
\`\`\`

## Notes

- Coverage is calculated using \`lcov\`
- HTML reports provide detailed line-by-line coverage
- Target coverage thresholds are guidelines, not strict requirements
- Focus on covering critical paths and edge cases

**Last Updated**: $(date)
EOF
            
            echo ""
            echo "✅ Coverage report generated: $REPORT_FILE"
        else
            echo "⚠️  Could not extract coverage percentage"
        fi
    else
        echo "⚠️  lcov not found. Install lcov for detailed coverage analysis:"
        echo "   macOS: brew install lcov"
        echo "   Linux: sudo apt-get install lcov"
    fi
else
    echo ""
    echo "❌ Coverage file not found. Run 'flutter test --coverage' first."
    exit 1
fi
            
            # Check if coverage meets threshold
            if [ "$coverage_percent_int" -ge 85 ]; then
                echo "✅ Coverage meets target (85%+)"
                exit_code=0
            elif [ "$coverage_percent_int" -ge 80 ]; then
                echo "⚠️  Coverage is good but below target (80-85%)"
                exit_code=0
            else
                echo "❌ Coverage below target (<80%)"
                exit_code=1
            fi
        fi
    else
        # Fallback: basic calculation
        total_lines=$(grep -c "^SF:" coverage/lcov.info || echo "0")
        covered_lines=$(grep -c "^DA:" coverage/lcov.info | grep -v ",0$" || echo "0")
        
        if [ "$total_lines" -gt 0 ]; then
            coverage_percent=$((covered_lines * 100 / total_lines))
            echo "   Total Files: $total_lines"
            echo "   Coverage: ~${coverage_percent}%"
        fi
        
        echo ""
        echo "💡 Install lcov for accurate coverage calculation:"
        echo "   macOS: brew install lcov"
        echo "   Linux: sudo apt-get install lcov"
        exit_code=0
    fi
    
    echo ""
    echo "💡 Target: 85%+ coverage"
    
    # Save coverage percentage to file for CI/CD
    if [ -n "$coverage_percent" ]; then
        echo "$coverage_percent" > coverage/coverage_percent.txt
    fi
    
    exit ${exit_code:-0}
fi










