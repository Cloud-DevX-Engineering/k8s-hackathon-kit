#!/usr/bin/env bash
# =============================================================================
#  OpenClaw WSL2 Ubuntu Setup Script
# =============================================================================
#  Creates a dedicated "openclaw" user and installs OpenClaw to run under it.
#
#  What this script does:
#    1. Ensures systemd is enabled in WSL2 (required for user services)
#    2. Installs system-level dependencies (curl, git, build-essential, etc.)
#    3. Installs systemd-container (for machinectl — proper user sessions)
#    4. Creates an "openclaw" user with passwordless sudo
#    5. Installs Homebrew (Linuxbrew) under the openclaw user
#    6. Installs Node.js 24 via nvm under the openclaw user
#    7. Installs OpenClaw globally via npm under the openclaw user
#    8. Enables systemd user linger so the openclaw daemon survives logouts
#    9. Prints next steps for onboarding
#
#  Usage:
#    chmod +x setup-openclaw-wsl2.sh
#    sudo ./setup-openclaw-wsl2.sh
#
#  After the script completes, use machinectl to get a proper session:
#    sudo machinectl shell openclaw@.host
#    openclaw onboard --install-daemon
#
#  IMPORTANT: Do NOT use "sudo -iu openclaw" — it does not create a proper
#  systemd user session, which means systemctl --user and the gateway daemon
#  will fail. Always use machinectl.
#
# =============================================================================

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
OPENCLAW_USER="openclaw"
NODE_MAJOR_VERSION="24"
NVM_VERSION="0.40.3"

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step()  { echo -e "\n${BOLD}── $* ──${NC}"; }

# ── Pre-flight checks ───────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (use sudo)."
    exit 1
fi

if ! grep -qi 'microsoft\|wsl' /proc/version 2>/dev/null; then
    warn "WSL2 not detected. This script is designed for WSL2 Ubuntu."
    warn "Continuing anyway — the script should work on regular Ubuntu too."
fi

# ── Step 1: Ensure systemd is enabled ────────────────────────────────────────
step "1/9 — Checking systemd"

WSL_CONF="/etc/wsl.conf"

if command -v systemctl &>/dev/null && systemctl is-system-running &>/dev/null 2>&1; then
    ok "systemd is already active."
else
    info "systemd is not active. Configuring /etc/wsl.conf..."

    if [[ -f "$WSL_CONF" ]]; then
        if grep -q '^\[boot\]' "$WSL_CONF"; then
            if grep -q '^systemd=' "$WSL_CONF"; then
                sed -i 's/^systemd=.*/systemd=true/' "$WSL_CONF"
            else
                sed -i '/^\[boot\]/a systemd=true' "$WSL_CONF"
            fi
        else
            echo -e "\n[boot]\nsystemd=true" >> "$WSL_CONF"
        fi
    else
        cat > "$WSL_CONF" <<EOF
[boot]
systemd=true
EOF
    fi

    warn "systemd has been enabled in /etc/wsl.conf."
    warn "You MUST restart WSL2 before continuing:"
    warn "  1. Exit this terminal"
    warn "  2. In PowerShell run:  wsl --shutdown"
    warn "  3. Re-open your WSL2 terminal"
    warn "  4. Re-run this script:  sudo ./setup-openclaw-wsl2.sh"
    echo ""
    warn "Exiting now. Please restart WSL2 and re-run."
    exit 0
fi

# ── Step 2: Install system dependencies ──────────────────────────────────────
step "2/9 — Installing system dependencies"

apt-get update -qq
apt-get install -y -qq \
    curl \
    wget \
    git \
    build-essential \
    python3 \
    ca-certificates \
    gnupg \
    unzip \
    procps \
    > /dev/null 2>&1

ok "System dependencies installed."

# ── Step 3: Install systemd-container (machinectl) ───────────────────────────
step "3/9 — Installing systemd-container (machinectl)"

if command -v machinectl &>/dev/null; then
    ok "machinectl already installed."
else
    apt-get install -y -qq systemd-container > /dev/null 2>&1
    ok "systemd-container installed."
fi

info "machinectl is required to get a proper systemd user session."
info "Always use 'sudo machinectl shell openclaw@.host' instead of 'sudo -iu openclaw'."

# ── Step 4: Create the openclaw user ─────────────────────────────────────────
step "4/9 — Creating user '${OPENCLAW_USER}'"

if id "${OPENCLAW_USER}" &>/dev/null; then
    ok "User '${OPENCLAW_USER}' already exists."
else
    useradd \
        --create-home \
        --shell /bin/bash \
        --comment "OpenClaw Service Account" \
        "${OPENCLAW_USER}"
    ok "User '${OPENCLAW_USER}' created with home at /home/${OPENCLAW_USER}."
