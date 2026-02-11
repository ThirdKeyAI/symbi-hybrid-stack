#!/usr/bin/env bash
# install.sh — Quick Start installer for symbi-hybrid-stack
#
# Usage:
#   curl -fsSL https://symbiont.dev/install.sh | bash
#   curl -fsSL https://symbiont.dev/install.sh | bash -s -- --no-start
#   curl -fsSL https://symbiont.dev/install.sh | bash -s -- --dir ~/my-fleet
#
set -euo pipefail

# --- Defaults ---
INSTALL_DIR="./symbi-hybrid-stack"
REPO_URL="https://github.com/thirdkeyai/symbi-hybrid-stack.git"
AUTO_START=true

# --- Colors (if terminal supports them) ---
if [ -t 1 ]; then
    BOLD="\033[1m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    RED="\033[31m"
    RESET="\033[0m"
else
    BOLD="" GREEN="" YELLOW="" RED="" RESET=""
fi

info()  { echo -e "${BOLD}${GREEN}>>>${RESET} $*"; }
warn()  { echo -e "${BOLD}${YELLOW}>>>${RESET} $*"; }
error() { echo -e "${BOLD}${RED}>>>${RESET} $*" >&2; }

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)       INSTALL_DIR="$2"; shift 2 ;;
        --no-start)  AUTO_START=false; shift ;;
        --help|-h)
            echo "Usage: curl -fsSL https://symbiont.dev/install.sh | bash"
            echo ""
            echo "Options (pass via: bash -s -- <options>):"
            echo "  --dir DIR      Install directory (default: ./symbi-hybrid-stack)"
            echo "  --no-start     Clone and configure only, don't start services"
            echo "  --help         Show this help"
            exit 0
            ;;
        *) error "Unknown option: $1"; exit 1 ;;
    esac
done

# --- Banner ---
echo ""
echo -e "${BOLD}  ┌─────────────────────────────────────────┐${RESET}"
echo -e "${BOLD}  │     symbi-hybrid-stack quick start       │${RESET}"
echo -e "${BOLD}  │     Zero to agent fleet in 5 minutes     │${RESET}"
echo -e "${BOLD}  └─────────────────────────────────────────┘${RESET}"
echo ""

# --- Check prerequisites ---
info "Checking prerequisites..."

MISSING=""

if ! command -v git &>/dev/null; then
    MISSING="${MISSING}  - git (https://git-scm.com)\n"
fi

if ! command -v docker &>/dev/null; then
    MISSING="${MISSING}  - docker (https://docs.docker.com/get-docker/)\n"
fi

if command -v docker &>/dev/null && ! docker compose version &>/dev/null 2>&1; then
    MISSING="${MISSING}  - docker compose v2 (https://docs.docker.com/compose/install/)\n"
fi

if ! command -v openssl &>/dev/null; then
    MISSING="${MISSING}  - openssl (for token generation)\n"
fi

if [ -n "$MISSING" ]; then
    error "Missing required tools:"
    echo -e "$MISSING"
    exit 1
fi

echo "  git:     $(git --version | head -c 20)"
echo "  docker:  $(docker --version | head -c 30)"
echo "  compose: $(docker compose version | head -c 30)"
echo ""

# --- Clone repo ---
if [ -d "$INSTALL_DIR" ]; then
    warn "Directory $INSTALL_DIR already exists."
    if [ -d "$INSTALL_DIR/.git" ]; then
        info "Pulling latest changes..."
        git -C "$INSTALL_DIR" pull --quiet
    else
        error "$INSTALL_DIR exists but is not a git repo. Remove it or use --dir to pick another location."
        exit 1
    fi
else
    info "Cloning symbi-hybrid-stack..."
    git clone --quiet "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"
info "Working in: $(pwd)"
echo ""

# --- Create .env ---
if [ ! -f .env ]; then
    info "Creating .env from template..."
    cp .env.example .env

    # Generate auth token
    TOKEN="symbi_$(openssl rand -hex 24)"
    sed -i "s|^SYMBI_AUTH_TOKEN=.*|SYMBI_AUTH_TOKEN=${TOKEN}|" .env 2>/dev/null || \
        sed -i '' "s|^SYMBI_AUTH_TOKEN=.*|SYMBI_AUTH_TOKEN=${TOKEN}|" .env
    info "Generated auth token."
