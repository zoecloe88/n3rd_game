#!/usr/bin/env python3
import os
import shutil

# Source directory
src_dir = "assets/animations/Green Neutral Simple Serendipity Phone Wallpaper(1)"
dest_base = "assets/animations"

# File mappings
mappings = {
    "first loading.mp4": "logo",
    "2nd loading.mp4": "onboarding",
    "title screen.mp4": "title",
    "mode selection screen.mp4": "mode_selection",
    "mode selection.mp4": "mode_selection",
    "stat screen.mp4": "stats",
    "setting screen.mp4": "settings",
    "word of the day.mp4": "word_of_day",
    "8.mp4": "shared",
    "10.mp4": "shared",
    "11.mp4": "shared",
}

print("Organizing animation files...")
print("")

# Create directories
for category in set(mappings.values()):
    os.makedirs(f"{dest_base}/{category}", exist_ok=True)

# Copy files
copied = 0
for filename, category in mappings.items():
    src_path = os.path.join(src_dir, filename)
    dest_path = os.path.join(dest_base, category, filename)
    
    if os.path.exists(src_path):
        shutil.copy2(src_path, dest_path)
        print(f"✓ {filename} → {category}/")
        copied += 1
    else:
        print(f"⚠ {filename} not found")

print("")
print(f"✅ Organized {copied} files successfully!")
print(f"📁 Files are now in: assets/animations/[category]/")

