#!/bin/bash
# cleanup_unused_videos.sh - Remove unused video files to save space

cd "$(dirname "$0")"

echo "🧹 Cleaning up unused video files..."
echo ""

VIDEOS_DIR="assets/videos"
SPACE_BEFORE=$(du -sh "$VIDEOS_DIR" 2>/dev/null | awk '{print $1}')

echo "📊 Videos folder size before: $SPACE_BEFORE"
echo ""

# List of unused video base names (without variants)
UNUSED_VIDEOS=(
  "gameplay_video"
  "logo_video"
  "stats_video"
)

DELETED_COUNT=0
DELETED_SIZE=0

echo "🗑️  Removing unused videos and their variants:"
echo ""

for video in "${UNUSED_VIDEOS[@]}"; do
  # Delete all variants (base, standard, tall, extra_tall)
  for variant in "" "_standard" "_tall" "_extra_tall"; do
    file="${video}${variant}.mp4"
    filepath="${VIDEOS_DIR}/${file}"
    
    if [ -f "$filepath" ]; then
      size=$(du -h "$filepath" 2>/dev/null | awk '{print $1}')
      echo "  Deleting: $file ($size)"
      rm -f "$filepath"
      if [ $? -eq 0 ]; then
        DELETED_COUNT=$((DELETED_COUNT + 1))
      fi
    fi
  done
done

echo ""
SPACE_AFTER=$(du -sh "$VIDEOS_DIR" 2>/dev/null | awk '{print $1}')

echo "✅ Cleanup complete!"
echo ""
echo "📊 Summary:"
echo "  - Deleted files: $DELETED_COUNT"
echo "  - Size before: $SPACE_BEFORE"
echo "  - Size after: $SPACE_AFTER"
echo ""
echo "📋 Remaining videos:"
find "$VIDEOS_DIR" -name "*.mp4" -type f | wc -l | xargs echo "  Total files:"
echo ""
echo "💡 Note: All video variants (standard/tall/extra_tall) are kept for responsive design."

