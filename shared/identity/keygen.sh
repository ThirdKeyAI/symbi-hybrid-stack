#!/usr/bin/env bash
# keygen.sh — Generate AgentPin identity keys and trust bundle
# Usage: bash shared/identity/keygen.sh [--domain DOMAIN] [--output-dir DIR]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# --- Parse arguments ---
DOMAIN="${AGENTPIN_DOMAIN:-example.com}"
OUTPUT_DIR="${PROJECT_DIR}/secrets"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain) DOMAIN="$2"; shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# --- Load environment ---
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
    DOMAIN="${AGENTPIN_DOMAIN:-$DOMAIN}"
fi

# --- Check prerequisites ---
if ! command -v agentpin &>/dev/null; then
    echo "Error: agentpin CLI not found."
    echo "Install from: https://agentpin.org"
    exit 1
fi

echo "AgentPin Identity Generation"
echo "  Domain:     $DOMAIN"
echo "  Output dir: $OUTPUT_DIR"
echo ""

# --- Create output directory ---
mkdir -p "$OUTPUT_DIR"

# --- Generate fleet keypair ---
echo "Generating fleet keypair..."
agentpin keygen \
    --domain "$DOMAIN" \
    --kid fleet-key-01 \
    --output-dir "$OUTPUT_DIR"

# --- Set restrictive permissions on private keys ---
chmod 0600 "$OUTPUT_DIR"/*.jwk 2>/dev/null || true
chmod 0644 "$OUTPUT_DIR"/*.pub.jwk 2>/dev/null || true

# --- Issue per-agent credentials ---
AGENTS_DIR="$PROJECT_DIR/desktop/agents"
if [ -d "$AGENTS_DIR" ]; then
    for dsl_file in "$AGENTS_DIR"/*.dsl; do
        [ -f "$dsl_file" ] || continue
        agent_name="$(basename "$dsl_file" .dsl)"
        echo "Issuing credential for agent: $agent_name"
        agentpin issue \
            --key "$OUTPUT_DIR/fleet-key-01.jwk" \
            --agent-id "$agent_name" \
            --domain "$DOMAIN" \
            --output "$OUTPUT_DIR/${agent_name}.jwt" 2>/dev/null || \
            echo "  Warning: could not issue credential for $agent_name (agentpin issue may not be available)"
    done
fi

# --- Generate trust bundle ---
echo "Generating trust bundle..."
agentpin bundle \
    --key "$OUTPUT_DIR/fleet-key-01.jwk" \
    --domain "$DOMAIN" \
    --output "$OUTPUT_DIR/trust-bundle.json" 2>/dev/null || \
    echo "Warning: could not generate trust bundle (agentpin bundle may not be available)"

# --- Set permissions on generated files ---
chmod 0600 "$OUTPUT_DIR"/*.jwt 2>/dev/null || true
chmod 0644 "$OUTPUT_DIR"/trust-bundle.json 2>/dev/null || true

echo ""
echo "Identity generation complete."
echo "  Fleet key:    $OUTPUT_DIR/fleet-key-01.jwk"
echo "  Trust bundle: $OUTPUT_DIR/trust-bundle.json"
echo ""
echo "IMPORTANT: Keep private keys secure. Never commit them to git."
