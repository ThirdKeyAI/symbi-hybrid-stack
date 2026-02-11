#!/usr/bin/env bash
# stop.sh — Graceful shutdown of the desktop stack
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo "=== Stopping Desktop Stack ==="
echo ""

# --- Stop Cloudflare Tunnel ---
if [ -f "$PROJECT_DIR/.tunnel.pid" ]; then
    TUNNEL_PID="$(cat "$PROJECT_DIR/.tunnel.pid")"
    if kill -0 "$TUNNEL_PID" 2>/dev/null; then
        echo "Stopping Cloudflare Tunnel (PID: $TUNNEL_PID)..."
        kill "$TUNNEL_PID" 2>/dev/null || true
        wait "$TUNNEL_PID" 2>/dev/null || true
    fi
    rm -f "$PROJECT_DIR/.tunnel.pid"
fi

# --- Stop Docker Compose ---
echo "Stopping Docker Compose services..."
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

docker compose -f "$PROJECT_DIR/desktop/docker-compose.yml" down

echo ""
echo "Desktop stack stopped."
