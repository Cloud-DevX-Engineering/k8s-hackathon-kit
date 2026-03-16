#!/bin/bash
# =============================================================================
# Setup OpenClaw System User
# =============================================================================
# Creates a dedicated 'openclaw' system user with passwordless sudo access
# so the OpenClaw AI agent can run privileged commands autonomously.
#
# Usage (run once, requires sudo):
#   chmod +x setup-openclaw-user.sh
#   sudo ./setup-openclaw-user.sh
# =============================================================================

set -e

echo ""
echo "🦞 OpenClaw User Setup"
echo "==========================================="
echo ""

# -----------------------------------------------------------------------------
# STEP 1: Create openclaw system user
# -----------------------------------------------------------------------------
if id "openclaw" &>/dev/null; then
  echo "✅ User 'openclaw' already exists"
else
  echo "👤 Creating system user 'openclaw'..."
  useradd --system --no-create-home --shell /usr/sbin/nologin openclaw
  echo "✅ User 'openclaw' created"
fi

# -----------------------------------------------------------------------------
# STEP 2: Add to docker group
# -----------------------------------------------------------------------------
echo "🐳 Adding 'openclaw' to docker group..."
usermod -aG docker openclaw
echo "✅ Added to docker group"

# Detect the user who invoked sudo (i.e. the real human user, not root)
INVOKING_USER="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"

# -----------------------------------------------------------------------------
# STEP 3: Grant passwordless sudo for openclaw user itself
# -----------------------------------------------------------------------------
echo "🔑 Configuring passwordless sudo for 'openclaw'..."
echo "openclaw ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/openclaw
chmod 440 /etc/sudoers.d/openclaw
echo "✅ Sudoers configured for 'openclaw'"

# -----------------------------------------------------------------------------
# STEP 4: Allow invoking user to sudo as openclaw without password
# -----------------------------------------------------------------------------
echo "🔑 Allowing '$INVOKING_USER' to switch to 'openclaw' without password..."
echo "$INVOKING_USER ALL=(openclaw) NOPASSWD: ALL" > /etc/sudoers.d/${INVOKING_USER}-as-openclaw
chmod 440 /etc/sudoers.d/${INVOKING_USER}-as-openclaw
echo "✅ Sudoers configured for '$INVOKING_USER' → 'openclaw'"

# -----------------------------------------------------------------------------
# STEP 5: Verify
# -----------------------------------------------------------------------------
echo ""
echo "🔍 Verifying setup..."
id openclaw
sudo -u openclaw sudo -n echo "  sudo test: OK"

echo ""
echo "==========================================="
echo "✅ OpenClaw user is ready!"
echo ""
echo "  Detected user: $INVOKING_USER"
echo "  The OpenClaw agent can now run:"
echo "  sudo -u openclaw sudo -E <your-command>"
echo "==========================================="
