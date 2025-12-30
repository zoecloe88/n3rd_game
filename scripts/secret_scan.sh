#!/bin/bash

# Secret Scanning Script
# Scans codebase for potential secrets and sensitive information
# Usage: ./scripts/secret_scan.sh

set -e

echo "🔍 Running Secret Scan..."
echo ""

ISSUES=0
WARNINGS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Patterns to detect secrets
declare -a SECRET_PATTERNS=(
    "password.*=.*['\"][^'\"]{8,}['\"]"
    "secret.*=.*['\"][^'\"]{8,}['\"]"
    "private_key.*=.*['\"][^'\"]{20,}['\"]"
    "api_key.*=.*['\"][^'\"]{20,}['\"]"
    "access_token.*=.*['\"][^'\"]{20,}['\"]"
    "AIza[0-9A-Za-z_-]{35}"
    "sk_live_[0-9a-zA-Z]{32,}"
    "sk_test_[0-9a-zA-Z]{32,}"
    "pk_live_[0-9a-zA-Z]{32,}"
    "pk_test_[0-9a-zA-Z]{32,}"
    "xox[baprs]-[0-9]{12}-[0-9]{12}-[0-9]{12}-[a-zA-Z0-9]{32}"
    "AKIA[0-9A-Z]{16}"
    "[0-9a-f]{32}-us[0-9]{1,2}"
    "ghp_[0-9a-zA-Z]{36}"
    "gho_[0-9a-zA-Z]{36}"
    "ghu_[0-9a-zA-Z]{36}"
    "ghs_[0-9a-zA-Z]{36}"
    "ghr_[0-9a-zA-Z]{36}"
)

# Directories to exclude
EXCLUDE_DIRS="--exclude-dir=build --exclude-dir=.dart_tool --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=Pods --exclude-dir=.gradle --exclude-dir=coverage --exclude-dir=ios/build --exclude-dir=android/.gradle"

# Files to exclude
EXCLUDE_FILES="--exclude=*.lock --exclude=*.log --exclude=*.pbxproj --exclude=*.xcworkspace --exclude=*.xcodeproj"

# Check for hardcoded API keys
echo "1. Checking for hardcoded API keys..."
API_KEY_MATCHES=$(grep -r "AIza[0-9A-Za-z_-]\{35\}" lib/ $EXCLUDE_DIRS $EXCLUDE_FILES 2>/dev/null | grep -v "//.*API" | grep -v "example" | grep -v "test" | grep -v "TODO" || true)

if [ -n "$API_KEY_MATCHES" ]; then
    echo -e "   ${RED}❌ Potential API keys found:${NC}"
    echo "$API_KEY_MATCHES" | while read -r line; do
        echo "      $line"
    done
    ISSUES=$((ISSUES + 1))
else
    echo "   ✅ No hardcoded API keys found"
fi

# Check for common secret patterns
echo ""
echo "2. Checking for common secret patterns..."

for pattern in "${SECRET_PATTERNS[@]}"; do
    # Extract pattern name for display
    pattern_name=$(echo "$pattern" | cut -d'.' -f1 | head -c 20)
    
    matches=$(grep -riE "$pattern" lib/ $EXCLUDE_DIRS $EXCLUDE_FILES 2>/dev/null | \
        grep -v "//.*example" | \
        grep -v "test" | \
        grep -v "TODO" | \
        grep -v "FIXME" | \
        grep -v "password.*validation" | \
        grep -v "password.*strength" | \
        grep -v "password.*min" | \
        grep -v "password.*max" | \
        grep -v "password.*required" | \
        grep -v "password.*field" | \
        grep -v "password.*controller" | \
        grep -v "password.*reset" | \
        grep -v "password.*reset" | \
        grep -v "api.*key.*restriction" | \
        grep -v "API.*KEY" | \
        grep -v "api.*key.*management" || true)
    
    if [ -n "$matches" ]; then
        echo -e "   ${YELLOW}⚠️  Potential secret pattern found: $pattern_name${NC}"
        echo "$matches" | head -3 | while read -r line; do
            echo "      $line"
        done
        if [ $(echo "$matches" | wc -l) -gt 3 ]; then
            echo "      ... and $(($(echo "$matches" | wc -l) - 3)) more"
        fi
        WARNINGS=$((WARNINGS + 1))
    fi
done

if [ $WARNINGS -eq 0 ]; then
    echo "   ✅ No obvious secrets found"
fi

