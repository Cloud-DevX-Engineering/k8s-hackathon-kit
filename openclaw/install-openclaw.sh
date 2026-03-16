#!/bin/bash
# =============================================================================
# OpenClaw Install Script for WSL2 Ubuntu
# =============================================================================
# Installs OpenClaw with Node 22 via nvm and sets up the background daemon
# as a systemd user service.
#
# Run as the openclaw user (after setup-openclaw-user.sh):
#   sudo -u openclaw ./install-openclaw.sh
#
# Or as any user for a personal install:
#   ./install-openclaw.sh
# =============================================================================

set -e

CURRENT_USER=$(whoami)

echo ""
echo "🦞 OpenClaw Installer for WSL2 Ubuntu"
echo "========================================"
echo "  Installing as: $CURRENT_USER"
echo "  Home: $HOME"
echo ""

# -----------------------------------------------------------------------------
# STEP 1: Install nvm if not already installed
# -----------------------------------------------------------------------------
export NVM_DIR="$HOME/.nvm"

if [ ! -d "$NVM_DIR" ]; then
  echo "📦 Installing nvm..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
  echo "✅ nvm installed"
fi

# Load nvm into current session
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# -----------------------------------------------------------------------------
# STEP 2: Install and use Node 22
# -----------------------------------------------------------------------------
echo ""
echo "📦 Installing Node.js 22..."
nvm install 22
nvm use 22
nvm alias default 22

NODE_VERSION=$(node -v)
NODE_BIN="$HOME/.nvm/versions/node/$NODE_VERSION/bin"

echo "✅ Node $NODE_VERSION active"
echo "✅ npm $(npm -v) active"

# -----------------------------------------------------------------------------
# STEP 3: Install OpenClaw
# -----------------------------------------------------------------------------
echo ""
echo "📦 Installing OpenClaw..."
curl -fsSL https://openclaw.ai/install.sh | bash

# Ensure PATH includes node bin
export PATH="$NODE_BIN:$PATH"

echo "✅ OpenClaw installed"

# -----------------------------------------------------------------------------
# STEP 4: Run onboard (creates config + sets up daemon)
# -----------------------------------------------------------------------------
echo ""
echo "⚙️  Running OpenClaw onboard..."
openclaw onboard --install-daemon

# -----------------------------------------------------------------------------
# STEP 5: Run doctor --repair to pin Node path in the service
# -----------------------------------------------------------------------------
echo ""
echo "🔧 Running openclaw doctor --repair..."
openclaw doctor --repair || echo "⚠️  doctor --repair had warnings — check: openclaw doctor"

# -----------------------------------------------------------------------------
# STEP 6: Add /snap/bin to PATH (for kubectl etc.)
# -----------------------------------------------------------------------------
if ! grep -q '/snap/bin' "$HOME/.bashrc" 2>/dev/null; then
  echo 'export PATH="/snap/bin:$PATH"' >> "$HOME/.bashrc"
  echo "✅ Added /snap/bin to PATH"
fi

# -----------------------------------------------------------------------------
# STEP 7: Verify
# -----------------------------------------------------------------------------
echo ""
echo "🔍 Verifying installation..."
openclaw gateway status || echo "⚠️  Gateway not responding yet — give it a moment"

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo "========================================"
echo "✅ OpenClaw is installed and running!"
echo ""
echo "  User:          $CURRENT_USER"
echo "  Home:          $HOME"
echo "  Node:          $NODE_VERSION"
echo "  Config:        $HOME/.openclaw/openclaw.json"
echo "  Workspace:     $HOME/.openclaw/workspace"
echo ""
echo "  Open in browser: http://localhost:18789"
echo ""
if [ "$CURRENT_USER" = "openclaw" ]; then
  echo "  💡 The service runs as the 'openclaw' user."
  echo "  To access the workspace from your main account:"
  echo "    sudo -u openclaw ls /home/openclaw/.openclaw/workspace"
  echo ""
fi
echo "  📖 Docs: https://docs.openclaw.ai"
echo "========================================"
