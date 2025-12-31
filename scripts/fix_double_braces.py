#!/usr/bin/env python3
import re

files = [
    'lib/services/performance_monitoring_service.dart',
    'lib/services/secure_http_client.dart',
]

for file_path in files:
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Fix double braces: ${{expr}} -> ${expr}
        content = re.sub(r'\$\{\{([^}]+)\}\}', r'${{\1}}', content)
        
        with open(file_path, 'w') as f:
            f.write(content)
        print(f'Fixed double braces in {file_path}')
    except Exception as e:
        print(f'Error: {file_path}: {e}')














