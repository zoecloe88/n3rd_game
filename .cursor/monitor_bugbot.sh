#!/bin/bash
# Monitor PR for bugbot comments and trigger Auto response
# This script runs automatically via GitHub Actions

PR_NUMBER=2
REPO="zoecloe88/n3rd_game"

echo "🔍 Monitoring PR #$PR_NUMBER for bugbot comments..."

# Fetch latest comments
COMMENTS=$(gh pr view $PR_NUMBER --json comments --jq '.comments[] | select(.author.type == "Bot" or (.body | ascii_downcase | contains("bugbot"))) | .body')

if [ -n "$COMMENTS" ]; then
    echo "✅ Found bugbot comments - Auto will process them"
    echo "$COMMENTS" > .auto/bugbot_findings.txt
    # Trigger Auto to read and fix
    echo "🤖 Auto: Processing bugbot findings..."
else
    echo "ℹ️  No bugbot comments yet"
fi

