#!/bin/bash
# generate_optimization_report.sh - Generate comprehensive optimization report

cd "$(dirname "$0")"

REPORT="OPTIMIZATION_REPORT.md"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "📊 Generating optimization report..."

cat > "$REPORT" << EOF
# Project Optimization Report
Generated: $DATE

## Code Analysis
\`\`\`
EOF

flutter analyze --no-fatal-infos >> "$REPORT" 2>&1

cat >> "$REPORT" << EOF
\`\`\`

## Dependency Status
\`\`\`
EOF

flutter pub outdated >> "$REPORT" 2>&1

cat >> "$REPORT" << EOF
\`\`\`

## Asset Sizes
\`\`\`
EOF

if [ -f "check_app_size.sh" ]; then
    ./check_app_size.sh >> "$REPORT" 2>&1
else
    echo "Assets folder:" >> "$REPORT"
    du -sh assets/ >> "$REPORT" 2>&1 || echo "No assets folder" >> "$REPORT"
fi

cat >> "$REPORT" << EOF
\`\`\`

## Project Size Breakdown
\`\`\`
EOF

echo "Total project size:" >> "$REPORT"
du -sh . >> "$REPORT" 2>&1
echo "" >> "$REPORT"
echo "Source code (lib/):" >> "$REPORT"
du -sh lib/ >> "$REPORT" 2>&1
echo "" >> "$REPORT"
echo "Assets:" >> "$REPORT"
du -sh assets/ >> "$REPORT" 2>&1 || echo "No assets folder" >> "$REPORT"
echo "" >> "$REPORT"
echo "Build artifacts:" >> "$REPORT"
du -sh build/ >> "$REPORT" 2>&1 || echo "No build folder (cleaned)" >> "$REPORT"
echo "" >> "$REPORT"
echo "iOS Pods:" >> "$REPORT"
du -sh ios/Pods/ >> "$REPORT" 2>&1 || echo "No Pods folder" >> "$REPORT"

cat >> "$REPORT" << EOF
\`\`\`

## File Count Statistics
\`\`\`
EOF

echo "Dart files:" >> "$REPORT"
find lib -name "*.dart" -type f | wc -l | xargs echo >> "$REPORT"
echo "" >> "$REPORT"
echo "Screen files:" >> "$REPORT"
find lib/screens -name "*.dart" -type f | wc -l | xargs echo >> "$REPORT"
echo "" >> "$REPORT"
echo "Service files:" >> "$REPORT"
find lib/services -name "*.dart" -type f | wc -l | xargs echo >> "$REPORT"
echo "" >> "$REPORT"
echo "Video assets:" >> "$REPORT"
find assets/videos -name "*.mp4" -type f 2>/dev/null | wc -l | xargs echo >> "$REPORT" || echo "0" >> "$REPORT"

cat >> "$REPORT" << EOF
\`\`\`

## Recommendations

### High Priority
1. Review code analysis issues above
2. Update outdated dependencies if available
3. Consider compressing video assets (77 MP4 files)

### Medium Priority
1. Review large files for potential splitting (game_service.dart is 4934 lines)
2. Enable tree-shaking for release builds
3. Move large videos to cloud storage (Firebase Storage)

### Low Priority
1. Add automated testing coverage
2. Generate API documentation
3. Set up CI/CD pipeline

---
*Report generated automatically - Review and update as needed*
EOF

echo "✅ Report generated: $REPORT"
echo "📄 View with: cat $REPORT | less"

