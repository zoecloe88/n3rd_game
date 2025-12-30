#!/usr/bin/env python3
"""Script to replace debugPrint with LoggerService across the codebase."""

import os
import re
import sys
from pathlib import Path

def replace_debugprint_in_file(file_path):
    """Replace debugPrint statements with LoggerService calls."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        changes = 0
        
        # Check if LoggerService is imported
        has_logger_import = 'logger_service' in content.lower() or 'LoggerService' in content
        
        # Pattern 1: Simple debugPrint('message')
        def replace_simple(match):
            nonlocal changes
            changes += 1
            msg = match.group(1)
            # Determine log level based on message content
            if '❌' in msg or 'error' in msg.lower() or 'failed' in msg.lower():
                return f"LoggerService.error('{msg.replace('❌ ', '').replace('❌', '')}')"
            elif '⚠️' in msg or 'warning' in msg.lower():
                return f"LoggerService.warning('{msg.replace('⚠️ ', '').replace('⚠️', '')}')"
            elif '✅' in msg or 'success' in msg.lower() or '✓' in msg:
                return f"LoggerService.info('{msg.replace('✅ ', '').replace('✅', '').replace('✓ ', '').replace('✓', '')}')"
            else:
                return f"LoggerService.debug('{msg}')"
        
        # Replace if (kDebugMode) { debugPrint('...'); }
        content = re.sub(
            r"if\s*\(kDebugMode\)\s*\{\s*debugPrint\(\s*'([^']+)'\s*\);\s*\}",
            replace_simple,
            content,
            flags=re.MULTILINE | re.DOTALL
        )
        
        # Replace standalone debugPrint('...')
        content = re.sub(
            r"debugPrint\(\s*'([^']+)'\s*\);",
            replace_simple,
            content,
            flags=re.MULTILINE
        )
        
        # Add LoggerService import if needed and changes were made
        if changes > 0 and not has_logger_import:
            # Find the last import statement
            import_pattern = r"(import\s+['\"][^'\"]+['\"];)"
            imports = list(re.finditer(import_pattern, content))
            if imports:
                last_import = imports[-1]
                insert_pos = last_import.end()
                # Add LoggerService import
                logger_import = "\nimport 'package:n3rd_game/services/logger_service.dart';"
                content = content[:insert_pos] + logger_import + content[insert_pos:]
        
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return changes
        
        return 0
    except Exception as e:
        print(f"Error processing {file_path}: {e}", file=sys.stderr)
        return 0

def main():
    """Main function to process all Dart files."""
    lib_dir = Path(__file__).parent.parent / 'lib'
    
    if not lib_dir.exists():
        print(f"Error: {lib_dir} does not exist", file=sys.stderr)
        sys.exit(1)
    
    total_changes = 0
    files_processed = 0
    
    # Process all .dart files
    for dart_file in lib_dir.rglob('*.dart'):
        # Skip test files for now
        if 'test' in str(dart_file):
            continue
        
        changes = replace_debugprint_in_file(dart_file)
        if changes > 0:
            files_processed += 1
            total_changes += changes
            print(f"Processed {dart_file}: {changes} replacements")
    
    print(f"\nTotal: {total_changes} replacements in {files_processed} files")

if __name__ == '__main__':
    main()














