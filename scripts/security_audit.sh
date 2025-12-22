#!/bin/bash

# Security Audit Script
# Checks for common security issues in the codebase

set -e

echo "🔒 Running Security Audit..."
echo ""

ISSUES=0

# Check for hardcoded API keys in source code
echo "1. Checking for hardcoded API keys..."
if grep -r "AIza[0-9A-Za-z_-]\{35\}" lib/ --exclude-dir=generated 2>/dev/null | grep -v "//.*API" | grep -v "example"; then
    echo "   ⚠️  WARNING: Potential API keys found in source code"
    ISSUES=$((ISSUES + 1))
else
    echo "   ✅ No hardcoded API keys found in lib/"
fi

# Check for secrets in code
echo ""
echo "2. Checking for common secrets..."
SECRET_PATTERNS=("password" "secret" "private_key" "api_key" "access_token")
for pattern in "${SECRET_PATTERNS[@]}"; do
    if grep -ri "$pattern.*=.*['\"][^'\"]*['\"]" lib/ --exclude-dir=generated 2>/dev/null | grep -v "//.*example" | grep -v "test"; then
        echo "   ⚠️  WARNING: Potential secret found: $pattern"
        ISSUES=$((ISSUES + 1))
    fi
done
if [ $ISSUES -eq 0 ]; then
    echo "   ✅ No obvious secrets found"
fi

# Check .env file is in .gitignore
echo ""
echo "3. Checking .gitignore..."
if grep -q "\.env" .gitignore 2>/dev/null; then
    echo "   ✅ .env is in .gitignore"
else
    echo "   ⚠️  WARNING: .env not found in .gitignore"
    ISSUES=$((ISSUES + 1))
fi

# Check for debug prints in production code
echo ""
echo "4. Checking for debug prints..."
if grep -r "print(" lib/ --exclude-dir=generated 2>/dev/null | grep -v "kDebugMode" | grep -v "test"; then
    echo "   ⚠️  WARNING: print() statements found (use LoggerService instead)"
    ISSUES=$((ISSUES + 1))
else
    echo "   ✅ No unsafe print() statements found"
fi

# Check for error messages that might leak information
echo ""
echo "5. Checking for information leakage in error messages..."
if grep -ri "stack.*trace\|exception.*message\|error.*details" lib/ --exclude-dir=generated 2>/dev/null | grep -v "LoggerService" | grep -v "kDebugMode"; then
    echo "   ⚠️  WARNING: Potential information leakage in error messages"
    ISSUES=$((ISSUES + 1))
else
    echo "   ✅ Error messages appear safe"
fi

# Summary
echo ""
echo "=========================================="
if [ $ISSUES -eq 0 ]; then
    echo "✅ Security audit passed!"
    exit 0
else
    echo "⚠️  Found $ISSUES potential security issue(s)"
    echo "   Please review the warnings above"
    exit 1
fi





