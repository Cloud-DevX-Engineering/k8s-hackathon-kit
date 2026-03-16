#!/bin/bash
# =============================================================================
# Start Local Talos Cluster (WSL2)
# =============================================================================
# Starts the local-talos Docker-provisioned cluster.
# If the cluster doesn't exist yet, run install-talos.sh first.
#
# Usage:
#   chmod +x start-talos.sh
#   ./start-talos.sh
# =============================================================================

set -e

CLUSTER_NAME="local-talos"
KUBECONFIG="/home/openclaw/.kube/config"
KUBECTL="/snap/bin/kubectl"

echo ""
echo "🚀 Starting Talos cluster: $CLUSTER_NAME"
echo "==========================================="
echo ""

# -----------------------------------------------------------------------------
# Check Docker
# -----------------------------------------------------------------------------
if ! docker info > /dev/null 2>&1; then
  echo "❌ Docker is not running. Starting it..."
  sudo systemctl start docker
  sleep 3
fi
echo "✅ Docker is running"

# -----------------------------------------------------------------------------
# Check if containers already exist (cluster was previously created)
# -----------------------------------------------------------------------------
EXISTING=$(docker ps -a --filter "name=$CLUSTER_NAME" --format "{{.Names}}" 2>/dev/null)

if [ -n "$EXISTING" ]; then
  echo "📦 Found existing cluster containers — starting them..."
  docker ps -a --filter "name=$CLUSTER_NAME" --format "{{.Names}}" | xargs -r docker start
  echo "✅ Containers started"
else
  echo "⚠️  No existing cluster found. Creating a new one..."
  sudo -u openclaw sudo -E talosctl cluster create docker --name "$CLUSTER_NAME"
fi

# -----------------------------------------------------------------------------
# Wait for nodes to be ready
# -----------------------------------------------------------------------------
echo ""
echo "⏳ Waiting for nodes to become ready..."
sleep 10

for i in {1..12}; do
  if KUBECONFIG="$KUBECONFIG" $KUBECTL get nodes 2>/dev/null | grep -q "Ready"; then
    break
  fi
  echo "   Still waiting... ($i/12)"
  sleep 5
done

# -----------------------------------------------------------------------------
# Status
# -----------------------------------------------------------------------------
echo ""
echo "🔍 Cluster status:"
KUBECONFIG="$KUBECONFIG" $KUBECTL get nodes 2>/dev/null || echo "⚠️  kubectl not responding yet — try again in a moment"

echo ""
echo "==========================================="
echo "✅ Talos cluster '$CLUSTER_NAME' is running"
echo ""
echo "  Check nodes:    KUBECONFIG=$KUBECONFIG kubectl get nodes"
echo "  Check pods:     KUBECONFIG=$KUBECONFIG kubectl get pods -A"
echo "  Stop cluster:   ./stop-talos.sh"
echo "==========================================="