# Check for .env files in git
echo ""
echo "3. Checking for .env files in repository..."
if find . -name ".env" -not -path "./.git/*" -not -path "./node_modules/*" 2>/dev/null | grep -q .; then
    echo -e "   ${YELLOW}⚠️  .env files found in repository${NC}"
    find . -name ".env" -not -path "./.git/*" -not -path "./node_modules/*" 2>/dev/null | while read -r file; do
        echo "      $file"
    done
    WARNINGS=$((WARNINGS + 1))
else
    echo "   ✅ No .env files found in repository"
fi

# Check .gitignore for .env
echo ""
echo "4. Checking .gitignore for .env..."
if grep -q "\.env" .gitignore 2>/dev/null; then
    echo "   ✅ .env is in .gitignore"
else
    echo -e "   ${RED}❌ .env not found in .gitignore${NC}"
    ISSUES=$((ISSUES + 1))
fi

# Check for debug prints that might leak secrets
echo ""
echo "5. Checking for unsafe debug prints..."
UNSAFE_PRINTS=$(grep -r "print(" lib/ $EXCLUDE_DIRS $EXCLUDE_FILES 2>/dev/null | \
    grep -v "kDebugMode" | \
    grep -v "test" | \
    grep -v "//.*safe" | \
    grep -v "LoggerService" || true)

if [ -n "$UNSAFE_PRINTS" ]; then
    echo -e "   ${YELLOW}⚠️  Unsafe print() statements found (use LoggerService instead):${NC}"
    echo "$UNSAFE_PRINTS" | head -5 | while read -r line; do
        echo "      $line"
    done
    if [ $(echo "$UNSAFE_PRINTS" | wc -l) -gt 5 ]; then
        echo "      ... and $(($(echo "$UNSAFE_PRINTS" | wc -l) - 5)) more"
    fi
    WARNINGS=$((WARNINGS + 1))
else
    echo "   ✅ No unsafe print() statements found"
fi

# Check for error messages that might leak information
echo ""
echo "6. Checking for information leakage in error messages..."
LEAKAGE_MATCHES=$(grep -riE "stack.*trace|exception.*message|error.*details" lib/ $EXCLUDE_DIRS $EXCLUDE_FILES 2>/dev/null | \
    grep -v "LoggerService" | \
    grep -v "kDebugMode" | \
    grep -v "Crashlytics" | \
    grep -v "//.*safe" || true)

if [ -n "$LEAKAGE_MATCHES" ]; then
    echo -e "   ${YELLOW}⚠️  Potential information leakage in error messages:${NC}"
    echo "$LEAKAGE_MATCHES" | head -3 | while read -r line; do
        echo "      $line"
    done
    WARNINGS=$((WARNINGS + 1))
else
    echo "   ✅ Error messages appear safe"
fi

# Check for hardcoded credentials in test files
echo ""
echo "7. Checking test files for hardcoded credentials..."
TEST_SECRETS=$(grep -riE "password.*=.*['\"][^'\"]{8,}['\"]|secret.*=.*['\"][^'\"]{8,}['\"]" test/ $EXCLUDE_DIRS $EXCLUDE_FILES 2>/dev/null | \
    grep -v "//.*test" | \
    grep -v "//.*mock" | \
    grep -v "//.*example" || true)

if [ -n "$TEST_SECRETS" ]; then
    echo -e "   ${YELLOW}⚠️  Potential hardcoded credentials in test files:${NC}"
    echo "$TEST_SECRETS" | head -3 | while read -r line; do
        echo "      $line"
    done
    WARNINGS=$((WARNINGS + 1))
else
    echo "   ✅ No hardcoded credentials in test files"
fi

# Check for exposed environment variables
echo ""
echo "8. Checking for exposed environment variables..."
ENV_EXPOSURE=$(grep -riE "process\.env|Platform\.environment|String\.fromEnvironment" lib/ $EXCLUDE_DIRS $EXCLUDE_FILES 2>/dev/null | \
    grep -v "//.*safe" | \
    grep -v "kDebugMode" || true)

if [ -n "$ENV_EXPOSURE" ]; then
    ENV_COUNT=$(echo "$ENV_EXPOSURE" | wc -l)
    echo -e "   ${BLUE}ℹ️  Found $ENV_COUNT environment variable usage(s)${NC}"
    echo "   💡 Ensure sensitive values use secure storage, not environment variables"
else
    echo "   ✅ No obvious environment variable exposure"
fi

# Summary
echo ""
echo "=========================================="
if [ $ISSUES -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ Secret scan passed!${NC}"
    exit 0
elif [ $ISSUES -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Secret scan completed with $WARNINGS warning(s)${NC}"
    echo "   Please review the warnings above"
    exit 0
else
    echo -e "${RED}❌ Secret scan found $ISSUES issue(s) and $WARNINGS warning(s)${NC}"
    echo "   Please review and fix the issues above"
    exit 1
fi