else
    info ".env already exists, keeping your config."
fi

echo ""

# --- Prompt for LLM API key ---
# shellcheck disable=SC1091
set -a; source .env; set +a

HAS_KEY=false
if [ -n "${OPENROUTER_API_KEY:-}" ] && [ "$OPENROUTER_API_KEY" != "your_openrouter_key_here" ]; then
    HAS_KEY=true
fi
if [ -n "${OPENAI_API_KEY:-}" ]; then HAS_KEY=true; fi
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then HAS_KEY=true; fi

if ! $HAS_KEY; then
    warn "No LLM API key detected."
    echo ""
    echo "  Your agents need an LLM provider. Paste an API key now, or"
    echo "  edit .env later. Supported providers:"
    echo ""
    echo "    1) OpenRouter (recommended — multi-model access)"
    echo "    2) OpenAI"
    echo "    3) Anthropic"
    echo "    s) Skip for now"
    echo ""

    if [ -t 0 ]; then
        read -rp "  Choice [1/2/3/s]: " CHOICE
        case "$CHOICE" in
            1)
                read -rp "  OpenRouter API key: " KEY
                sed -i "s|^OPENROUTER_API_KEY=.*|OPENROUTER_API_KEY=${KEY}|" .env 2>/dev/null || \
                    sed -i '' "s|^OPENROUTER_API_KEY=.*|OPENROUTER_API_KEY=${KEY}|" .env
                info "Saved OpenRouter key."
                ;;
            2)
                read -rp "  OpenAI API key: " KEY
                # Uncomment and set
                sed -i "s|^# OPENAI_API_KEY=.*|OPENAI_API_KEY=${KEY}|" .env 2>/dev/null || \
                    sed -i '' "s|^# OPENAI_API_KEY=.*|OPENAI_API_KEY=${KEY}|" .env
                info "Saved OpenAI key."
                ;;
            3)
                read -rp "  Anthropic API key: " KEY
                sed -i "s|^# ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=${KEY}|" .env 2>/dev/null || \
                    sed -i '' "s|^# ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=${KEY}|" .env
                info "Saved Anthropic key."
                ;;
            *)
                warn "Skipped. Edit .env with your API key before using the fleet."
                ;;
        esac
    else
        warn "Non-interactive shell — edit .env with your API key before using the fleet."
    fi
    echo ""
fi

# --- Pull images ---
info "Pulling Docker images (this may take a minute)..."
set -a; source .env; set +a
docker compose -f desktop/docker-compose.yml pull --quiet
info "Images ready."
echo ""

# --- Start services ---
if $AUTO_START; then
    info "Starting desktop stack..."
    docker compose -f desktop/docker-compose.yml up -d

    echo ""
    info "Waiting for services..."
    READY=false
    for _i in $(seq 1 30); do
        if docker inspect --format='{{.State.Health.Status}}' symbi-coordinator 2>/dev/null | grep -q healthy; then
            READY=true
            break
        fi
        sleep 2
    done

    if $READY; then
        info "All services healthy."
    else
        warn "Services are starting — they may need another moment."
        echo "  Run 'make verify' to check status."
    fi
fi

# --- Done ---
echo ""
echo -e "${BOLD}${GREEN}  ✓ symbi-hybrid-stack is ready!${RESET}"
echo ""
echo "  Your agent fleet is running at: http://localhost:8081"
echo ""
echo "  Next steps:"
if ! $HAS_KEY; then
    echo "    1. Add your LLM API key:  \$EDITOR $INSTALL_DIR/.env"
    echo "    2. Restart:               cd $INSTALL_DIR && make desktop-down && make desktop-up"
    echo "    3. Verify:                 make verify"
else
    echo "    1. Verify:                 cd $INSTALL_DIR && make verify"
    echo "    2. View logs:              make logs"
    echo "    3. Add cloud failover:     See README.md"
fi
echo ""
echo "  Docs:     https://github.com/thirdkeyai/symbi-hybrid-stack"
echo "  Support:  https://thirdkey.ai"
echo ""
