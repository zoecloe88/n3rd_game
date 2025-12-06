#!/bin/bash
# Build monitoring script

echo "📊 Build Status Check - $(date '+%H:%M:%S')"
echo ""

# Check for build processes
BUILD_PROCS=$(ps aux | grep -E "flutter run|dart|xcodebuild" | grep -v grep | wc -l | tr -d ' ')
echo "🔨 Active build processes: $BUILD_PROCS"

# Check if xcodebuild is running
if pgrep -fl "xcodebuild" > /dev/null; then
    echo "✅ Xcode build: RUNNING"
    xcodebuild_proc=$(pgrep -fl "xcodebuild" | head -1 | awk '{print $2}')
    echo "   PID: $xcodebuild_proc"
else
    echo "❌ Xcode build: NOT RUNNING"
fi

# Check if app is built
if [ -f "build/ios/Debug-iphonesimulator/Runner.app/Runner" ]; then
    echo "✅ App binary: EXISTS"
    ls -lh build/ios/Debug-iphonesimulator/Runner.app/Runner | awk '{print "   Size: " $5}'
else
    echo "⏳ App binary: NOT YET CREATED"
fi

# Check if app is running on simulator
if xcrun simctl list apps booted 2>/dev/null | grep -qi "n3rd\|runner"; then
    echo "✅ App on simulator: RUNNING"
else
    echo "⏳ App on simulator: NOT RUNNING YET"
fi

# Check disk space
DISK_FREE=$(df -h / | tail -1 | awk '{print $4}')
DISK_USED=$(df -h / | tail -1 | awk '{print $5}')
echo "💾 Disk space: $DISK_FREE free ($DISK_USED used)"

echo ""
echo "---"
echo ""