fi

OPENCLAW_HOME="/home/${OPENCLAW_USER}"

# ── Step 5: Configure passwordless sudo ──────────────────────────────────────
step "5/9 — Configuring passwordless sudo for '${OPENCLAW_USER}'"

SUDOERS_FILE="/etc/sudoers.d/${OPENCLAW_USER}"

if [[ -f "${SUDOERS_FILE}" ]]; then
    ok "Sudoers file already exists at ${SUDOERS_FILE}."
else
    echo "${OPENCLAW_USER} ALL=(ALL) NOPASSWD:ALL" > "${SUDOERS_FILE}"
    chmod 0440 "${SUDOERS_FILE}"

    # Validate the sudoers file
    if visudo -c -f "${SUDOERS_FILE}" &>/dev/null; then
        ok "Passwordless sudo configured for '${OPENCLAW_USER}'."
    else
        err "Sudoers file validation failed. Removing invalid file."
        rm -f "${SUDOERS_FILE}"
        exit 1
    fi
fi

# ── Step 6: Install Homebrew (Linuxbrew) for the openclaw user ───────────────
step "6/9 — Setting up Homebrew (Linuxbrew)"

BREW_PREFIX="/home/linuxbrew/.linuxbrew"

if [[ -d "${BREW_PREFIX}" ]]; then
    info "Homebrew directory already exists. Fixing ownership..."
    chown -R "${OPENCLAW_USER}:${OPENCLAW_USER}" "${BREW_PREFIX}"
    chmod -R u+w "${BREW_PREFIX}"
    ok "Homebrew ownership fixed for '${OPENCLAW_USER}'."
else
    info "Installing Homebrew as '${OPENCLAW_USER}'..."
    sudo -u "${OPENCLAW_USER}" bash -c \
        'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' \
        || true

    if [[ -d "${BREW_PREFIX}" ]]; then
        chown -R "${OPENCLAW_USER}:${OPENCLAW_USER}" "${BREW_PREFIX}"
        chmod -R u+w "${BREW_PREFIX}"
        ok "Homebrew installed and ownership set to '${OPENCLAW_USER}'."
    else
        warn "Homebrew installation may have failed. Skills that need brew will not work."
        warn "You can install it manually later as the openclaw user."
    fi
fi

# Add Homebrew to .bashrc — use a heredoc with single-quoted delimiter to
# prevent any variable/command expansion, ensuring correct syntax in the file.
sudo -u "${OPENCLAW_USER}" bash << 'BREWRC'
if ! grep -q 'brew shellenv' "${HOME}/.bashrc" 2>/dev/null; then
    cat >> "${HOME}/.bashrc" << 'INNEREOF'

# Homebrew (Linuxbrew)
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
INNEREOF
fi
BREWRC
ok "Homebrew added to ${OPENCLAW_USER}'s shell profile."

# ── Step 7: Install nvm + Node.js as the openclaw user ──────────────────────
step "7/9 — Installing nvm and Node.js ${NODE_MAJOR_VERSION} for '${OPENCLAW_USER}'"

sudo -iu "${OPENCLAW_USER}" bash <<USERSHELL
set -euo pipefail

# Install nvm if not present
export NVM_DIR="\${HOME}/.nvm"
if [[ ! -d "\${NVM_DIR}" ]]; then
    echo "[INFO]  Installing nvm v${NVM_VERSION}..."
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" | bash
else
    echo "[OK]    nvm already installed."
fi

# Source nvm
export NVM_DIR="\${HOME}/.nvm"
[ -s "\${NVM_DIR}/nvm.sh" ] && . "\${NVM_DIR}/nvm.sh"

# Install Node.js
if command -v node &>/dev/null && node -v | grep -q "^v${NODE_MAJOR_VERSION}"; then
    echo "[OK]    Node.js \$(node -v) already installed."
else
    echo "[INFO]  Installing Node.js ${NODE_MAJOR_VERSION}..."
    nvm install ${NODE_MAJOR_VERSION}
    nvm alias default ${NODE_MAJOR_VERSION}
    nvm use default
    echo "[OK]    Node.js \$(node -v) installed."
fi

echo "[OK]    npm version: \$(npm -v)"
USERSHELL

ok "Node.js ${NODE_MAJOR_VERSION} ready for user '${OPENCLAW_USER}'."

# ── Step 8: Install OpenClaw as the openclaw user ────────────────────────────
step "8/9 — Installing OpenClaw"

sudo -iu "${OPENCLAW_USER}" bash <<'USERSHELL'
set -euo pipefail

# Source nvm
export NVM_DIR="${HOME}/.nvm"
[ -s "${NVM_DIR}/nvm.sh" ] && . "${NVM_DIR}/nvm.sh"

