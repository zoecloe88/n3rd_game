#!/bin/bash

# Simple script to guide Firebase Storage upload
# Project: wordn3rd-7bd5d

echo "🚀 Uploading MP4 videos to Firebase Storage"
echo "Project: wordn3rd-7bd5d"
echo ""
echo "📋 Files to upload:"
echo "   - loginscreen.mp4"
echo "   - titlescreen.mp4"
echo "   - settingscreen.mp4"
echo "   - statscreen.mp4"
echo "   - modeselectionscreen.mp4"
echo "   - modeselection2.mp4"
echo "   - modeselection3.mp4"
echo "   - modeselectiontransitionscreen.mp4"
echo "   - wordoftheday.mp4"
echo "   - edition.mp4"
echo "   - youthscreen.mp4"
echo "   - logoloadingscreen.mp4"
echo ""
echo "🌐 Opening Firebase Console..."
echo "   Please upload files to: public/videos/"
echo ""

# Try to open Firebase Console in browser
if command -v open &> /dev/null; then
    open "https://console.firebase.google.com/project/wordn3rd-7bd5d/storage"
elif command -v xdg-open &> /dev/null; then
    xdg-open "https://console.firebase.google.com/project/wordn3rd-7bd5d/storage"
else
    echo "Please visit: https://console.firebase.google.com/project/wordn3rd-7bd5d/storage"
fi

echo ""
echo "📝 Instructions:"
echo "   1. Create folder: public/videos/"
echo "   2. Upload all MP4 files from assets/ folder"
echo "   3. Files will be publicly accessible"
echo ""

