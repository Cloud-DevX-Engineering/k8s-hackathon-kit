#!/bin/bash
set -e

# =============================================================================
# NemoClaw Setup Script
# =============================================================================
# Installs NemoClaw, creates a sandbox, and configures inference.
#
# Prerequisites:
#   - WSL2 with Docker running
#   - Node.js installed (for nemoclaw CLI)
#
# Usage:
#   ./setup-nemoclaw.sh
#
# You will be prompted for:
#   - NVIDIA API key (for initial onboard, get from https://build.nvidia.com/settings/api-keys)
# =============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "  NemoClaw Setup"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ── Step 1: Install nemoclaw CLI ──
if ! command -v nemoclaw &>/dev/null; then
    echo "◇ Installing NemoClaw CLI..."
    curl -fsSL https://nvidia.com/nemoclaw.sh | bash
    source ~/.bashrc
else
    echo "✓ NemoClaw CLI already installed: $(which nemoclaw)"
fi

# ── Step 2: Kill anything on required ports ──
echo "◇ Checking ports 8080 and 18789..."

# Port 8080 - OpenShell gateway
CONTAINER=$(docker ps --format '{{.Names}}' --filter "publish=8080" 2>/dev/null || true)
if [ -n "$CONTAINER" ]; then
    echo "  Stopping container on port 8080: $CONTAINER"
    docker stop "$CONTAINER" && docker rm "$CONTAINER" 2>/dev/null
fi

# Port 18789 - Dashboard
PID_18789=$(lsof -ti :18789 -sTCP:LISTEN 2>/dev/null || true)
if [ -n "$PID_18789" ]; then
    echo "  Killing process on port 18789 (PID $PID_18789)"
    kill "$PID_18789" 2>/dev/null || true
fi

echo "✓ Ports are free"

# ── Step 3: Run onboard ──
echo ""
echo "◇ Starting NemoClaw onboard wizard..."
echo "  You will need an NVIDIA API key (nvapi-...) for the initial setup."
echo "  Get one at: https://build.nvidia.com/settings/api-keys"
echo ""
nemoclaw onboard
