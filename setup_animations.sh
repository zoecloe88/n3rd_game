#!/bin/bash
set -e

SOURCE="/Users/gerardandre/Downloads/Green Neutral Simple Serendipity Phone Wallpaper(1)"
DEST="assets/videos/animations"

# Create directories
mkdir -p "$DEST/logo"
mkdir -p "$DEST/onboarding"
mkdir -p "$DEST/title"
mkdir -p "$DEST/mode_selection"
mkdir -p "$DEST/stats"
mkdir -p "$DEST/settings"
mkdir -p "$DEST/word_of_day"
mkdir -p "$DEST/shared"

# Copy files
cp "$SOURCE/first loading.mp4" "$DEST/logo/"
cp "$SOURCE/2nd loading.mp4" "$DEST/onboarding/"
cp "$SOURCE/title screen.mp4" "$DEST/title/"
cp "$SOURCE/mode selection screen.mp4" "$DEST/mode_selection/"
cp "$SOURCE/mode selection.mp4" "$DEST/mode_selection/"
cp "$SOURCE/stat screen.mp4" "$DEST/stats/"
cp "$SOURCE/setting screen.mp4" "$DEST/settings/"
cp "$SOURCE/word of the day.mp4" "$DEST/word_of_day/"
cp "$SOURCE/8.mp4" "$DEST/shared/"
cp "$SOURCE/10.mp4" "$DEST/shared/"
cp "$SOURCE/11.mp4" "$DEST/shared/"

echo "✅ All animations copied successfully"

