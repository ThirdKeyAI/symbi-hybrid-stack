#!/usr/bin/env bash
# keygen.sh — Generate AgentPin identity keys, credentials, and trust bundle
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
    # shellcheck source=/dev/null
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

KID="fleet-key-01"

echo "AgentPin Identity Generation"
echo "  Domain:     $DOMAIN"
echo "  Output dir: $OUTPUT_DIR"
echo "  Key ID:     $KID"
echo ""

# --- Create output directory ---
mkdir -p "$OUTPUT_DIR"

# --- Generate fleet keypair ---
echo "Generating fleet keypair..."
agentpin keygen \
    --kid "$KID" \
    --format both \
    --output-dir "$OUTPUT_DIR"

# --- Set restrictive permissions on private keys ---
chmod 0600 "$OUTPUT_DIR"/*.private.pem 2>/dev/null || true
chmod 0644 "$OUTPUT_DIR"/*.public.pem 2>/dev/null || true
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
            --private-key "$OUTPUT_DIR/${KID}.private.pem" \
            --kid "$KID" \
            --issuer "$DOMAIN" \
            --agent-id "$agent_name" \
            --capabilities "$(grep -oP 'capabilities\s*\[\K[^\]]+' "$dsl_file" 2>/dev/null | tr -d '"' | tr ',' ' ' || echo "")" \
            --ttl 8760h \
            > "$OUTPUT_DIR/${agent_name}.jwt" 2>/dev/null || \
            echo "  Warning: could not issue credential for $agent_name (agentpin issue may not be available)"
    done
fi

# --- Set permissions on credentials ---
chmod 0600 "$OUTPUT_DIR"/*.jwt 2>/dev/null || true

# --- Generate discovery document ---
DISCOVERY_FILE="$OUTPUT_DIR/discovery.json"
echo "Generating discovery document..."
agentpin discovery \
    --issuer "$DOMAIN" \
    --public-key "$OUTPUT_DIR/${KID}.public.pem" \
    --kid "$KID" \
    -o "$DISCOVERY_FILE" 2>/dev/null || \
    echo "Warning: could not generate discovery document (agentpin discovery may not be available)"

# --- Generate trust bundle ---
echo "Generating trust bundle..."
if [ -f "$DISCOVERY_FILE" ]; then
    agentpin bundle \
        --discovery "$DISCOVERY_FILE" \
        -o "$OUTPUT_DIR/trust-bundle.json" 2>/dev/null || \
        echo "Warning: could not generate trust bundle (agentpin bundle may not be available)"
else
    echo "Warning: skipping trust bundle — discovery document not available"
fi

chmod 0644 "$OUTPUT_DIR"/trust-bundle.json 2>/dev/null || true

# --- Initialize pin store (TOFU) ---
PIN_STORE="$OUTPUT_DIR/pin-store.json"
echo "Initializing TOFU pin store..."
if [ -f "$OUTPUT_DIR/trust-bundle.json" ]; then
    first_jwt=""
    for jwt_file in "$OUTPUT_DIR"/*.jwt; do
        [ -f "$jwt_file" ] || continue
        first_jwt="$jwt_file"
        break
    done
    if [ -n "$first_jwt" ]; then
        agentpin verify \
            --trust-bundle "$OUTPUT_DIR/trust-bundle.json" \
            --credential "$first_jwt" \
            --pin-store "$PIN_STORE" 2>/dev/null || \
            echo "Warning: could not seed pin store (agentpin verify may not be available)"
    fi
fi
chmod 0600 "$PIN_STORE" 2>/dev/null || true

# --- Create empty revocation document ---
REVOCATIONS_FILE="$OUTPUT_DIR/revocations.json"
echo "Creating empty revocation document..."
cat > "$REVOCATIONS_FILE" <<'REVEOF'
{
  "agentpin_revocations_version": "1.0.0",
  "issuer": "example.com",
  "updated_at": "1970-01-01T00:00:00Z",
  "revocations": []
}
REVEOF
# Patch issuer to match the configured domain
if command -v sed &>/dev/null; then
    sed -i "s/\"issuer\": \"example.com\"/\"issuer\": \"$DOMAIN\"/" "$REVOCATIONS_FILE"
fi
chmod 0644 "$REVOCATIONS_FILE" 2>/dev/null || true

echo ""
echo "Identity generation complete."
echo "  Fleet private key:  $OUTPUT_DIR/${KID}.private.pem"
echo "  Fleet public key:   $OUTPUT_DIR/${KID}.public.pem"
echo "  Discovery document: $DISCOVERY_FILE"
echo "  Trust bundle:       $OUTPUT_DIR/trust-bundle.json"
echo "  Pin store (TOFU):   $PIN_STORE"
echo "  Revocations:        $REVOCATIONS_FILE"
echo ""
echo "IMPORTANT: Keep private keys and pin store secure. Never commit them to git."
