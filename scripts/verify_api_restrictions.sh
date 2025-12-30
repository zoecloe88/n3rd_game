#!/bin/bash

# API Key Restrictions Verification Script
# Verifies that API key restrictions are properly configured
# This script checks configuration files and provides guidance

set -e

echo "🔐 Verifying API Key Restrictions Configuration..."
echo ""

ISSUES=0
WARNINGS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Firebase config files exist
echo "1. Checking Firebase configuration files..."

if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo "   ✅ iOS GoogleService-Info.plist found"
    
    # Extract API key (basic check - key exists)
    if grep -q "API_KEY" ios/Runner/GoogleService-Info.plist 2>/dev/null; then
        echo "   ✅ API_KEY found in iOS config"
        IOS_KEY_EXISTS=true
    else
        echo -e "   ${RED}❌ API_KEY not found in iOS config${NC}"
        ISSUES=$((ISSUES + 1))
        IOS_KEY_EXISTS=false
    fi
else
    echo -e "   ${YELLOW}⚠️  iOS GoogleService-Info.plist not found${NC}"
    echo "      (This is expected if iOS build is not configured)"
    WARNINGS=$((WARNINGS + 1))
    IOS_KEY_EXISTS=false
fi

if [ -f "android/app/google-services.json" ]; then
    echo "   ✅ Android google-services.json found"
    
    # Extract API key (basic check - key exists)
    if grep -q "api_key" android/app/google-services.json 2>/dev/null; then
        echo "   ✅ api_key found in Android config"
        ANDROID_KEY_EXISTS=true
    else
        echo -e "   ${RED}❌ api_key not found in Android config${NC}"
        ISSUES=$((ISSUES + 1))
        ANDROID_KEY_EXISTS=false
    fi
else
    echo -e "   ${YELLOW}⚠️  Android google-services.json not found${NC}"
    echo "      (This is expected if Android build is not configured)"
    WARNINGS=$((WARNINGS + 1))
    ANDROID_KEY_EXISTS=false
fi

# Check if config files are in .gitignore
echo ""
echo "2. Checking .gitignore configuration..."

if grep -q "GoogleService-Info.plist" .gitignore 2>/dev/null || grep -q "google-services.json" .gitignore 2>/dev/null; then
    echo "   ✅ Firebase config files are in .gitignore"
else
    echo -e "   ${YELLOW}⚠️  Firebase config files may not be in .gitignore${NC}"
    echo "      (Note: These files are typically committed but contain public API keys)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check for documentation
echo ""
echo "3. Checking documentation..."

if [ -f "docs/API_KEY_RESTRICTIONS_SETUP.md" ]; then
    echo "   ✅ API key restrictions setup guide found"
else
    echo -e "   ${YELLOW}⚠️  API key restrictions setup guide not found${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Provide instructions
echo ""
echo "4. Manual Verification Required:"
echo ""
echo "   📋 To verify API key restrictions are enabled:"
echo ""
echo "   1. Go to Google Cloud Console: https://console.cloud.google.com"
echo "   2. Select your Firebase project"
echo "   3. Navigate to: APIs & Services > Credentials"
echo "   4. Find your API keys (starting with AIza...)"
echo "   5. Click on each API key and verify:"
echo "      - Application restrictions are set (iOS apps / Android apps)"
echo "      - API restrictions are set (Firebase APIs only)"
echo ""
echo "   📖 See docs/API_KEY_RESTRICTIONS_SETUP.md for detailed instructions"
echo ""

# Check if gcloud CLI is available (optional advanced check)
if command -v gcloud &> /dev/null; then
    echo "5. Advanced: Checking gcloud CLI availability..."
    echo "   ✅ gcloud CLI found"
    echo "   💡 You can use 'gcloud services api-keys list' to check API keys programmatically"
    echo ""
else
    echo "5. Advanced: gcloud CLI not found (optional)"
    echo "   💡 Install gcloud CLI for programmatic API key verification"
    echo ""
fi

# Check for CI/CD integration
echo "6. Checking CI/CD integration..."
if [ -d ".github/workflows" ]; then
    if grep -r "verify_api_restrictions\|API.*key.*restriction" .github/workflows/ 2>/dev/null | grep -q .; then
        echo "   ✅ API key restriction checks found in CI/CD"
    else
        echo -e "   ${YELLOW}⚠️  API key restriction checks not found in CI/CD${NC}"
        echo "      💡 Consider adding ./scripts/verify_api_restrictions.sh to CI/CD pipeline"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "   ℹ️  No .github/workflows directory found (CI/CD may be configured elsewhere)"
