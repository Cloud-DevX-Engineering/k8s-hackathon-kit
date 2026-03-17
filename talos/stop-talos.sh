#!/bin/bash
# =============================================================================
# Stop Local Talos Cluster (WSL2)
# =============================================================================
# Kills the socat port-forward and stops the Talos Docker containers.
# Data is preserved — use start-talos.sh to resume.
#
# Usage:
#   chmod +x stop-talos.sh
#   ./stop-talos.sh
# =============================================================================

CLUSTER_NAME="local-talos"
EXPOSE_PORT=8080

echo ""
echo "🛑 Stopping Talos cluster: $CLUSTER_NAME"
echo "==========================================="
echo ""

# -----------------------------------------------------------------------------
# Kill port-forward
# -----------------------------------------------------------------------------
echo "🌐 Killing port-forward on :$EXPOSE_PORT..."
fuser -k ${EXPOSE_PORT}/tcp 2>/dev/null && echo "✅ Port-forward stopped" || echo "   (none running on :$EXPOSE_PORT)"
# Also kill any stray socat or kubectl port-forward processes
pkill -f "socat.*${EXPOSE_PORT}" 2>/dev/null || true
pkill -f "kubectl port-forward" 2>/dev/null || true

# -----------------------------------------------------------------------------
# Stop containers
# -----------------------------------------------------------------------------
if ! sudo docker info > /dev/null 2>&1; then
  echo "ℹ️  Docker not running — nothing to stop"
  exit 0
fi

CONTAINERS=$(sudo docker ps --filter "name=$CLUSTER_NAME" --format "{{.Names}}" 2>/dev/null)

if [ -z "$CONTAINERS" ]; then
  echo "ℹ️  No running containers found for '$CLUSTER_NAME'"
  exit 0
fi

echo "📦 Stopping containers:"
echo "$CONTAINERS" | while read c; do echo "   - $c"; done
echo "$CONTAINERS" | xargs sudo docker stop

echo ""
echo "==========================================="
echo "✅ Cluster stopped — data preserved"
echo "   Resume: ./start-talos.sh"
echo "==========================================="
