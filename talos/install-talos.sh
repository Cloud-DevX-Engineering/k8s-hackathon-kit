#!/bin/bash
# =============================================================================
# Talos Local Cluster Install Script for WSL2 Ubuntu
# =============================================================================
# Installs talosctl, kubectl and creates a local Talos cluster using the
# Docker provisioner.
#
# Prerequisites:
#   - Docker must be running (sudo systemctl start docker)
#   - User must be in the docker group (sudo usermod -aG docker $USER)
#
# Usage:
#   chmod +x install-talos.sh
#   ./install-talos.sh
# =============================================================================

set -e

CLUSTER_NAME="local-talos"

echo ""
echo "⚙️  Talos Local Cluster Installer for WSL2"
echo "==========================================="
echo ""

# -----------------------------------------------------------------------------
# STEP 1: Check Docker
# -----------------------------------------------------------------------------
echo "🔍 Checking Docker..."
if ! docker info > /dev/null 2>&1; then
  echo "❌ Docker is not running. Start it with:"
  echo "   sudo systemctl start docker"
  exit 1
fi
echo "✅ Docker is running"

# -----------------------------------------------------------------------------
# STEP 2: Install talosctl
# -----------------------------------------------------------------------------
if command -v talosctl &> /dev/null; then
  echo "✅ talosctl already installed: $(talosctl version --client 2>/dev/null | grep Tag | awk '{print $2}')"
else
  echo ""
  echo "📦 Installing talosctl..."
  curl -sL https://talos.dev/install | sh
  echo "✅ talosctl installed"
fi

# -----------------------------------------------------------------------------
# STEP 3: Install kubectl
# -----------------------------------------------------------------------------
if command -v kubectl &> /dev/null; then
  echo "✅ kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -1)"
else
  echo ""
  echo "📦 Installing kubectl..."
  sudo snap install kubectl --classic
  echo "✅ kubectl installed"
fi

# -----------------------------------------------------------------------------
# STEP 4: Create the local Talos cluster
# -----------------------------------------------------------------------------
echo ""
echo "🚀 Creating Talos cluster: $CLUSTER_NAME"
echo "   (This may take a few minutes on first run — it pulls Talos images)"
echo ""

sudo -u openclaw sudo -E talosctl cluster create docker --name "$CLUSTER_NAME"

# -----------------------------------------------------------------------------
# STEP 5: Verify
# -----------------------------------------------------------------------------
echo ""
echo "🔍 Verifying cluster..."
sleep 5
KUBECONFIG=/home/openclaw/.kube/config /snap/bin/kubectl get nodes

echo ""
echo "==========================================="
echo "✅ Talos cluster '$CLUSTER_NAME' is ready!"
echo ""
echo "  Check nodes:    KUBECONFIG=/home/openclaw/.kube/config kubectl get nodes"
echo "  Check cluster:  talosctl config info"
echo "  Stop cluster:   ./stop-talos.sh"
echo "==========================================="
