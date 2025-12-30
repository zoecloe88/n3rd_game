#!/usr/bin/env python3
"""Fix all 'extends ChangeNotifier?' to 'extends ChangeNotifier'"""
import re
from pathlib import Path

def fix_file(file_path):
    """Fix ChangeNotifier? extends"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        
        # Fix: extends ChangeNotifier? -> extends ChangeNotifier
        content = re.sub(r'extends\s+ChangeNotifier\?', 'extends ChangeNotifier', content)
        
        if content != original:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

def main():
    lib_dir = Path('lib')
    fixed_count = 0
    
    # Find all files with extends ChangeNotifier?
    for dart_file in lib_dir.rglob('*.dart'):
        if fix_file(dart_file):
            fixed_count += 1
    
    print(f"\nFixed {fixed_count} files")

if __name__ == "__main__":
    main()














