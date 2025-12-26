#!/bin/bash

# Script to upload MP4 video assets to Firebase Storage
# Project: wordn3rd-7bd5d
# Storage bucket: wordn3rd-7bd5d.firebasestorage.app

set -e

PROJECT_ID="wordn3rd-7bd5d"
STORAGE_BUCKET="wordn3rd-7bd5d.firebasestorage.app"
ASSETS_DIR="assets"

echo "🚀 Uploading MP4 video files to Firebase Storage..."
echo "Project: $PROJECT_ID"
echo "Bucket: $STORAGE_BUCKET"
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Please install it:"
    echo "   npm install -g firebase-tools"
    exit 1
fi

# Check if logged in
if ! firebase projects:list &> /dev/null; then
    echo "🔐 Please log in to Firebase:"
    firebase login
fi

# Upload each MP4 file to Firebase Storage public folder
echo "📤 Uploading video files..."

# List of MP4 files to upload
VIDEOS=(
    "loginscreen.mp4"
    "titlescreen.mp4"
    "settingscreen.mp4"
    "statscreen.mp4"
    "modeselectionscreen.mp4"
    "modeselection2.mp4"
    "modeselection3.mp4"
    "modeselectiontransitionscreen.mp4"
    "wordoftheday.mp4"
    "edition.mp4"
    "youthscreen.mp4"
    "logoloadingscreen.mp4"
)

for video in "${VIDEOS[@]}"; do
    if [ -f "$ASSETS_DIR/$video" ]; then
        echo "  📹 Uploading $video..."
        # Upload to public/videos/ folder in Firebase Storage
        gsutil -m cp "$ASSETS_DIR/$video" "gs://$STORAGE_BUCKET/public/videos/$video" || {
            echo "  ⚠️  Failed to upload $video using gsutil, trying alternative method..."
            # Alternative: Use Firebase Storage REST API or firebase-tools
            echo "  💡 You may need to upload manually via Firebase Console:"
            echo "     https://console.firebase.google.com/project/$PROJECT_ID/storage"
        }
    else
        echo "  ⚠️  File not found: $ASSETS_DIR/$video"
    fi
done

echo ""
echo "✅ Upload complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Verify files in Firebase Console:"
echo "      https://console.firebase.google.com/project/$PROJECT_ID/storage"
echo "   2. Update your code to use Firebase Storage URLs instead of local assets"
echo "   3. Files are accessible at: gs://$STORAGE_BUCKET/public/videos/[filename]"
echo ""

