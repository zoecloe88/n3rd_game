#!/bin/bash

# Complete backup script (Firestore + Storage)
# Runs all backup procedures

set -e

echo "🚀 Starting complete backup process..."
echo "========================================"

# Run Firestore backup
echo ""
echo "1. Backing up Firestore..."
bash scripts/backup_firestore.sh

# Run Storage backup
echo ""
echo "2. Backing up Storage..."
bash scripts/backup_storage.sh

echo ""
echo "========================================"
echo "✅ Complete backup finished successfully"

















