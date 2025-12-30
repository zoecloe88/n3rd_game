#!/bin/bash

# Firestore backup script
# Runs daily via cron or CI/CD to backup Firestore database

set -e

PROJECT_ID="wordn3rd-7bd5d"
BACKUP_BUCKET="gs://wordn3rd-7bd5d-backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_BUCKET/firestore/$DATE"

echo "🔥 Starting Firestore backup: $DATE"
echo "Project: $PROJECT_ID"
echo "Backup path: $BACKUP_PATH"

# Check if gcloud is available
if ! command -v gcloud &> /dev/null; then
    echo "❌ Error: gcloud CLI not found. Please install Google Cloud SDK."
    exit 1
fi

# Check if project is set
if [ -z "$PROJECT_ID" ]; then
    echo "❌ Error: PROJECT_ID not set"
    exit 1
fi

# Export Firestore
echo "📦 Exporting Firestore database..."
gcloud firestore export "$BACKUP_PATH" \
  --project="$PROJECT_ID" \
  --async

if [ $? -eq 0 ]; then
    echo "✅ Firestore backup initiated: $DATE"
    echo "📋 Monitor backup status:"
    echo "   gcloud firestore operations list --project=$PROJECT_ID"
else
    echo "❌ Firestore backup failed"
    exit 1
fi

echo "✅ Backup process completed"














