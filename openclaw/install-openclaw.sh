#!/bin/bash
# =============================================================================
# OpenClaw Install Script for WSL2 Ubuntu
# =============================================================================
# Installs OpenClaw with Node 22 via nvm and sets up the background daemon.
#
# Usage:
#   chmod +x install-openclaw.sh
#   ./install-openclaw.sh
# =============================================================================

set -e

echo ""
echo "🦞 OpenClaw Installer for WSL2 Ubuntu"
echo "========================================"
echo ""

# -----------------------------------------------------------------------------
# STEP 1: Install nvm if not already installed
# -----------------------------------------------------------------------------
if [ ! -d "$HOME/.nvm" ]; then
  echo "📦 Installing nvm..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash

  # Load nvm into current session
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

  echo "✅ nvm installed"
else
  echo "✅ nvm already installed"

  # Load nvm into current session
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
fi

# -----------------------------------------------------------------------------
# STEP 2: Install and use Node 22
# -----------------------------------------------------------------------------
echo ""
echo "📦 Installing Node.js 22..."
nvm install 22
nvm use 22
nvm alias default 22

echo "✅ Node $(node -v) active"
echo "✅ npm $(npm -v) active"

# -----------------------------------------------------------------------------
# STEP 3: Install OpenClaw
# -----------------------------------------------------------------------------
echo ""
echo "📦 Installing OpenClaw..."
curl -fsSL https://openclaw.ai/install.sh | bash

# Reload PATH in case openclaw was added
export PATH="$HOME/.nvm/versions/node/$(node -v)/bin:$PATH"

echo "✅ OpenClaw installed"

# -----------------------------------------------------------------------------
# STEP 4: Run doctor --repair to pin Node path in the service
# -----------------------------------------------------------------------------
echo ""
echo "🔧 Running openclaw doctor --repair to fix nvm Node path in service..."
openclaw doctor --repair || echo "⚠️  doctor --repair had warnings — check manually with: openclaw doctor"

# -----------------------------------------------------------------------------
# STEP 5: Set up the background daemon
# -----------------------------------------------------------------------------
echo ""
echo "⚙️  Setting up OpenClaw daemon..."
openclaw onboard --install-daemon

# -----------------------------------------------------------------------------
# STEP 6: Verify
# -----------------------------------------------------------------------------
echo ""
echo "🔍 Verifying installation..."
openclaw gateway status

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo "========================================"
echo "✅ OpenClaw is installed and running!"
echo ""
echo "  Open in browser: http://localhost:18789"
echo "  Get your token:  cat ~/.openclaw/openclaw.json | grep token"
echo ""
echo "💡 Tip: WSL2 doesn't auto-start with Windows."
echo "   Open a terminal once after reboot — the daemon will start automatically."
echo ""
echo "📖 Docs: https://docs.openclaw.ai"
echo "========================================"
