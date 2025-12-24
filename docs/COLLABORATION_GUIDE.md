# 🤝 Auto + Bugbot Collaboration Guide

## Overview

This project uses an automated collaboration system between Auto (AI assistant) and Bugbot for continuous code quality improvement.

## Quick Start

### Request Bugbot Review
```bash
gh pr comment <PR_NUMBER> --body "@bugbot please review"
```

### View PR Status
```bash
gh pr view <PR_NUMBER> --web
```

### Monitor Comments
```bash
gh pr view <PR_NUMBER> --comments
```

## Workflow

1. **Create PR** → Auto creates PR with improvements
2. **Request Review** → Comment "@bugbot please review"
3. **Bugbot Analyzes** → Bugbot reviews code and posts findings
4. **Auto Responds** → Auto processes findings and implements fixes
5. **Iterate** → Continues until perfect

## Integration Methods

### GitHub Actions (Automatic)
- Location: `.github/workflows/auto-bugbot-collaboration.yml`
- Status: ✅ Active
- Triggers: PR events, comments, reviews

### Direct PR Comments
- Comment on PR: "@bugbot please review"
- Bugbot detects and responds automatically

### Graphite Integration
- Use Graphite CLI for stack-based reviews
- See `GITHUB_CLI_AND_BUGBOT_GUIDE.md` for details

## Documentation

- **GITHUB_CLI_AND_BUGBOT_GUIDE.md** - Complete CLI and bugbot guide
- **BUGBOT_INTEGRATION_STATUS.md** - Integration status
- **COLLABORATION_SUMMARY.md** - Collaboration summary

---

*For detailed information, see the root-level collaboration documentation files.*
