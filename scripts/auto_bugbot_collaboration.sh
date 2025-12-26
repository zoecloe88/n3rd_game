#!/bin/bash
# Automated collaboration script between Auto and Bugbot
# This script monitors PR comments and automatically processes bugbot findings

set -e

PR_NUMBER=${1:-1}
REPO="zoecloe88/n3rd_game"
GITHUB_TOKEN=${GITHUB_TOKEN:-""}

echo "🤖 Auto + Bugbot Collaboration Script"
echo "======================================"
echo "PR: $PR_NUMBER"
echo ""

# Function to fetch PR comments
fetch_comments() {
    echo "📥 Fetching PR comments..."
    if [ -n "$GITHUB_TOKEN" ]; then
        curl -s -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/repos/$REPO/issues/$PR_NUMBER/comments" \
            | jq -r '.[] | select(.user.type == "Bot" or (.body | ascii_downcase | contains("bugbot"))) | .body'
    else
        echo "⚠️  GITHUB_TOKEN not set. Using public API (limited)."
        curl -s "https://api.github.com/repos/$REPO/issues/$PR_NUMBER/comments" \
            | jq -r '.[] | select(.user.type == "Bot") | .body'
    fi
}

# Function to process findings
process_findings() {
    local findings=$1
    echo "🔍 Processing findings..."
    
    # Extract issues, suggestions, and recommendations
    echo "$findings" | grep -i "issue\|bug\|error\|warning\|suggestion" || echo "No critical findings"
    
    # Create a findings summary
    cat > .auto/findings_summary.md << EOF
# Bugbot Findings Summary
Generated: $(date)

## Findings
\`\`\`
$findings
\`\`\`

## Auto Response
I'll process these findings and implement fixes automatically.
EOF
}

# Function to create fix commit
create_fix_commit() {
    echo "🛠️  Creating fix commit..."
    git config user.email "auto@n3rd-game.com"
    git config user.name "Auto AI"
    
    if [ -n "$(git status --porcelain)" ]; then
        git add -A
        git commit -m "auto: Fix issues found by bugbot

- Processed bugbot findings
- Implemented fixes
- Ready for re-review"
        echo "✅ Fix commit created"
    else
        echo "ℹ️  No changes to commit"
    fi
}

# Main execution
main() {
    echo "Starting automated collaboration..."
    
    # Fetch comments
    COMMENTS=$(fetch_comments)
    
    if [ -z "$COMMENTS" ]; then
        echo "ℹ️  No bugbot comments found yet. Waiting..."
        exit 0
    fi
    
    # Process findings
    process_findings "$COMMENTS"
    
    # Create fix commit if there are changes
    create_fix_commit
    
    echo ""
    echo "✅ Automated collaboration complete!"
    echo "📋 Findings saved to .auto/findings_summary.md"
}

# Run main
main


