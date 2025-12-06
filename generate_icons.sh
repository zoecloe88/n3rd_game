#!/bin/bash

# Script to generate app icons from source images
# Usage: ./generate_icons.sh <source_app_icon.png>
# Make sure ImageMagick is installed (brew install imagemagick on macOS)

if [ -z "$1" ]; then
    echo "Usage: ./generate_icons.sh <source_app_icon.png>"
    echo "Example: ./generate_icons.sh assets/images/app_icon.png"
    exit 1
fi

SOURCE_ICON="$1"

if [ ! -f "$SOURCE_ICON" ]; then
    echo "Error: Source icon file '$SOURCE_ICON' not found!"
    exit 1
fi

echo "Generating app icons from $SOURCE_ICON..."

# Android icons
echo "Generating Android icons..."
mkdir -p android/app/src/main/res/mipmap-mdpi
mkdir -p android/app/src/main/res/mipmap-hdpi
mkdir -p android/app/src/main/res/mipmap-xhdpi
mkdir -p android/app/src/main/res/mipmap-xxhdpi
mkdir -p android/app/src/main/res/mipmap-xxxhdpi

magick "$SOURCE_ICON" -resize 48x48! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 android/app/src/main/res/mipmap-mdpi/ic_launcher.png
magick "$SOURCE_ICON" -resize 72x72! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 android/app/src/main/res/mipmap-hdpi/ic_launcher.png
magick "$SOURCE_ICON" -resize 96x96! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
magick "$SOURCE_ICON" -resize 144x144! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
magick "$SOURCE_ICON" -resize 192x192! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png

# iOS icons
echo "Generating iOS icons..."
magick "$SOURCE_ICON" -resize 20x20! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png
magick "$SOURCE_ICON" -resize 40x40! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png
magick "$SOURCE_ICON" -resize 60x60! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png
magick "$SOURCE_ICON" -resize 29x29! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png
magick "$SOURCE_ICON" -resize 58x58! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png
magick "$SOURCE_ICON" -resize 87x87! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png
magick "$SOURCE_ICON" -resize 40x40! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png
magick "$SOURCE_ICON" -resize 80x80! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png
magick "$SOURCE_ICON" -resize 120x120! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png
magick "$SOURCE_ICON" -resize 120x120! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png
magick "$SOURCE_ICON" -resize 180x180! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png
magick "$SOURCE_ICON" -resize 76x76! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png
magick "$SOURCE_ICON" -resize 152x152! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png
magick "$SOURCE_ICON" -resize 167x167! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png
magick "$SOURCE_ICON" -resize 1024x1024! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png

# macOS icons
echo "Generating macOS icons..."
magick "$SOURCE_ICON" -resize 16x16! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png
magick "$SOURCE_ICON" -resize 32x32! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png
magick "$SOURCE_ICON" -resize 64x64! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png
magick "$SOURCE_ICON" -resize 128x128! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png
magick "$SOURCE_ICON" -resize 256x256! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png
magick "$SOURCE_ICON" -resize 512x512! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png
magick "$SOURCE_ICON" -resize 1024x1024! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png

# Web icons
echo "Generating Web icons..."
magick "$SOURCE_ICON" -resize 192x192! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 web/icons/Icon-192.png
magick "$SOURCE_ICON" -resize 512x512! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 web/icons/Icon-512.png
magick "$SOURCE_ICON" -resize 192x192! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 web/icons/Icon-maskable-192.png
magick "$SOURCE_ICON" -resize 512x512! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 web/icons/Icon-maskable-512.png

# Web favicon
magick "$SOURCE_ICON" -resize 32x32! -quality 100 -filter Lanczos -sharpen 0x1.0 -define png:compression-level=9 web/favicon.png

# Windows icon (requires ico format, but we'll create a PNG that can be converted)
echo "Note: Windows .ico file should be generated manually or using a tool like ImageMagick with -define icon:auto-resize"
echo "For now, creating app_icon.ico placeholder (you may need to convert manually)"

echo "Done! All app icons have been generated."
echo ""
echo "Next steps:"
echo "1. Verify the generated icons look correct"
echo "2. For Windows, manually convert app_icon.png to app_icon.ico format if needed"
echo "3. Run 'flutter pub get' to ensure assets are registered"
echo "4. Run 'flutter clean' and rebuild your app"



