#!/bin/bash
# =============================================================================
# Stop Local Talos Cluster (WSL2)
# =============================================================================
# Gracefully stops the local-talos Docker-provisioned cluster.
# Containers are stopped but NOT removed — use start-talos.sh to resume.
#
# Usage:
#   chmod +x stop-talos.sh
#   ./stop-talos.sh
#
# To fully destroy the cluster (removes all data):
#   sudo -u openclaw sudo -E talosctl cluster destroy docker --name local-talos
# =============================================================================

CLUSTER_NAME="local-talos"

echo ""
echo "🛑 Stopping Talos cluster: $CLUSTER_NAME"
echo "==========================================="
echo ""

# -----------------------------------------------------------------------------
# Check Docker
# -----------------------------------------------------------------------------
if ! docker info > /dev/null 2>&1; then
  echo "❌ Docker is not running — nothing to stop"
  exit 0
fi

# -----------------------------------------------------------------------------
# Find and stop cluster containers
# -----------------------------------------------------------------------------
CONTAINERS=$(docker ps --filter "name=$CLUSTER_NAME" --format "{{.Names}}" 2>/dev/null)

if [ -z "$CONTAINERS" ]; then
  echo "ℹ️  No running containers found for cluster '$CLUSTER_NAME'"
  echo "   The cluster may already be stopped."
  exit 0
fi

echo "📦 Stopping containers:"
echo "$CONTAINERS" | while read c; do echo "   - $c"; done
echo ""

echo "$CONTAINERS" | xargs -r docker stop

echo ""
echo "==========================================="
echo "✅ Talos cluster '$CLUSTER_NAME' stopped"
echo ""
echo "  Containers are preserved — data is safe"
echo "  Resume with:  ./start-talos.sh"
echo "  Destroy all:  sudo -u openclaw sudo -E talosctl cluster destroy docker --name $CLUSTER_NAME"
echo "==========================================="
