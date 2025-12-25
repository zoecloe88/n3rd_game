#!/bin/bash

# Script to run only core service tests (excluding Firebase-dependent tests)
# This focuses on unit tests that don't require Firebase initialization

echo "🧪 Running core service tests (non-Firebase)..."
echo ""

# List of core service test files (excluding Firebase-dependent ones)
CORE_TESTS=(
  "test/services/animation_randomizer_service_test.dart"
  "test/services/game_service_test.dart"
  "test/services/trivia_generator_service_test.dart"
  "test/services/subscription_service_test.dart"
  "test/services/content_moderation_service_test.dart"
  "test/services/input_sanitizer_test.dart"
  "test/services/practice_learning_modes_test.dart"
  "test/services/trivia_validation_test.dart"
  "test/services/auth_service_test.dart"
)

# Build test command
TEST_CMD="flutter test"
for test_file in "${CORE_TESTS[@]}"; do
  if [ -f "$test_file" ]; then
    TEST_CMD="$TEST_CMD $test_file"
  fi
done

# Run tests and filter Firebase/Google Fonts/file_picker noise
$TEST_CMD 2>&1 | \
  grep -v "No Firebase App" | \
  grep -v "Firebase.*has been created" | \
  grep -v "Failed to load subscription tier from Firestore" | \
  grep -v "Failed to sync subscription tier to Firestore" | \
  grep -v "Firebase auth not available" | \
  grep -v "file_picker.*references file_picker" | \
  grep -v "package:firebase" | \
  grep -v "package:cloud_firestore" | \
  grep -v "google_fonts.*unable to load font" | \
  grep -v "Exception: Failed to load font with url" | \
  grep -v "fonts.gstatic.com" | \
  grep -v "package:google_fonts" | \
  grep -v "Package file_picker:" | \
  grep -v "Ask the maintainers of file_picker" | \
  grep -v "inline implementation"

EXIT_CODE=${PIPESTATUS[0]}

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ All core service tests passed!"
else
  echo "❌ Some core service tests failed (exit code: $EXIT_CODE)"
fi

exit $EXIT_CODE