# Install OpenClaw globally
echo "[INFO]  Installing openclaw via npm..."
npm install -g openclaw@latest 2>&1 | tail -5

# Verify
NPM_BIN="$(npm prefix -g)/bin"
if [[ -x "${NPM_BIN}/openclaw" ]]; then
    echo "[OK]    OpenClaw installed at ${NPM_BIN}/openclaw"
else
    echo "[ERROR] OpenClaw installation failed."
    exit 1
fi
USERSHELL

# Add npm global bin to PATH in .bashrc — guarded so it only runs after nvm loads
sudo -u "${OPENCLAW_USER}" bash << 'NPMRC'
if ! grep -q 'npm prefix -g' "${HOME}/.bashrc" 2>/dev/null; then
    cat >> "${HOME}/.bashrc" << 'INNEREOF'

# npm global bin (after nvm is loaded)
if command -v npm &>/dev/null; then
    export PATH="$(npm prefix -g)/bin:$PATH"
fi
INNEREOF
fi
NPMRC

ok "OpenClaw installed for user '${OPENCLAW_USER}'."

# ── Step 9: Enable systemd user linger + start user manager ─────────────────
step "9/9 — Enabling systemd linger and user manager for '${OPENCLAW_USER}'"

loginctl enable-linger "${OPENCLAW_USER}" 2>/dev/null || true
ok "Linger enabled — systemd user services will persist after logout."

OPENCLAW_UID=$(id -u "${OPENCLAW_USER}")
systemctl start "user@${OPENCLAW_UID}.service" 2>/dev/null || true
ok "Systemd user manager started for UID ${OPENCLAW_UID}."

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  OpenClaw setup complete!${NC}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  User:       ${BOLD}${OPENCLAW_USER}${NC}"
echo -e "  Home:       ${BOLD}${OPENCLAW_HOME}${NC}"
echo -e "  Node.js:    ${BOLD}v${NODE_MAJOR_VERSION}.x (via nvm)${NC}"
echo -e "  Homebrew:   ${BOLD}/home/linuxbrew/.linuxbrew${NC}"
echo -e "  Sudo:       ${BOLD}passwordless (via /etc/sudoers.d/${OPENCLAW_USER})${NC}"
echo -e "  Config dir: ${BOLD}${OPENCLAW_HOME}/.openclaw/${NC}"
echo ""
echo -e "${RED}${BOLD}  ⚠ IMPORTANT — DO NOT use 'sudo -iu openclaw'${NC}"
echo -e "  It does not create a proper systemd user session, which means"
echo -e "  systemctl --user and the OpenClaw gateway daemon will fail."
echo ""
echo -e "${CYAN}${BOLD}  Next steps:${NC}"
echo ""
echo -e "  1. Switch to the openclaw user (proper session):"
echo -e "     ${BOLD}sudo machinectl shell openclaw@.host${NC}"
echo ""
echo -e "  2. Run the onboarding wizard (interactive):"
echo -e "     ${BOLD}openclaw onboard --install-daemon${NC}"
echo ""
echo -e "     This will walk you through:"
echo -e "       • Choosing your AI provider (Anthropic, OpenAI, etc.)"
echo -e "       • Entering your API key"
echo -e "       • Selecting a messaging channel (WhatsApp, Telegram, etc.)"
echo -e "       • Optionally installing skills"
echo -e "       • Installing the gateway daemon (systemd user service)"
echo ""
echo -e "  3. If you already ran onboarding but skipped the daemon:"
echo -e "     ${BOLD}sudo machinectl shell openclaw@.host${NC}"
echo -e "     ${BOLD}openclaw gateway install${NC}"
echo -e "     ${BOLD}openclaw gateway start${NC}"
echo ""
echo -e "  4. Verify the installation:"
echo -e "     ${BOLD}openclaw doctor${NC}"
echo -e "     ${BOLD}openclaw status${NC}"
echo ""
echo -e "  5. Access the dashboard:"
echo -e "     ${BOLD}openclaw dashboard${NC}"
echo -e "     Default URL: ${BOLD}http://127.0.0.1:18789${NC}"
echo ""
echo -e "${YELLOW}  Security reminders:${NC}"
echo -e "  • Never expose the gateway to the public internet without auth"
echo -e "  • Keep the gateway bound to 127.0.0.1 (loopback)"
echo -e "  • Enable exec_approval for dangerous tools (terminal, filesystem_delete)"
echo -e "  • Run ${BOLD}openclaw doctor${NC} regularly to check for misconfigurations"
echo ""
echo -e "${CYAN}  Convenience alias (add to your own ~/.bashrc):${NC}"
echo -e "  ${BOLD}alias openclaw-shell='sudo machinectl shell openclaw@.host'${NC}"
echo ""
