#!/usr/bin/env python3
"""Fix all syntax errors introduced by previous script"""
import re
from pathlib import Path

def fix_file(file_path):
    """Fix all syntax errors in a file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        
        # Fix 1: Remove semicolons after opening parentheses in LoggerService calls
        # Pattern: LoggerService.method(; -> LoggerService.method(
        content = re.sub(
            r'LoggerService\.(debug|info|warning|error)\(;',
            r'LoggerService.\1(',
            content
        )
        
        # Fix 2: Replace remaining debugPrint in trivia_templates_consolidated.dart
        if 'trivia_templates_consolidated.dart' in str(file_path):
            # Replace if (kDebugMode) { debugPrint('...'); } with LoggerService.info('...');
            content = re.sub(
                r"if\s*\(kDebugMode\)\s*\{\s*debugPrint\(\s*'([^']+)',?\s*\);\s*\}",
                r"LoggerService.info('\1');",
                content,
                flags=re.MULTILINE
            )
            # Replace standalone debugPrint('...');
            content = re.sub(
                r"debugPrint\(\s*'([^']+)',?\s*\);",
                r"LoggerService.info('\1');",
                content
            )
        
        # Fix 3: Remove unused foundation.dart imports (only if kDebugMode is not used)
        if "import 'package:flutter/foundation.dart';" in content:
            # Check if kDebugMode is actually used in the file
            if 'kDebugMode' not in content:
                content = re.sub(
                    r"import\s+'package:flutter/foundation\.dart';\s*\n",
                    '',
                    content
                )
        
        if content != original:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

def fix_logger_service():
    """Fix missing semicolons in logger_service.dart"""
    file_path = Path('lib/services/logger_service.dart')
    if not file_path.exists():
        return False
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        modified = False
        for i, line in enumerate(lines):
            original = line
            # Add semicolon to LoggerService calls that don't have one
            if 'LoggerService.' in line and not line.rstrip().endswith(';') and not line.rstrip().endswith(',') and ')' in line:
                # Check if it's a complete call on one line
                if line.rstrip().endswith(')'):
                    lines[i] = line.rstrip() + ';\n'
                    modified = True
            
            if line != original:
                modified = True
        
        if modified:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.writelines(lines)
            return True
        return False
    except Exception as e:
        print(f"Error fixing logger_service.dart: {e}")
        return False

def main():
    lib_dir = Path('lib')
    fixed_count = 0
    
    # Fix all Dart files
    for dart_file in lib_dir.rglob('*.dart'):
        if fix_file(dart_file):
            fixed_count += 1
    
    # Fix logger_service.dart specifically
    if fix_logger_service():
        print("Fixed logger_service.dart")
    
    print(f"\nFixed {fixed_count} files")

if __name__ == "__main__":
    main()














