#!/bin/bash
# =============================================================================
# Start Local Talos Cluster (WSL2)
# =============================================================================
# Starts dockerd, resumes Talos containers, waits for Ready, and restores
# the socat port-forward so the webapp is accessible at http://localhost:8080
#
# Usage:
#   chmod +x start-talos.sh
#   ./start-talos.sh
# =============================================================================

set -e

CLUSTER_NAME="local-talos"
EXPOSE_PORT=8080          # Windows-accessible port
NODEPORT=30090            # nginx-lb NodePort inside cluster

echo ""
echo "🚀 Starting Talos cluster: $CLUSTER_NAME"
echo "==========================================="
echo ""

# -----------------------------------------------------------------------------
# STEP 1: Ensure dockerd is running
# -----------------------------------------------------------------------------
if ! sudo docker info > /dev/null 2>&1; then
  echo "🐳 Starting dockerd..."
  sudo dockerd --host=unix:///var/run/docker.sock &>/tmp/dockerd.log &
  for i in {1..10}; do
    sleep 2
    sudo docker info > /dev/null 2>&1 && break
    echo "   Waiting for dockerd... ($i/10)"
  done
fi

if ! sudo docker info > /dev/null 2>&1; then
  echo "❌ dockerd failed to start. Check /tmp/dockerd.log"
  exit 1
fi
echo "✅ Docker is running"

# -----------------------------------------------------------------------------
# STEP 2: Start cluster containers
# -----------------------------------------------------------------------------
EXISTING=$(sudo docker ps -a --filter "name=$CLUSTER_NAME" --format "{{.Names}}" 2>/dev/null)

if [ -n "$EXISTING" ]; then
  echo "📦 Resuming existing cluster containers..."
  sudo docker ps -a --filter "name=$CLUSTER_NAME" --format "{{.Names}}" | xargs sudo docker start 2>/dev/null || true
else
  echo "⚠️  No existing cluster found — run install-talos.sh first"
  exit 1
fi

# -----------------------------------------------------------------------------
# STEP 3: Wait for nodes Ready
# -----------------------------------------------------------------------------
echo ""
echo "⏳ Waiting for nodes to become Ready..."
for i in {1..30}; do
  if kubectl get nodes 2>/dev/null | grep -v "NotReady" | grep -q "Ready"; then
    break
  fi
  echo "   ($i/30) waiting..."
  sleep 5
done

# Uncordon worker nodes — they come back cordoned after a container restart
kubectl uncordon -l '!node-role.kubernetes.io/control-plane' 2>/dev/null || true

# Wait for worker to flip to Ready after uncordon
for i in {1..12}; do
  NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -v "control-plane" | grep "NotReady" | wc -l)
  [ "$NOT_READY" -eq 0 ] && break
  echo "   Waiting for worker Ready after uncordon... ($i/12)"
  sleep 5
done

echo ""
kubectl get nodes

# -----------------------------------------------------------------------------
# STEP 4: Restore socat port-forward (Windows access)
# -----------------------------------------------------------------------------
echo ""
echo "🌐 Restoring port-forward on :$EXPOSE_PORT..."

# Ensure socat is installed
if ! command -v socat &>/dev/null; then
  echo "   Installing socat..."
  sudo apt-get install -y socat -qq 2>/dev/null
fi

# Kill any existing forwarders on this port
fuser -k ${EXPOSE_PORT}/tcp 2>/dev/null || true
sleep 1

WORKER_IP=$(sudo docker inspect ${CLUSTER_NAME}-worker-1 \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null)

if [ -z "$WORKER_IP" ]; then
  echo "⚠️  Could not determine worker IP — skipping port-forward"
else
  socat TCP-LISTEN:${EXPOSE_PORT},bind=0.0.0.0,fork,reuseaddr TCP:${WORKER_IP}:${NODEPORT} &
  sleep 2
  if curl -s http://localhost:${EXPOSE_PORT} > /dev/null 2>&1; then
    echo "✅ Port-forward active: http://localhost:${EXPOSE_PORT} → $WORKER_IP:${NODEPORT}"
  else
    echo "⚠️  Port-forward started but app may still be warming up"
  fi
fi

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo "==========================================="
echo "✅ Cluster '$CLUSTER_NAME' is running"
echo ""
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  🌐 http://localhost:${EXPOSE_PORT}"
echo ""
echo "  Stop:    ./stop-talos.sh"
echo "  Destroy: sudo -E talosctl cluster destroy docker --name $CLUSTER_NAME"
echo "==========================================="
