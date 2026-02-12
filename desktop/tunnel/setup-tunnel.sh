#!/usr/bin/env bash
# setup-tunnel.sh — Set up Cloudflare Tunnel for zero-trust ingress
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# --- Load environment ---
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

# --- Check prerequisites ---
if ! command -v cloudflared &>/dev/null; then
    echo "Error: cloudflared not found."
    echo "Install from: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
    exit 1
fi

TUNNEL_TOKEN="${CLOUDFLARE_TUNNEL_TOKEN:-}"
CONFIG_FILE="$SCRIPT_DIR/config.yml"

# Kill orphaned cloudflared if interrupted before PID file is written
cleanup_tunnel() {
    if [ -n "${TUNNEL_PID:-}" ] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
        kill "$TUNNEL_PID" 2>/dev/null || true
    fi
}
trap cleanup_tunnel INT TERM

# --- Option 1: Token-based tunnel (recommended) ---
if [ -n "$TUNNEL_TOKEN" ]; then
    echo "Starting Cloudflare Tunnel with token..."
    cloudflared tunnel --no-autoupdate run --token "$TUNNEL_TOKEN" &
    TUNNEL_PID=$!
    echo "Tunnel started (PID: $TUNNEL_PID)"
    echo "$TUNNEL_PID" > "$PROJECT_DIR/.tunnel.pid"
    trap - INT TERM
    echo "Tunnel is running. Use 'kill $TUNNEL_PID' or 'make desktop-down' to stop."
    exit 0
fi

# --- Option 2: Config-file tunnel ---
if [ -f "$CONFIG_FILE" ]; then
    echo "Starting Cloudflare Tunnel with config..."
    cloudflared tunnel --no-autoupdate --config "$CONFIG_FILE" run &
    TUNNEL_PID=$!
    echo "Tunnel started (PID: $TUNNEL_PID)"
    echo "$TUNNEL_PID" > "$PROJECT_DIR/.tunnel.pid"
    trap - INT TERM
    echo "Tunnel is running. Use 'kill $TUNNEL_PID' or 'make desktop-down' to stop."
    exit 0
fi

# --- No tunnel config found ---
echo "No tunnel configuration found."
echo ""
echo "Option 1 (recommended): Set CLOUDFLARE_TUNNEL_TOKEN in .env"
echo "  1. Go to Cloudflare Zero Trust dashboard"
echo "  2. Create a tunnel"
echo "  3. Copy the token and add to .env:"
echo "     CLOUDFLARE_TUNNEL_TOKEN=your-token-here"
echo ""
echo "Option 2: Create a config file"
echo "  cp $SCRIPT_DIR/config.yml.example $CONFIG_FILE"
echo "  Edit $CONFIG_FILE with your tunnel settings"
exit 1
