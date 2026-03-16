#!/bin/bash
# =============================================================================
# Setup OpenClaw System User
# =============================================================================
# Creates a dedicated 'openclaw' system user with a home directory, shell,
# passwordless sudo, and docker access — ready to run OpenClaw as a service.
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

# Detect the user who invoked sudo
INVOKING_USER="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"

# -----------------------------------------------------------------------------
# STEP 1: Create openclaw system user (with home dir and shell)
# -----------------------------------------------------------------------------
if id "openclaw" &>/dev/null; then
  echo "✅ User 'openclaw' already exists"
  # Ensure home dir and shell are set correctly
  if [ ! -d /home/openclaw ]; then
    mkdir -p /home/openclaw
    chown openclaw:openclaw /home/openclaw
    echo "📁 Created /home/openclaw"
  fi
  usermod -s /bin/bash -d /home/openclaw openclaw 2>/dev/null || true
else
  echo "👤 Creating system user 'openclaw'..."
  useradd --system --create-home --home-dir /home/openclaw --shell /bin/bash openclaw
  echo "✅ User 'openclaw' created with home at /home/openclaw"
fi

# -----------------------------------------------------------------------------
# STEP 2: Add to docker group
# -----------------------------------------------------------------------------
echo "🐳 Adding 'openclaw' to docker group..."
usermod -aG docker openclaw
echo "✅ Added to docker group"

# -----------------------------------------------------------------------------
# STEP 3: Grant passwordless sudo for openclaw user
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
# STEP 5: Enable lingering (so user services start at boot without login)
# -----------------------------------------------------------------------------
echo "⚙️  Enabling lingering for 'openclaw' (auto-start services at boot)..."
loginctl enable-linger openclaw 2>/dev/null || echo "⚠️  loginctl enable-linger not available — service won't auto-start until openclaw logs in"
echo "✅ Lingering enabled"

# -----------------------------------------------------------------------------
# STEP 6: Verify
# -----------------------------------------------------------------------------
echo ""
echo "🔍 Verifying setup..."
id openclaw
echo "  Home: $(eval echo ~openclaw)"
echo "  Shell: $(getent passwd openclaw | cut -d: -f7)"
sudo -u openclaw whoami
sudo -u openclaw sudo -n echo "  sudo test: OK"

echo ""
echo "==========================================="
echo "✅ OpenClaw user is ready!"
echo ""
echo "  User:     openclaw"
echo "  Home:     /home/openclaw"
echo "  Shell:    /bin/bash"
echo "  Docker:   ✅"
echo "  Sudo:     ✅ (passwordless)"
echo "  Linger:   ✅ (services auto-start)"
echo ""
echo "  Next: Run install-openclaw.sh as the openclaw user:"
echo "  sudo -u openclaw ./install-openclaw.sh"
echo "==========================================="
