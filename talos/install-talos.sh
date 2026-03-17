#!/bin/bash
# =============================================================================
# Talos Local Cluster — Install Script (WSL2)
# =============================================================================
# Installs talosctl + kubectl and creates a local Talos cluster via Docker.
#
# Prerequisites:
#   - Docker must be running (sudo service docker start)
#   - Run this script once; use start-talos.sh / stop-talos.sh day-to-day
#
# Usage:
#   chmod +x install-talos.sh
#   ./install-talos.sh
# =============================================================================

set -e

CLUSTER_NAME="local-talos"

echo ""
echo "⚙️  Talos Local Cluster Installer (WSL2)"
echo "==========================================="
echo ""

# -----------------------------------------------------------------------------
# STEP 1: Docker
# -----------------------------------------------------------------------------
echo "🔍 Checking Docker..."
if ! sudo docker info > /dev/null 2>&1; then
  echo "   Docker not running — starting it..."
  sudo service docker start
  sleep 3
fi
if ! sudo docker info > /dev/null 2>&1; then
  echo "❌ Could not start Docker. Install it with:"
  echo "   curl -fsSL https://get.docker.com | sudo sh"
  exit 1
fi
echo "✅ Docker is running"

# -----------------------------------------------------------------------------
# STEP 2: talosctl
# -----------------------------------------------------------------------------
if command -v talosctl &>/dev/null; then
  echo "✅ talosctl already installed: $(talosctl version --client 2>/dev/null | grep Tag | awk '{print $2}')"
else
  echo ""
  echo "📦 Installing talosctl..."
  curl -sL https://talos.dev/install | sudo sh
  echo "✅ talosctl installed"
fi

# -----------------------------------------------------------------------------
# STEP 3: kubectl
# -----------------------------------------------------------------------------
if command -v kubectl &>/dev/null; then
  echo "✅ kubectl already installed: $(kubectl version --client 2>/dev/null | head -1)"
else
  echo ""
  echo "📦 Installing kubectl..."
  KUBE_VER=$(curl -Ls https://dl.k8s.io/release/stable.txt)
  curl -LO "https://dl.k8s.io/release/${KUBE_VER}/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm kubectl
  echo "✅ kubectl installed"
fi

# -----------------------------------------------------------------------------
# STEP 4: Create cluster
# -----------------------------------------------------------------------------
echo ""
echo "🚀 Creating Talos cluster: $CLUSTER_NAME"
echo "   (Pulls ~500MB of images on first run — grab a coffee)"
echo ""

sudo -E talosctl cluster create docker --name "$CLUSTER_NAME" --workers 1

# -----------------------------------------------------------------------------
# STEP 5: kubeconfig
# -----------------------------------------------------------------------------
mkdir -p "$HOME/.kube"
cp /root/.kube/config "$HOME/.kube/config" 2>/dev/null || true

# -----------------------------------------------------------------------------
# STEP 6: Verify
# -----------------------------------------------------------------------------
echo ""
echo "🔍 Verifying cluster..."
for i in {1..12}; do
  if kubectl get nodes 2>/dev/null | grep -q "Ready"; then
    break
  fi
  echo "   Waiting for nodes... ($i/12)"
  sleep 5
done

echo ""
kubectl get nodes
echo ""
echo "==========================================="
echo "✅ Cluster '$CLUSTER_NAME' is ready!"
echo ""
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  talosctl config info"
echo "  ./stop-talos.sh"
echo "==========================================="