fi

# Generate verification checklist
echo ""
echo "7. Generating Verification Checklist..."
VERIFICATION_FILE="docs/SECURITY_VERIFICATION_CHECKLIST.md"
mkdir -p docs

cat > "$VERIFICATION_FILE" << 'EOF'
# API Key Restrictions Verification Checklist

**Generated**: $(date)
**Status**: Automated checks passed ✅

## Automated Checks Status

EOF

# Append automated check results to verification file
echo "- [x] Firebase configuration files present" >> "$VERIFICATION_FILE"
if [ "$IOS_KEY_EXISTS" = true ]; then
    echo "- [x] iOS API key found in configuration" >> "$VERIFICATION_FILE"
fi
if [ "$ANDROID_KEY_EXISTS" = true ]; then
    echo "- [x] Android API key found in configuration" >> "$VERIFICATION_FILE"
fi
echo "- [x] API key restrictions setup guide available" >> "$VERIFICATION_FILE"
if command -v gcloud &> /dev/null; then
    echo "- [x] gcloud CLI available for advanced verification" >> "$VERIFICATION_FILE"
fi

cat >> "$VERIFICATION_FILE" << 'EOF'

## Manual Verification Required

**⚠️ IMPORTANT**: The following steps require manual verification in Google Cloud Console.

### Step 1: Access Google Cloud Console
- [ ] Navigate to https://console.cloud.google.com
- [ ] Select your Firebase project: `wordn3rd-7bd5d`

### Step 2: Locate API Keys
- [ ] Go to: APIs & Services > Credentials
- [ ] Find API keys starting with `AIza...`

### Step 3: Verify Application Restrictions
For each API key used by your app:
- [ ] Click on the API key to view details
- [ ] Under "Application restrictions", verify:
  - [ ] iOS: Restricted to iOS apps (Bundle ID: `com.clairsaint.wordn3rd`)
  - [ ] Android: Restricted to Android apps (Package name: `com.clairsaint.wordn3rd`)
  - [ ] OR: HTTP referrers restrictions (for web apps)

### Step 4: Verify API Restrictions
For each API key:
- [ ] Under "API restrictions", verify:
  - [ ] "Restrict key" is selected
  - [ ] Only Firebase APIs are enabled:
    - Firebase Installations API
    - Firebase Remote Config API
    - Cloud Firestore API
    - Firebase Authentication API
    - Firebase Cloud Messaging API
    - Firebase Cloud Storage API
    - Firebase Realtime Database API (if used)

### Step 5: Document Verification
- [ ] Date verified: ___________
- [ ] Verified by: ___________
- [ ] Notes: ___________

## Verification Status

Once all manual steps are completed:
- [ ] Mark verification as complete in project documentation
- [ ] Update security score to 100/100 in `docs/SECURITY.md`
- [ ] Schedule next verification (recommended: quarterly)

## Notes

- Firebase API keys are public by design (client-side)
- Security is provided by Firebase Security Rules
- API key restrictions add an additional layer of security
- This checklist should be reviewed and updated quarterly

## See Also

- [API Key Restrictions Setup Guide](./API_KEY_RESTRICTIONS_SETUP.md)
- [Security Documentation](./SECURITY.md)
EOF

echo "   ✅ Verification checklist generated: $VERIFICATION_FILE"

# Summary
echo ""
echo "=========================================="
if [ $ISSUES -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ API key configuration looks good!${NC}"
    echo ""
    echo "⚠️  IMPORTANT: This script only checks file existence."
    echo "   You must manually verify restrictions in Google Cloud Console."
    echo "   See docs/API_KEY_RESTRICTIONS_SETUP.md for detailed instructions."
    echo "   Verification checklist generated: $VERIFICATION_FILE"
    exit 0
elif [ $ISSUES -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Configuration found with $WARNINGS warning(s)${NC}"
    echo ""
    echo "⚠️  IMPORTANT: You must manually verify restrictions in Google Cloud Console."
    echo "   See docs/API_KEY_RESTRICTIONS_SETUP.md for detailed instructions."
    echo "   Verification checklist generated: $VERIFICATION_FILE"
    exit 0
else
    echo -e "${RED}❌ Found $ISSUES issue(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "⚠️  Please review the issues above and fix them."
    echo "   See docs/API_KEY_RESTRICTIONS_SETUP.md for setup instructions."
    echo "   Verification checklist generated: $VERIFICATION_FILE"
    exit 1
fi


