#!/usr/bin/env python3
import os
import shutil
import sys

src = "/Users/gerardandre/Downloads/game screen123.png"
dest_dir = "assets/images"
dest_file = os.path.join(dest_dir, "game screen123.png")
dest_file2 = os.path.join(dest_dir, "game_screen_bg.png")

# Create directory if it doesn't exist
os.makedirs(dest_dir, exist_ok=True)

# Copy file
if os.path.exists(src):
    shutil.copy2(src, dest_file)
    shutil.copy2(src, dest_file2)
    print(f"✅ Copied {src} to {dest_file}")
    print(f"✅ Also copied to {dest_file2}")
    sys.exit(0)
else:
    print(f"❌ Source file not found: {src}")
    sys.exit(1)

