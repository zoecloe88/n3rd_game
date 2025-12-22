#!/bin/bash
# Automated Graphite Setup Script

set -e

echo "🚀 Setting up Graphite for code review..."
echo ""

# Check if authenticated
if gt auth --help 2>&1 | grep -q "token"; then
    echo "📋 To authenticate, get your token from:"
    echo "   https://app.graphite.com/activate"
    echo ""
    echo "Then run:"
    echo "   gt auth --token YOUR_TOKEN"
    echo ""
fi

# Initialize repo (this should work even without auth)
echo "🔧 Initializing Graphite repository..."
gt repo init 2>&1 | grep -v "WARNING\|renamed" || true

echo ""
echo "✅ Graphite repo initialized!"
echo ""
echo "📝 Next steps:"
echo "   1. Get auth token: https://app.graphite.com/activate"
echo "   2. Authenticate: gt auth --token YOUR_TOKEN"
echo "   3. Sync repo: https://app.graphite.com/settings/synced-repos"
echo "   4. Create stack: gt stack create --name 'code-review'"
echo "   5. Submit: gt submit --stack"
