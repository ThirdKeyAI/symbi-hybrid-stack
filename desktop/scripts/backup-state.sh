#!/usr/bin/env bash
# backup-state.sh — Manual SQLite snapshot + GCS upload
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# --- Load environment ---
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

BUCKET="${GCS_STATE_BUCKET:-}"
TIMESTAMP="$(date -u +%Y%m%d_%H%M%S)"
BACKUP_DIR="$PROJECT_DIR/state/backups"
BACKUP_FILE="$BACKUP_DIR/symbi_${TIMESTAMP}.db"

mkdir -p "$BACKUP_DIR"

echo "=== Manual State Backup ==="
echo ""

# --- Snapshot SQLite from Docker volume ---
echo "Creating SQLite snapshot..."
docker cp symbi-coordinator:/var/lib/symbi/symbi.db "$BACKUP_FILE" 2>/dev/null || {
    echo "Error: Could not copy database from symbi container."
    echo "Is the desktop stack running? Try 'make desktop-up' first."
    exit 1
}

echo "  Snapshot: $BACKUP_FILE"
echo "  Size: $(du -h "$BACKUP_FILE" | cut -f1)"

# --- Upload to GCS if configured ---
if [ -n "$BUCKET" ]; then
    if ! command -v gsutil &>/dev/null; then
        echo ""
        echo "Warning: gsutil not found. Skipping GCS upload."
        echo "Install Google Cloud SDK to enable cloud backups."
    else
        echo ""
        echo "Uploading to GCS..."
        GCS_PATH="gs://${BUCKET}/backups/symbi_${TIMESTAMP}.db"
        gsutil cp "$BACKUP_FILE" "$GCS_PATH"
        echo "  Uploaded: $GCS_PATH"
    fi
else
    echo ""
    echo "GCS_STATE_BUCKET not set — local backup only."
    echo "Set GCS_STATE_BUCKET in .env to enable cloud backups."
fi

echo ""
echo "Backup complete."
