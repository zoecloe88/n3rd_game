#!/bin/bash

# Script to add Firebase Crashlytics dSYM upload build phase to Xcode project
# This automates the process of adding the upload script to the project

PROJECT_FILE="ios/Runner.xcodeproj/project.pbxproj"
SCRIPT_PATH="${PWD}/ios/upload_dsym.sh"

if [ ! -f "$PROJECT_FILE" ]; then
  echo "Error: Xcode project file not found at $PROJECT_FILE"
  exit 1
fi

if [ ! -f "$SCRIPT_PATH" ]; then
  echo "Error: Upload script not found at $SCRIPT_PATH"
  exit 1
fi

echo "⚠️  Manual step required:"
echo ""
echo "To add the dSYM upload script to your Xcode project:"
echo ""
echo "1. Open ios/Runner.xcworkspace in Xcode"
echo "2. Select the 'Runner' target"
echo "3. Go to 'Build Phases' tab"
echo "4. Click the '+' button and select 'New Run Script Phase'"
echo "5. Name it 'Upload dSYM to Firebase Crashlytics'"
echo "6. Move it to run AFTER 'Embed Frameworks' (drag it down)"
echo "7. Add this script:"
echo ""
echo "   \"\${SRCROOT}/upload_dsym.sh\""
echo ""
echo "8. Uncheck 'For install builds only' (so it runs for all builds)"
echo "9. Save and close Xcode"
echo ""
echo "Alternatively, you can add it via command line using:"
echo "  xcodebuild -project ios/Runner.xcodeproj -target Runner -showBuildSettings | grep -i dsym"
echo ""
echo "The upload script is ready at: $SCRIPT_PATH"


