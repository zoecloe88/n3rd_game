#!/bin/bash

# Script to run Flutter tests while filtering out Firebase/Google Fonts/file_picker noise
# This helps focus on actual test failures without dependency-related warnings

echo "🧪 Running Flutter tests (filtering Firebase/Google Fonts/file_picker noise)..."
echo ""

# Run tests and filter output
flutter test 2>&1 | \
  grep -v "No Firebase App" | \
  grep -v "Firebase.*has been created" | \
  grep -v "firebase" | \
  grep -v "Firestore" | \
  grep -v "firebase_core" | \
  grep -v "cloud_firestore" | \
  grep -v "file_picker.*references file_picker" | \
  grep -v "package:firebase" | \
  grep -v "package:cloud_firestore" | \
  grep -v "Failed to load subscription tier from Firestore" | \
  grep -v "Failed to sync subscription tier to Firestore" | \
  grep -v "Firebase auth not available" | \
  grep -v "google_fonts.*unable to load font" | \
  grep -v "Exception: Failed to load font with url" | \
  grep -v "fonts.gstatic.com" | \
  grep -v "package:google_fonts" | \
  grep -v "There is likely something wrong with your test.*google_fonts" | \
  grep -v "Make sure to use a matching library which informs the test runner" | \
  grep -v "Package file_picker:" | \
  grep -v "Ask the maintainers of file_picker" | \
  grep -v "inline implementation" | \
  tee test_results_filtered.txt

echo ""
echo "📊 Summary saved to: test_results_filtered.txt"
echo ""
echo "✅ Filtered results shown above (Firebase/Google Fonts/file_picker noise removed)"
echo "💡 To see all tests including dependency warnings, run: flutter test"

