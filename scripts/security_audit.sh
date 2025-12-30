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

# Run secret scan if available
echo ""
echo "6. Running secret scan..."
if [ -f "scripts/secret_scan.sh" ]; then
    chmod +x scripts/secret_scan.sh
    if ./scripts/secret_scan.sh; then
        echo "   ✅ Secret scan passed"
    else
        echo "   ⚠️  Secret scan found issues"
        ISSUES=$((ISSUES + 1))
    fi
else
    echo "   ⚠️  Secret scan script not found"
    WARNINGS=$((WARNINGS + 1))
fi

# Check for certificate pinning
echo ""
echo "7. Checking for certificate pinning..."
if grep -r "certificate.*pinning\|http_certificate_pinning\|SecureHttpClient" lib/ --exclude-dir=generated 2>/dev/null | grep -v "test" | grep -q .; then
    echo "   ✅ Certificate pinning implementation found"
else
    echo "   ⚠️  Certificate pinning not implemented (recommended for production)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check dependency vulnerabilities (basic check)
echo ""
echo "8. Checking dependency security..."
if command -v flutter &> /dev/null; then
    echo "   💡 Run 'flutter pub outdated' to check for outdated dependencies"
    echo "   💡 Review pub.dev for security advisories"
else
    echo "   ⚠️  Flutter not found, skipping dependency check"
fi

# Summary
echo ""
echo "=========================================="
if [ $ISSUES -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ Security audit passed!"
    exit 0
elif [ $ISSUES -eq 0 ]; then
    echo "⚠️  Security audit completed with $WARNINGS warning(s)"
    echo "   Please review the warnings above"
    exit 0
else
    echo "⚠️  Found $ISSUES potential security issue(s) and $WARNINGS warning(s)"
    echo "   Please review the warnings above"
    exit 1
fi










