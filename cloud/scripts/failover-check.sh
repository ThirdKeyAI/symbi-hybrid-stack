#!/usr/bin/env bash
# failover-check.sh — Check desktop health; route to cloud if down
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# --- Load environment ---
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

if [ -f "$PROJECT_DIR/cloud/.env" ]; then
    set -a
    source "$PROJECT_DIR/cloud/.env"
    set +a
fi

HTTP_PORT="${SYMBI_HTTP_PORT:-8081}"
TOKEN="${SYMBI_AUTH_TOKEN:-}"
GCP_REGION="${GCP_REGION:-us-central1}"
MAX_RETRIES=3
RETRY_DELAY=5

echo "=== Failover Check ==="
echo ""

# --- Check desktop health ---
echo "Checking desktop coordinator..."
DESKTOP_HEALTHY=false

for i in $(seq 1 "$MAX_RETRIES"); do
    if curl -sf -o /dev/null \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        "http://localhost:${HTTP_PORT}/webhook" \
        -d '{"ping":true}' 2>/dev/null; then
        DESKTOP_HEALTHY=true
        break
    fi
    echo "  Attempt $i/$MAX_RETRIES failed, retrying in ${RETRY_DELAY}s..."
    sleep "$RETRY_DELAY"
done

if $DESKTOP_HEALTHY; then
    echo "  Desktop coordinator is healthy."
    echo ""
    echo "Status: DESKTOP_PRIMARY"
    echo "No failover needed."
    exit 0
fi

# --- Desktop is down — check cloud standby ---
echo "  Desktop coordinator is DOWN."
echo ""
echo "Checking cloud standby..."

CLOUD_URL="$(gcloud run services describe coordinator-standby \
    --region "$GCP_REGION" \
    --format='value(status.url)' 2>/dev/null || true)"

if [ -z "$CLOUD_URL" ]; then
    echo "  Error: Cloud standby service not found."
    echo "  Deploy with 'make cloud-deploy' first."
    echo ""
    echo "Status: ALL_DOWN"
    exit 1
fi

# Check cloud health
if curl -sf -o /dev/null \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    "${CLOUD_URL}/webhook" \
    -d '{"ping":true}' 2>/dev/null; then
    echo "  Cloud standby is healthy at: $CLOUD_URL"
    echo ""
    echo "Status: CLOUD_FAILOVER"
    echo "Route traffic to: $CLOUD_URL"
else
    echo "  Cloud standby is starting up (min-instances=0, may take a moment)..."
    echo ""
    echo "Status: CLOUD_STARTING"
    echo "URL: $CLOUD_URL"
fi
