#!/usr/bin/env python3
"""Clean up old build artifacts"""
import os
import shutil
import subprocess
import sys

PROJECT_ROOT = "/Users/gerardandre/n3rd_game"

def run_command(cmd, description):
    """Run a shell command and print status"""
    print(f"{description}...")
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"  ✅ {description} completed")
        else:
            print(f"  ⚠️  {description} completed (may have warnings)")
    except Exception as e:
        print(f"  ❌ {description} failed: {e}")

def remove_directory(path, description):
    """Remove a directory if it exists"""
    if os.path.exists(path):
        try:
            size = get_dir_size(path)
            shutil.rmtree(path)
            print(f"  ✅ Removed {description} ({size})")
        except Exception as e:
            print(f"  ❌ Failed to remove {description}: {e}")
    else:
        print(f"  ℹ️  {description} not found (already clean)")

def get_dir_size(path):
    """Get directory size in human-readable format"""
    try:
        result = subprocess.run(
            ["du", "-sh", path],
            capture_output=True,
            text=True,
            stderr=subprocess.DEVNULL
        )
        if result.returncode == 0:
            return result.stdout.split()[0]
    except:
        pass
    return "unknown size"

def main():
    print("🧹 Cleaning old builds...")
    print("")
    
    os.chdir(PROJECT_ROOT)
    
    # Stop processes
    print("1. Stopping running processes...")
    run_command("pkill -f 'flutter run'", "Stopped flutter processes")
    run_command("pkill -f 'xcodebuild'", "Stopped xcodebuild processes")
    print("")
    
    # Flutter clean
    print("2. Running flutter clean...")
    run_command("flutter clean", "Flutter clean")
    print("")
    
    # Remove directories
    print("3. Removing build directories...")
    remove_directory(f"{PROJECT_ROOT}/build", "Flutter build directory")
    remove_directory(f"{PROJECT_ROOT}/ios/Pods", "iOS Pods")
    remove_directory(f"{PROJECT_ROOT}/ios/Podfile.lock", "Podfile.lock (file)")
    
    # Xcode artifacts
    print("")
    print("4. Removing Xcode artifacts...")
    derived_data = os.path.expanduser("~/Library/Developer/Xcode/DerivedData")
    if os.path.exists(derived_data):
        # Remove contents but keep directory
        for item in os.listdir(derived_data):
            remove_directory(os.path.join(derived_data, item), f"DerivedData/{item}")
    else:
        print("  ℹ️  Xcode DerivedData not found")
    
    # Temporary files
    print("")
    print("5. Cleaning temporary files...")
    temp_patterns = [
        "/var/folders/zf/y8sx6ccd0z91l8qb8by0slpc0000gn/T/flutter_tools.*",
        "/var/folders/zf/y8sx6ccd0z91l8qb8by0slpc0000gn/T/*xcresult*"
    ]
    for pattern in temp_patterns:
        run_command(f"rm -rf {pattern}", f"Cleaned {pattern}")
    
    print("")
    print("✅ Cleanup complete!")
    print("")
    print("📊 Current disk space:")
    result = subprocess.run(["df", "-h", "/"], capture_output=True, text=True)
    if result.returncode == 0:
        lines = result.stdout.strip().split('\n')
        if len(lines) > 1:
            print(lines[-1])
    print("")

if __name__ == "__main__":
    main()

