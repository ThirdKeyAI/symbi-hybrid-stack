#!/usr/bin/env bash
# init.sh — First-run setup for the desktop stack
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$PROJECT_DIR"

echo "=== symbi-hybrid-stack: First-Run Setup ==="
echo ""

# --- Check prerequisites ---
echo "Checking prerequisites..."

MISSING=""

if ! command -v docker &>/dev/null; then
    MISSING="${MISSING}  - docker\n"
fi

if ! docker compose version &>/dev/null 2>&1; then
    MISSING="${MISSING}  - docker compose v2\n"
fi

if [ -n "$MISSING" ]; then
    echo "Error: Missing required tools:"
    echo -e "$MISSING"
    exit 1
fi

echo "  Docker: $(docker --version | head -1)"
echo "  Compose: $(docker compose version | head -1)"

if command -v agentpin &>/dev/null; then
    echo "  AgentPin: $(agentpin --version 2>/dev/null || echo 'available')"
else
    echo "  AgentPin: not found (keygen will be skipped)"
fi

echo ""

# --- Copy .env if missing ---
if [ ! -f .env ]; then
    echo "Creating .env from template..."
    cp .env.example .env
    echo "  Created .env — edit it with your API keys."
else
    echo ".env already exists, skipping."
fi

# --- Generate auth token if empty ---
set -a
source .env
set +a

if [ -z "${SYMBI_AUTH_TOKEN:-}" ]; then
    echo "Generating SYMBI_AUTH_TOKEN..."
    TOKEN="symbi_$(openssl rand -hex 24)"
    # Append token to .env
    if grep -q "^SYMBI_AUTH_TOKEN=" .env; then
        sed -i "s|^SYMBI_AUTH_TOKEN=.*|SYMBI_AUTH_TOKEN=${TOKEN}|" .env 2>/dev/null || sed -i '' "s|^SYMBI_AUTH_TOKEN=.*|SYMBI_AUTH_TOKEN=${TOKEN}|" .env
    else
        echo "SYMBI_AUTH_TOKEN=${TOKEN}" >> .env
    fi
    echo "  Token generated and saved to .env"
else
    echo "SYMBI_AUTH_TOKEN already set."
fi

echo ""

# --- Pull Docker images ---
echo "Pulling Docker images..."
docker compose -f desktop/docker-compose.yml pull
echo ""

# --- Generate AgentPin keys ---
if command -v agentpin &>/dev/null; then
    echo "Generating AgentPin identity keys..."
    bash shared/identity/keygen.sh
    echo ""
else
    echo "Skipping AgentPin keygen (agentpin CLI not found)."
    echo "Install from https://agentpin.org and run 'make keygen' later."
    echo ""
fi

# --- Create required directories ---
mkdir -p logs state

# --- Start the stack ---
echo "Starting desktop stack..."
set -a
source .env
set +a
docker compose -f desktop/docker-compose.yml up -d

echo ""
echo "Waiting for services to be healthy..."
bash desktop/scripts/healthcheck.sh || true

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit .env with your LLM API key"
echo "  2. Run 'make verify' to check health"
echo "  3. Send requests to http://localhost:8081/webhook"
echo ""
echo "See README.md for more details."
