#!/usr/bin/env python3
"""Fix all remaining syntax errors efficiently"""
import re
from pathlib import Path

def fix_string_interpolation_semicolons(content):
    """Fix semicolons inside string interpolations: ${expr;} -> ${expr}"""
    # Pattern: ${expression;} -> ${expression}
    # This handles cases like: '...${missingDeps.join(", ");}...'
    content = re.sub(r'\$\{([^}]+);\}', r'${{\1}}', content)
    return content

def fix_file(file_path):
    """Fix syntax errors in a file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        
        # Fix 1: Remove semicolons inside string interpolations
        content = fix_string_interpolation_semicolons(content)
        
        # Fix 2: Fix broken LoggerService calls with trailing semicolons
        # Pattern: LoggerService.method('...',; -> LoggerService.method('...',
        content = re.sub(r"(LoggerService\.\w+\('[^']+'),;", r"\1,", content)
        
        # Fix 3: Fix broken multi-line LoggerService calls
        # If we have LoggerService.method('...',; followed by ); on next line
        content = re.sub(r"LoggerService\.\w+\(\s*'([^']+)',;\s*\n\s*\);", 
                        r"LoggerService.debug('\1');", content)
        
        if content != original:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

def main():
    # Files with known syntax errors
    files_to_fix = [
        'lib/utils/video_path_helper.dart',
        'lib/services/performance_monitoring_service.dart',
        'lib/services/secure_http_client.dart',
        'lib/services/subscription_service.dart',
        'lib/services/trivia_generator_service.dart',
        'lib/services/ai_edition_service.dart',
    ]
    
    fixed_count = 0
    for file_path in files_to_fix:
        path = Path(file_path)
        if path.exists() and fix_file(path):
            fixed_count += 1
            print(f"Fixed {file_path}")
    
    print(f"\nFixed {fixed_count} files")

if __name__ == "__main__":
    main()














