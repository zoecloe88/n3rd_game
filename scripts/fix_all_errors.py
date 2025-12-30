#!/usr/bin/env python3
"""Fix all linter errors: add semicolons to LoggerService calls and replace debugPrint"""
import re
import os
from pathlib import Path

def fix_file(file_path):
    """Fix all issues in a file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        changes = 0
        
        # 1. Replace debugPrint with LoggerService in trivia_templates_consolidated.dart
        if 'trivia_templates_consolidated.dart' in str(file_path):
            # Replace if (kDebugMode) { debugPrint('...'); }
            content = re.sub(
                r"if\s*\(kDebugMode\)\s*\{\s*debugPrint\(\s*'([^']+)'\s*\);\s*\}",
                lambda m: f"LoggerService.info('{m.group(1).replace('✓ ', '').replace('❌ ', '').replace('⚠️ ', '')}');",
                content,
                flags=re.MULTILINE | re.DOTALL
            )
            # Replace standalone debugPrint('...');
            content = re.sub(
                r"debugPrint\(\s*'([^']+)'\s*\);\s*",
                lambda m: f"LoggerService.info('{m.group(1).replace('✓ ', '').replace('❌ ', '').replace('⚠️ ', '')}');",
                content,
                flags=re.MULTILINE
            )
        
        # 2. Add semicolons to LoggerService calls missing them
        # Pattern: LoggerService.method('...') without semicolon at end of line
        def add_semicolon(match):
            nonlocal changes
            changes += 1
            return match.group(0).rstrip() + ';'
        
        # Match LoggerService calls that don't end with semicolon or comma
        content = re.sub(
            r'(LoggerService\.(debug|info|warning|error)\([^)]+\))(?![;,\n])',
            add_semicolon,
            content,
            flags=re.MULTILINE
        )
        
        # Fix lines ending with LoggerService call but no semicolon
        lines = content.split('\n')
        for i, line in enumerate(lines):
            stripped = line.rstrip()
            if re.search(r'LoggerService\.(debug|info|warning|error)\(', stripped):
                if not stripped.endswith(';') and not stripped.endswith(',') and stripped:
                    lines[i] = stripped + ';' + line[len(stripped):]
                    changes += 1
        content = '\n'.join(lines)
        
        if content != original:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return changes
        
        return 0
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return 0

def main():
    """Main function"""
    lib_dir = Path('lib')
    total_changes = 0
    files_fixed = 0
    
    for dart_file in lib_dir.rglob('*.dart'):
        # Skip logger_service.dart itself
        if 'logger_service.dart' in str(dart_file):
            continue
        
        changes = fix_file(dart_file)
        if changes > 0:
            files_fixed += 1
            total_changes += changes
            print(f"Fixed {dart_file}: {changes} changes")
    
    print(f"\nTotal: {total_changes} fixes in {files_fixed} files")

if __name__ == '__main__':
    main()














