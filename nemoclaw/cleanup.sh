#!/bin/bash
set -e

# =============================================================================
# NemoClaw Cleanup
# =============================================================================
# Stops and removes the NemoClaw sandbox and gateway.
# Frees ports 8080 and 18789.
#
# Usage:
#   ./cleanup.sh [SANDBOX_NAME]
# =============================================================================

SANDBOX="${1:-huginn}"

echo "◇ Destroying sandbox '${SANDBOX}'..."
nemoclaw "$SANDBOX" destroy 2>/dev/null || echo "  Sandbox not found or already destroyed"

echo "◇ Stopping gateway..."
docker stop openshell-cluster-nemoclaw 2>/dev/null || true
docker rm openshell-cluster-nemoclaw 2>/dev/null || true

echo "◇ Killing any leftover port forwards..."
PID_18789=$(lsof -ti :18789 -sTCP:LISTEN 2>/dev/null || true)
if [ -n "$PID_18789" ]; then
    kill "$PID_18789" 2>/dev/null || true
fi

echo "✓ Cleanup complete"
