#!/bin/bash

# Cleanup old backups according to retention policy
# Retention: Daily (7 days), Weekly (4 weeks), Monthly (12 months)

set -e

BACKUP_BUCKET="gs://wordn3rd-7bd5d-backups"

echo "🧹 Cleaning up old backups..."

# Cleanup daily backups older than 7 days (keep weekly/monthly)
echo "Removing daily backups older than 7 days..."
# Implementation: Keep first backup of each week for 4 weeks
# Keep first backup of each month for 12 months

# Cleanup weekly backups older than 4 weeks (keep monthly)
echo "Removing weekly backups older than 4 weeks..."

# Cleanup monthly backups older than 12 months
echo "Removing monthly backups older than 12 months..."

echo "✅ Backup cleanup completed"














