# 🚀 GitHub CLI & Bugbot Usage Guide

## ✅ GitHub CLI Setup (Already Configured!)

Your GitHub CLI is already set up and authenticated:
- **Version:** 2.83.2
- **Account:** zoecloe88
- **Status:** ✅ Authenticated
- **Token Scopes:** repo, workflow, gist, read:org

## 📋 Common GitHub CLI Commands

### PR Management

```bash
# List all PRs
gh pr list

# View a specific PR
gh pr view 3

# View PR in browser
gh pr view 3 --web

# Create a new PR
gh pr create --title "Your PR Title" --body "Description"

# Create PR as draft
gh pr create --draft --title "WIP: Feature" --body "Work in progress"

# Checkout a PR locally
gh pr checkout 3

# Merge a PR
gh pr merge 3

# Close a PR
gh pr close 3

# Add reviewers
gh pr edit 3 --add-reviewer username

# Add labels
gh pr edit 3 --add-label "bug" "enhancement"

# Comment on PR
gh pr comment 3 --body "Great work!"
```

### Branch Management

```bash
# List branches
gh repo view --json defaultBranchRef

# Create branch from PR
gh pr checkout 3

# View branch info
gh api repos/zoecloe88/n3rd_game/branches/auto-bugbot-round-2
```

### Issue Management

```bash
# List issues
gh issue list

# Create issue
gh issue create --title "Bug: Title" --body "Description"

# View issue
gh issue view 1

# Close issue
gh issue close 1
```

### Repository Info

```bash
# View repo info
gh repo view zoecloe88/n3rd_game

# View repo in browser
gh repo view --web

# Clone repo
gh repo clone zoecloe88/n3rd_game
```

## 🤖 Using Bugbot for Code Reviews

### What is Bugbot?

Bugbot is an AI-powered code review tool that automatically analyzes your code for:
- Bugs and potential issues
- Code quality improvements
- Security vulnerabilities
- Performance optimizations
- Best practices

### Option 1: Graphite Integration (Recommended)

If you have Graphite set up with bugbot:

```bash
# Install Graphite CLI (if not installed)
npm install -g @graphitehq/cli

# Authenticate with Graphite
gt auth --token YOUR_GRAPHITE_TOKEN

# Create a branch for bugbot review
gt branch create bugbot-review

# Make your changes and commit
git add .
git commit -m "Ready for bugbot review"

# Submit to Graphite (creates PR automatically)
gt submit --stack

# Bugbot will automatically review the PR
```

### Option 2: Direct GitHub PR with Bugbot

1. **Create a PR using GitHub CLI:**
```bash
# Create PR
gh pr create --title "Ready for bugbot review" --body "Please review this code"

# Get PR number
PR_NUMBER=$(gh pr list --head auto-bugbot-round-2 --json number --jq '.[0].number')

# View PR
gh pr view $PR_NUMBER --web
```

2. **Add Bugbot as Reviewer:**
   - Go to the PR on GitHub
   - Click "Reviewers" → Add "bugbot" or your bugbot GitHub username
   - Bugbot will automatically review the PR

3. **Or use GitHub CLI:**
```bash
# Add bugbot as reviewer (replace with actual bugbot username)
gh pr edit 3 --add-reviewer bugbot
```

### Option 3: Manual Bugbot Review

If bugbot is a separate service:

1. **Get PR diff:**
```bash
# View PR diff
gh pr diff 3

# Save diff to file
gh pr diff 3 > pr-diff.patch
```

2. **Submit to Bugbot:**
   - Upload the diff to bugbot's interface
   - Or use bugbot's API/CLI if available

### Option 4: GitHub Actions Integration

Your project already has a GitHub Actions workflow for Auto + Bugbot collaboration!

**Location:** `.github/workflows/auto-bugbot-collaboration.yml`

**How it works:**
1. Bugbot comments on PR
2. GitHub Actions detects the comment
3. Auto processes the findings
4. Auto implements fixes
5. Auto pushes updates
6. Bugbot re-reviews

**Trigger manually:**
```bash
# Trigger workflow via GitHub CLI
gh workflow run "Auto + Bugbot Collaboration" --ref auto-bugbot-round-2
```

## 🔄 Current Workflow Example

### Step 1: Create Branch & Make Changes
```bash
git checkout -b feature/my-feature
# Make changes
git add .
git commit -m "Add new feature"
```

### Step 2: Push & Create PR
```bash
git push -u origin feature/my-feature
gh pr create --title "Add new feature" --body "Description" --draft
```

### Step 3: Request Bugbot Review
```bash
PR_NUMBER=$(gh pr list --head feature/my-feature --json number --jq '.[0].number')
gh pr edit $PR_NUMBER --add-reviewer bugbot
# Or comment: @bugbot please review
gh pr comment $PR_NUMBER --body "@bugbot please review this PR"
```

### Step 4: Monitor Review
```bash
# Watch for comments
gh pr view $PR_NUMBER --comments

# View in browser
gh pr view $PR_NUMBER --web
```

### Step 5: Address Feedback
```bash
# Checkout PR branch
gh pr checkout $PR_NUMBER

# Make fixes
git add .
git commit -m "Fix: Address bugbot feedback"
git push

# Bugbot will automatically re-review
```

## 📊 Useful GitHub CLI Aliases

Add these to your `~/.bashrc` or `~/.zshrc`:

```bash
# PR shortcuts
alias prs='gh pr list'
alias prv='gh pr view'
alias prc='gh pr create'
alias prm='gh pr merge'
alias prco='gh pr checkout'

# Issue shortcuts
alias issues='gh issue list'
alias issue='gh issue view'

# Repo shortcuts
alias repo='gh repo view --web'
```

## 🎯 Quick Reference

### Current PRs
```bash
# List open PRs
gh pr list

# View PR #3
gh pr view 3

# View PR #3 in browser
gh pr view 3 --web
```

### Current Status
- **PR #3:** Open - Round 2 collaboration
- **Branch:** auto-bugbot-round-2
- **Status:** Ready for bugbot review

### Next Steps
1. Request bugbot review on PR #3:
   ```bash
   gh pr edit 3 --add-reviewer bugbot
   # Or
   gh pr comment 3 --body "@bugbot please review"
   ```

2. Monitor the review:
   ```bash
   gh pr view 3 --web
   ```

3. Auto will automatically fix any findings!

## 🔗 Resources

- **GitHub CLI Docs:** https://cli.github.com/manual/
- **Graphite Docs:** https://docs.graphite.dev/
- **Current PR:** https://github.com/zoecloe88/n3rd_game/pull/3

---

**💡 Pro Tip:** Use `gh pr view --web` to open PRs in your browser for easier review!

