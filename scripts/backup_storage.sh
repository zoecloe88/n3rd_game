#!/bin/bash

# Firebase Storage backup script
# Backs up user-uploaded content and application assets

set -e

STORAGE_BUCKET="wordn3rd-7bd5d.firebasestorage.app"
BACKUP_BUCKET="gs://wordn3rd-7bd5d-backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_BUCKET/storage/$DATE"

echo "📦 Starting Storage backup: $DATE"
echo "Source: $STORAGE_BUCKET"
echo "Backup path: $BACKUP_PATH"

# Check if gsutil is available
if ! command -v gsutil &> /dev/null; then
    echo "❌ Error: gsutil not found. Please install Google Cloud SDK."
    exit 1
fi

# Backup storage
echo "📦 Backing up Firebase Storage..."
gsutil -m cp -r "gs://$STORAGE_BUCKET" "$BACKUP_PATH"

if [ $? -eq 0 ]; then
    echo "✅ Storage backup completed: $DATE"
else
    echo "❌ Storage backup failed"
    exit 1
fi

echo "✅ Backup process completed"

















