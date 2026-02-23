#!/usr/bin/env bash
# healthcheck.sh — Check health of all desktop services
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# --- Load environment ---
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

HTTP_PORT="${SYMBI_HTTP_PORT:-8081}"
QDRANT_PORT="${QDRANT_PORT:-6333}"
A2UI_PORT="${A2UI_PORT:-3001}"
TOKEN="${SYMBI_AUTH_TOKEN:-}"

STATUS_OK=0
RESULTS=()

check_service() {
    local name="$1"
    shift
    local status

    if "$@" &>/dev/null; then
        status="healthy"
    else
        status="unhealthy"
        STATUS_OK=1
    fi

    RESULTS+=("{\"service\":\"$name\",\"status\":\"$status\"}")
    printf "  %-20s %s\n" "$name" "$status"
}

echo "=== Health Check ==="
echo ""

# Check Docker
check_service "docker" docker info

# Check Symbi container
check_service "symbi" bash -c "docker inspect --format='{{.State.Health.Status}}' symbi-coordinator 2>/dev/null | grep -q healthy"

# Check Symbi HTTP endpoint
if [ -n "$TOKEN" ]; then
    check_service "symbi-http" curl -sf -o /dev/null \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"ping":true}' \
        "http://localhost:${HTTP_PORT}/webhook"
else
    check_service "symbi-http" curl -sf -o /dev/null "http://localhost:${HTTP_PORT}/webhook"
fi

# Check Qdrant (only if container is running via --profile qdrant)
if docker inspect symbi-qdrant &>/dev/null; then
    check_service "qdrant" curl -sf "http://localhost:${QDRANT_PORT}/healthz"
else
    printf "  %-20s %s\n" "qdrant" "not configured (use --profile qdrant)"
fi

# Check Operations Console (static SPA)
check_service "a2ui" curl -sf -o /dev/null "http://localhost:${A2UI_PORT}/"

# Check a2ui API proxy (should reach symbi:8081 via extra_hosts + Caddyfile)
if curl -sf -o /dev/null "http://localhost:${A2UI_PORT}/" 2>/dev/null; then
    # Only check proxy if the SPA is up — avoids misleading "unhealthy" when a2ui is down
    if curl -sf -o /dev/null -w '' "http://localhost:${A2UI_PORT}/api/v1/health" 2>/dev/null; then
        printf "  %-20s %s\n" "a2ui-api-proxy" "healthy"
        RESULTS+=("{\"service\":\"a2ui-api-proxy\",\"status\":\"healthy\"}")
    else
        printf "  %-20s %s\n" "a2ui-api-proxy" "unreachable (symbi API may not serve /api/v1/*)"
        RESULTS+=("{\"service\":\"a2ui-api-proxy\",\"status\":\"warning\"}")
    fi
fi

# Check Litestream container (only if running via --profile replication)
if docker inspect symbi-litestream &>/dev/null; then
    check_service "litestream" bash -c "docker inspect --format='{{.State.Running}}' symbi-litestream 2>/dev/null | grep -q true"
else
    printf "  %-20s %s\n" "litestream" "not configured (use --profile replication)"
fi

# Check Cloudflare Tunnel (if configured)
if [ -f "$PROJECT_DIR/.tunnel.pid" ]; then
    TUNNEL_PID="$(cat "$PROJECT_DIR/.tunnel.pid")"
    check_service "tunnel" kill -0 "$TUNNEL_PID"
else
    printf "  %-20s %s\n" "tunnel" "not configured"
fi

echo ""

# Output JSON report
mkdir -p "$PROJECT_DIR/state"
JSON_REPORT="{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"overall\":\"$([ $STATUS_OK -eq 0 ] && echo healthy || echo unhealthy)\",\"services\":[$(IFS=,; echo "${RESULTS[*]}")]}"
echo "$JSON_REPORT" > "$PROJECT_DIR/state/health.json" 2>/dev/null || true

if [ $STATUS_OK -eq 0 ]; then
    echo "All services healthy."
else
    echo "Some services are unhealthy."
    exit 1
fi
